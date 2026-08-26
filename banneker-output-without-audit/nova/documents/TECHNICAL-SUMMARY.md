# Technical Summary — OpenStack Nova

**Generated:** 2026-08-26
**Project:** OpenStack Nova
**Version:** Survey v2.0 — Complete

---

## 1. Project Overview

OpenStack Nova is a distributed compute orchestration service that manages the lifecycle of virtual machine and bare-metal instances across cloud infrastructure. It provides a unified API abstraction over heterogeneous virtualization technologies (libvirt/KVM, VMware, IBM Z, bare metal via Ironic), supporting horizontal scaling through cells v2 and integrating with the broader OpenStack ecosystem.

### Problem Statement

Cloud operators need a scalable, multi-tenant compute orchestration layer that:

- Abstracts heterogeneous virtualization technologies into a unified API
- Supports horizontal scaling through cells v2 (thousands of compute nodes)
- Integrates with OpenStack services: Glance (images), Neutron (networking), Cinder (storage), Keystone (identity), and Placement (resource tracking)
- Provides fine-grained RBAC with microversioned REST APIs

### Scope

Nova manages the full instance lifecycle: creation, scheduling, live migration, resizing, console access, volume attachment, and deletion. It operates as a backend service with no direct frontend; all client interaction occurs through the REST API.

## 2. Actors

### Human Actors

| Actor | Role |
|-------|------|
| **Cloud Administrator** | Manages Nova infrastructure including cells, aggregates, host aggregates, security groups, quotas, service management, policy rules, and service health monitoring via `nova-manage` and `nova-status` |
| **Cloud User (Tenant)** | Provisions and manages compute instances within their project, including booting, resizing, rebooting, pausing/resuming, attaching volumes, and accessing console via noVNC or Spice |

### System Actors

| Actor | Role |
|-------|------|
| **OpenStack Keystone** | Identity and authentication; validates tokens, enforces RBAC policy, provides tenant context for all Nova API requests |
| **OpenStack Glance** | Image service; serves VM disk images, provides image metadata (architecture, min disk, min RAM), and exposes image properties for scheduler filters |
| **OpenStack Neutron** | Networking service; creates and manages network interfaces, assigns IP addresses, manages security groups, and provides network topology |
| **OpenStack Cinder** | Block storage service; attaches and detaches iSCSI/FC volumes to instances, supports boot-from-volume |
| **OpenStack Placement** | Resource provider tracking; allocates vCPUs, memory, disk, and custom resources per compute host |
| **VM Instance** | The managed virtual machine or bare-metal instance; exposes metadata service, reports heartbeat, supports live migration and console access |

## 3. Core Workflows

### 3.1 Create and Boot a Server Instance

User submits `POST /servers` with `image_id`, `flavor_id`, `network_info`, and optional `user_data`. The API controller validates against the current microversion schema. Keystone middleware authenticates and applies policy rules (DEC-003, DEC-007). `ComputeManager.create()` initiates the build flow, which notifies the Scheduler via RPC.

The Scheduler selects a host using filters (affinity, NUMA, PCI, image properties, aggregate filters) and weights (DEC-008), then routes the build request to the appropriate conductor service in a cell-aware manner (DEC-005). The Conductor dispatches to the target `nova-compute` node via RPC. The compute node reserves resource allocations in Placement, downloads the image from Glance (if not cached), allocates network resources via Neutron, spawns the VM via the libvirt/KVM virt driver, and updates the Instance object state to ACTIVE.

**Key dependencies:** DEC-001, DEC-003, DEC-008, DEC-010, DEC-011

### 3.2 Live Migrate a Running Instance

User submits `POST /servers/{id}/action` with `action=migrate`. The `ComputeManager.migrate_server()` flow initiates pre-copy of memory pages between compute nodes. The cursive distributed state machine coordinates the live migration state (DEC-011). TooZ lock groups prevent concurrent operations on the same instance. After the final pause-and-switch, resource allocations are swapped between source and destination hosts via Placement.

**Key dependencies:** DEC-011

### 3.3 Resize an Instance (Change Flavor)

User submits `POST /servers/{id}/action` with `action=resize` and a target `flavor_id`. Nova creates a `ResizeRequest`, allocates resources on the destination host, migrates the instance with shutdown, resizes the disk, and boots the instance with new flavor specs. The user must confirm (`confirmResize`) or revert (`revertResize`).

**Key dependencies:** DEC-011

### 3.4 List and Filter Servers with Microversion API

User sends `GET /servers` with query parameters (`status`, `image_id`, `flavor_id`, `host`, `project_id`). The API controller applies the `X-OpenStack-Nova-API-Version` header for microversion-aware filtering. `ServersController.index()` queries Instance objects via the versioned object layer, applies database-level filters, and the view module serializes the response with microversion-aware format.

**Key dependencies:** DEC-003, DEC-002

### 3.5 Access Instance Console via noVNC Proxy

User requests `GET /servers/{id}/actions/os-get-vnc-console`. The API validates access and creates a console ticket via `VncConsoleManager`. The `nova-novncproxy` service tunnels WebSocket traffic between the browser and the compute node's VNC server.

## 4. Architecture

### 4.1 Process Model

Nova operates as four separate daemons communicating via RPC (DEC-001):

| Daemon | Responsibility |
|--------|---------------|
| `nova-api` | WSGI HTTP API server; receives and responds to all REST requests |
| `nova-scheduler` | Host selection; filter/weight pipeline for scheduling decisions |
| `nova-conductor` | Database access mediator; routes requests between cells; manages resource allocations |
| `nova-compute` | Per-host daemon; manages VM lifecycle on its host (spawn, migrate, delete) |

Compute nodes have **no direct database access**; all database operations go through the conductor service. This improves security and enables compute nodes to run in untrusted tenant environments (DEC-001).

### 4.2 Cells v2 Architecture

Nova supports multi-cell deployments for horizontal scaling (DEC-005):

- **Cell0**: Metadata-only database. Stores cell mappings and lightweight instance metadata (e.g., UUID, hostname, power state). No compute resources tracked here.
- **Cell1+**: Each cell has its own database, conductor, and compute hosts. Full compute and scheduling operations occur within each cell independently.

The Conductor routes build requests to the appropriate cell. Requests that span cells (e.g., live migration across cells) are coordinated via the conductor layer.

### 4.3 Data Model

Two-layer data model (DEC-002):

1. **SQLAlchemy ORM** (`nova/db/`) — Maps to database tables. Shadow tables enable soft deletes and audit trails.
2. **oslo.versionedobjects** (`nova/objects/`) — 65 object classes with explicit VERSION attributes, providing API-level backward compatibility independent of database schema changes.

The "Smart Managers, Dumb Data" pattern separates business logic (managers) from data representation (objects).

### 4.4 Concurrency Model

The default concurrency model is Eventlet green threads (DEC-006), providing non-blocking I/O for thousands of concurrent connections. A native Python threading fallback (`concurrency_backend = threading`) accommodates environments where eventlet is incompatible (e.g., certain glibc versions, profiler tools). Test infrastructure enforces greenlet leak detection.

### 4.5 Authorization

Fine-grained RBAC via oslo.policy (DEC-007):

- 56 policy modules corresponding to API modules
- Rules checked at every API endpoint via middleware stack
- Keystone provides authentication context
- Policy rules are configurable at runtime

Privilege separation (DEC-009):

- oslo.privsep isolates privileged operations in a separate process
- Nova-compute runs as root but untrusted API input cannot escalate
- oslo-rootwrap whitelists allowed host commands

## 5. Integration Boundaries

Nova integrates with eight external services and components:

| Integration | Direction | Protocol |
|-------------|-----------|----------|
| OpenStack Keystone | Inbound (authentication) | HTTP REST |
| OpenStack Glance | Outbound (image retrieval) | HTTP REST |
| OpenStack Neutron | Bidirectional | RPC (oslo.messaging) |
| OpenStack Cinder | Bidirectional | RPC (oslo.messaging) |
| OpenStack Placement | Bidirectional | HTTP REST |
| RabbitMQ | Bidirectional (internal RPC) | AMQP (via Kombu) |
| Barbican | Outbound (key management) | HTTP REST (via castellan) |
| Dogpile.cache | Internal (caching) | Configuration-driven |

## 6. Technology Stack Summary

| Category | Technology |
|----------|-----------|
| Language | Python |
| Runtime | CPython + Eventlet (green threads) |
| Web | WSGI, PasteDeploy, Routes |
| API | REST over JSON, microversioning (2.1 → 2.104) |
| Database | PostgreSQL (primary), MySQL/MariaDB (alternative), SQLite (test) |
| ORM | SQLAlchemy + Alembic |
| Object Layer | oslo.versionedobjects (65 classes) |
| Messaging | oslo.messaging (RabbitMQ/Kombu) |
| Concurrency | Eventlet (default), threading (fallback) |
| Virtualization | libvirt (default), VMware, IBM Z, Ironic |
| Scheduling | Stevedore pluggable filters (19) and weights |
| Authorization | oslo.policy (56 modules) |
| Privilege | oslo.privsep + oslo-rootwrap |
| Configuration | oslo.config (48 modules) |
| Deployment | Ansible, Devstack |
| CI/CD | Zuul, Docker |
| Console | noVNC, Spice |

## 7. Quality Attributes

| Attribute | Approach |
|-----------|----------|
| **Scalability** | Cells v2 horizontal partitioning (DEC-005); per-host compute daemons (DEC-001) |
| **Reliability** | Message persistence via RabbitMQ (DEC-010); distributed state machine for migrations (DEC-011) |
| **Security** | Compute nodes without direct DB access (DEC-001); privilege separation (DEC-009); fine-grained RBAC (DEC-007) |
| **Extensibility** | Stevedore pluggable drivers and scheduler plugins (DEC-004, DEC-008); microversioned API (DEC-003) |
| **Compatibility** | oslo.policy ecosystem integration (DEC-007); eventlet-based oslo library compatibility (DEC-006) |

## 8. Architectural Decisions Summary

| ID | Decision |
|----|----------|
| DEC-001 | Three-process distributed architecture |
| DEC-002 | Two-layer data model with versioned objects |
| DEC-003 | REST API with microversioning |
| DEC-004 | libvirt default driver, pluggable via Stevedore |
| DEC-005 | Cells v2 for horizontal scaling |
| DEC-006 | Eventlet concurrency with threading fallback |
| DEC-007 | oslo.policy for fine-grained RBAC |
| DEC-008 | Pluggable scheduler filters and weights |
| DEC-009 | oslo.privsep for privilege isolation |
| DEC-010 | oslo.messaging with RabbitMQ transport |
| DEC-011 | Scheduler → Conductor → Compute RPC chain |
| DEC-012 | Modular oslo.config configuration |
