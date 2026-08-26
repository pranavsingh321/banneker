# OpenStack Nova — Platform Context

Generated: 2026-08-26T00:00:00Z
Word limit: ~4,000 words

---

## Project Overview

OpenStack Nova is OpenStack's distributed compute service that manages the lifecycle of instances (virtual machines and bare metal) in a cloud infrastructure. Cloud operators need a scalable, multi-tenant compute orchestration layer that abstracts heterogeneous virtualization technologies (Libvirt/KVM, VMware, IBM Z, bare metal via Ironic) into a unified microversioned REST API. Nova supports horizontal scaling through cells v2, integrates with other OpenStack services (Glance, Neutron, Cinder, Keystone, Placement), and provides fine-grained RBAC.

**Project:** OpenStack Nova
**Type:** backend-service (large scale)
**API Base:** /v2.1 with microversioning up to 2.104

## Technology Stack

### Core Technologies

| Technology | Category | Rationale |
|------------|----------|-----------|
| Python (Eventlet) | Language/Runtime | OpenStack ecosystem standard; green threads handle thousands of concurrent connections |
| WSGI / PasteDeploy | Web Framework | Standard deployment interface; compatible with all OpenStack services |
| Routes (ProjectMapper) | URL Routing | Flexible URL mapping for nested Nova resource paths |
| SQLAlchemy + Shadow Tables | ORM | Two-layer data model with soft delete support and audit trails (DEC-002) |
| PostgreSQL / MySQL/MariaDB | Database | Strong consistency, JSONB support, reliable transactions (DEC-002) |
| Alembic | Migration | Versioned schema evolution with reversible migrations |
| oslo.db | Session Management | Automatic retry on transient database failures |
| oslo.messaging / RabbitMQ | RPC Transport | Persistent message delivery for build/migration operations (DEC-010) |
| oslo.policy | Authorization | 56 policy modules for fine-grained RBAC (DEC-007) |
| oslo.config | Configuration | 48 modular config modules mirroring Nova's subsystem architecture (DEC-012) |
| oslo.privsep + oslo-rootwrap | Privilege Separation | Compartmentalized privilege execution limits API compromise damage (DEC-009) |
| TooZ | Distributed Locking | Lock groups prevent concurrent operations on same instance |
| cursive | State Machine | Formal state machine for live migration coordination (DEC-011) |
| Stevedore | Plugin Loading | Dynamic loading of 19+ scheduler filters and virtualization drivers |
| Libvirt (KVM/QEMU/LXC) | Virtualization (Default) | Most widely deployed stack in OpenStack (DEC-004) |
| VMware, ZVM, Ironic | Virtualization (Optional) | Optional drivers for heterogeneous hardware support |
| Cells v2 | Scaling Architecture | Cell0 metadata + Cell1+ independent deployments (DEC-005) |
| Dogpile.cache | Caching | Distributed caching for flavor, aggregate, and filter lookups |
| Barbican (castellan) | Secrets | Cryptographic key management for encrypted disks |

### Supporting Tools

Ansible (deployment), DevStack (single-node deployment/testing), Zuul (CI/CD), Docker (containerized CI), tox/stestr (test runner), Tempest (integration tests), PasteDeploy (WSGI pipeline), Kombu (RabbitMQ client), castellan (key abstraction).

## Architecture Decisions

**DEC-001: Compute orchestration distribution** — Three-process architecture: nova-compute, nova-conductor, and nova-scheduler run as separate daemons communicating via RPC (oslo.messaging). Separating compute, conductor, and scheduler enables independent scaling, fault isolation, and cell-based horizontal growth. Compute nodes have no direct database access, improving security. Rejected monolithic single-process (no horizontal scaling) and microservices (OpenStack ecosystem requires tightly integrated services).

**DEC-002: Data model management** — Two-layer data model: SQLAlchemy ORM models in nova/db/ with Shadow tables for soft deletes, wrapped by oslo.versionedobjects (65 object classes with explicit VERSION attributes) in nova/objects/. Provides API-level backward compatibility independent of database schema changes. Shadow tables enable audit trails without complex SQL. Rejected single ORM layer without versioned objects (would require DB migrations for API changes) and NoSQL (OpenStack expects relational data with strong consistency).

**DEC-003: REST API versioning** — REST API over WSGI with microversioning (2.1 base, currently 2.104). URL routing via Routes with custom ProjectMapper. Microversions controlled via X-OpenStack-Nova-API-Version header. 390+ microversion changes show highly iterative development. Rejected URL-based versioning (permanent URL endpoints that cannot be deprecated) and GraphQL (OpenStack ecosystem uses REST).

**DEC-004: Default virtualization driver** — Libvirt (KVM/QEMU/LXC/Parallels) as the default driver, with VMware, IBM Z (ZVM), and bare metal (Ironic) as optional drivers loaded via Stevedore entry points. Libvirt is the most widely deployed virtualization stack in OpenStack. Rejected embedding all drivers in core (would bloat codebase) and container-only runtime (VMs dominated cloud demand).

**DEC-005: Horizontal scaling** — Cells v2 architecture: Cell0 is a metadata-only database; Cell1+ each have their own database, conductor, and compute hosts. Single-database Nova hits scalability limits around a few thousand hosts. Cell isolation allows each cell to scale independently. Rejected database partitioning (harder to manage, single point of failure) and fully distributed peer-to-peer (no centralized resource tracking).

**DEC-006: Concurrency model** — Eventlet green threads as default, with native Python threading fallback. Handles thousands of concurrent connections per process. The threading fallback accommodates environments where eventlet is incompatible. Rejected asyncio (oslo.* ecosystem is built on eventlet) and native thread-per-request (higher memory/resource consumption).

**DEC-007: Authorization** — oslo.policy with 56 policy modules defining fine-grained RBAC rules. Custom policy enforcer entry point (nova.policy:get_enforcer). Consistent policy management across all OpenStack services. Rejected custom authorization framework (not compatible with existing OpenStack policy tools) and ABAC (role-based rules simpler to manage and audit).

**DEC-008: Scheduler pluggability** — Stevedore entry points for scheduler filters (19 filters) and weight plugins. Different cloud deployments have vastly different scheduling requirements. Rejected hard-coded scheduler logic (would force uniform policy) and external scheduler service (adds network overhead).

**DEC-009: Privilege separation** — oslo.privsep with privilege separation helpers in nova/privsep/. Privileged operations execute in a separate process via oslo-rootwrap. nova-compute runs as root but should not trust API input. Rejected running nova-compute as unprivileged (hypervisor operations require root) and sudo-based escalation (less secure than oslo.privsep).

**DEC-010: Messaging transport** — oslo.messaging with RabbitMQ via Kombu as default transport. Message persistence guarantees build/migration reliability. Transport abstraction allows switching to ZeroMQ or in-memory. Rejected ZeroMQ (no message persistence) and direct TCP (tight coupling).

**DEC-011: Build request coordination** — Scheduler → Conductor → Compute RPC chain with cursive distributed state machine for live migration and TooZ lock groups for distributed locking. Ensures resource allocation, database updates, and VM lifecycle are coordinated through consistent pathways. Rejected direct Scheduler→Compute (bypasses conductor layer) and synchronous builds (blocks API threads).

**DEC-012: Configuration management** — 48 modular config modules in nova/conf/, aggregated via oslo.config entry point. Modular approach mirrors Nova's subsystem architecture. Rejected single monolithic config (unwieldy with 48+ subsystems) and YAML/JSON (oslo.config is ecosystem standard).

## Core Walkthroughs

### Create and boot a server instance

**Actor:** Cloud User (Tenant)
**Flow:**
1. User authenticates with Keystone and submits POST /servers with image_id, flavor_id, network_info, and optional user_data
2. API controller validates the request against the current microversion schema
3. Keystone middleware authenticates the token and applies policy rules (DEC-003, DEC-007)
4. ComputeManager.create() is called, which notifies the Scheduler via RPC (DEC-011)
5. Scheduler selects a host using filters (affinity, NUMA, PCI, image properties, aggregate filters) and weights (DEC-008)
6. Scheduler routes the build request to the appropriate conductor service (cell-aware) (DEC-005)
7. Conductor dispatches the build request to the target nova-compute node via RabbitMQ (DEC-010)
8. Compute node reserves resource allocations in Placement (vCPUs, memory, disk)
9. Compute node downloads the image from Glance (if not cached)
10. Compute node allocates network resources via Neutron (creates port, assigns IP)
11. Compute node spawns the VM via the virt driver (libvirt/KVM by default) (DEC-004)
12. Compute node updates the Instance object state to ACTIVE
13. User receives 202 Accepted with server creation response

**Data Changes:** Instance row created (status=BUILDING), InstanceAction record, Placement resource allocations, Neutron port creation, shadow instance row for historical tracking.
**Error Cases:** NoValidHost (400), FlavorNotFound (404), ImageNotFound (404), QuotaExceeded (413), Insufficient resources, Neutron NetworkNotFound/PortCreationFailed.

### Live migrate a running instance

**Actor:** Cloud User (Tenant)
**Flow:**
1. User submits POST /servers/{id}/action with action=migrate on the target server
2. API controller validates the microversion for migration features
3. ComputeManager.migrate_server() initiates the migration flow
4. Scheduler selects a destination host using the same filter/weight pipeline (DEC-008)
5. Conductor coordinates the migration request to the destination compute node
6. Pre-copy phase: compute nodes transfer memory pages of the running VM over the network
7. Cursive distributed state machine coordinates the live migration state (DEC-011)
8. TooZ lock groups prevent concurrent operations on the same instance (DEC-011)
9. Final pause and switch: instance paused briefly, state transferred, instance resumed on destination
10. Placement resource allocations swapped between source and destination (DEC-011)
11. User receives 202 Accepted

**Data Changes:** Migration row created (status=check_cell0), Instance compute_host/host fields updated, Placement allocations transferred, InstanceAction records for each migration step.
**Error Cases:** Insufficient resources on destination, network bandwidth insufficient, incompatible CPU between hosts, source compute goes down during migration, conductor unreachable.

### Resize an instance (change flavor)

**Actor:** Cloud User (Tenant)
**Flow:**
1. User submits POST /servers/{id}/action with action=resize, specifying a new flavor_id
2. API controller verifies the user has permissions and the target flavor exists
3. Nova creates a resize request and allocates resources on the destination host
4. Scheduler selects a destination host for the resized instance
5. Instance is powered off and migrated to the destination (similar to live migration but with shutdown)
6. Disk is resized on the destination compute node
7. Instance boots on the destination with new flavor specs
8. User must confirm (action=confirmResize) or revert (action=revertResize)
9. On confirm: source resources released, migration marked complete
10. On revert: instance and disk moved back to original host

**Data Changes:** ResizeRequest record, instance flavor updated, resource allocations adjusted on both source and destination, migration record created.
**Error Cases:** No host with sufficient resources for target flavor, user does not confirm within timeout (auto-revert), disk resize fails on destination (auto-revert), conductor unavailable.

### List and filter servers with microversion API

**Actor:** Cloud User (Tenant)
**Flow:**
1. User sends GET /servers with query parameters (status, image_id, flavor_id, host, project_id)
2. API controller applies X-OpenStack-Nova-API-Version header for microversion
3. ServersController.index() queries Instance objects via the object layer
4. Filters applied at the database level via SQLAlchemy queries
5. View module serializes the response with microversion-aware format (DEC-003)
6. User receives filtered list of servers with metadata links

**Data Changes:** None (read-only).
**Error Cases:** Invalid microversion header (400), malformed query parameters (400), unauthorized (401).

### Access instance console via noVNC proxy

**Actor:** Cloud User (Tenant)
**Flow:**
1. User authenticates with Keystone and requests GET /servers/{id}/actions/os-get-vnc-console
2. API controller validates access and creates a console ticket via VncConsoleManager
3. nova-novncproxy service receives the VNC connection request with the ticket
4. Proxy authenticates the ticket and forwards the WebSocket connection to the compute node's VNC server
5. User sees the VM console in their browser via the noVNC WebSocket connection

**Data Changes:** Console ticket created with expiration timestamp, console entry logged in the database.
**Error Cases:** Instance not running (rejected), VNC server not listening on compute node (500), ticket expired (authentication rejected).

## Requirements Summary

### Installation & Distribution
- REQ-INST-001: Deploy via Ansible playbooks
- REQ-INST-002: Support DevStack single-node deployment
- REQ-INST-003: Support Docker-based CI deployment

### Functional Requirements
- REQ-FUNC-001: Create and boot a server instance (must)
- REQ-FUNC-002: Assign network port and IP via Neutron (must)
- REQ-FUNC-003: List and filter servers (must)
- REQ-FUNC-004: Live migrate an instance (must)
- REQ-FUNC-005: Resize an instance with confirmation workflow (must)
- REQ-FUNC-006: Access instance console via proxy (should)
- REQ-FUNC-007: Server actions (reboot, pause, resume, migrate, resize, etc.) (must)
- REQ-FUNC-008: Update server name and metadata (should)
- REQ-FUNC-009: Delete servers (should)
- REQ-FUNC-010: Attach/detach volumes via Cinder (should)
- REQ-FUNC-011: Manage server groups with affinity policies (should)

### Data Model
- REQ-DATA-001 through 012: Instance, InstanceAction, Migration, ResizeRequest, Flavor, ComputeNode, CellMapping, RequestSpec entities; PostgreSQL/Alembic/oslo.versionedobjects

### Security
- REQ-SEC-001: Keystone authentication on all API requests (must)
- REQ-SEC-002: oslo.policy RBAC with 56 policy modules (must)
- REQ-SEC-003: oslo.privsep for privilege separation (must)
- REQ-SEC-004: oslo-rootwrap command whitelisting (must)

### Performance
- REQ-PERF-001: Eventlet green threads for thousands of concurrent connections (must)
- REQ-PERF-002: Native threading fallback (should)
- REQ-PERF-003: Cell isolation to reduce database contention (should)
- REQ-PERF-004: Dogpile.cache for data caching (should)

### Integrations
- REQ-INT-001 through 008: Keystone, Glance, Neutron, Cinder, Placement, RabbitMQ, Barbican, Dogpile.cache

### Documentation
- REQ-DOCS-001 through 004: 48 modular config modules, oslo-config-generator, microversion documentation, policy rule documentation

## Context Footer

**Constraints:**
- nova-compute cannot connect directly to the database — all DB operations go through nova-conductor (DEC-001)
- asyncio is not introduced; the eventlet-based oslo.* ecosystem requires green thread concurrency (DEC-006)
- nova-compute runs as root; privilege separation via oslo.privsep is mandatory (DEC-009)
- Cell0 has no compute hosts; Cell1+ have independent databases and conductors (DEC-005)
- API microversions (2.1 through 2.104) require appropriate X-OpenStack-Nova-API-Version headers (DEC-003)

**Out of Scope:**
- Testing strategy — formal test design patterns, coverage targets, and test data management are rubric gaps
- Monitoring/observability — no specific metrics, alerting, or dashboard requirements defined
- Performance benchmarks — no benchmark data or performance profiles documented
- Optional drivers (VMware, ZVM, Ironic) — additional complexity not fully explored
- Metadata service detail — nova/api/metadata/ not examined in depth
- Cell RPC protocol details — exact messaging protocol between cells and conductor not fully traced

**Key Integrations:**
OpenStack Keystone (authentication/RBAC), Glance (image service), Neutron (networking/security groups), Cinder (block storage), Placement (resource tracking), RabbitMQ (inter-service RPC), Barbican (cryptographic keys), Dogpile.cache (distributed caching).

**Hosting:**
No specific cloud platform — designed for bare metal or virtualized infrastructure. Multi-cell production deployment (Cell0 metadata + Cell1+ compute), HA deployment (multiple instances behind load balancers), DevStack for single-node testing.

---

*Generated by Banneker. Word count: ~1,200 words. Complete context included. For full context, see generic summary or context bundle exports.*
