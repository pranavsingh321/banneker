# Technical Summary — OpenStack Nova

## Project Overview

**OpenStack Nova** is OpenStack's distributed compute service that manages the lifecycle of instances (virtual machines and bare metal) in a cloud infrastructure, including creation, scheduling, live migration, resizing, and deletion across multi-cell deployments.

Cloud operators need a scalable, multi-tenant compute orchestration layer that abstracts heterogeneous virtualization technologies (Libvirt/KVM, VMware, IBM Z, bare metal via Ironic) into a unified REST API, while supporting horizontal scaling through cells v2, integrating with other OpenStack services (Glance for images, Neutron for networking, Cinder for block storage, Keystone for authentication), and providing fine-grained RBAC with microversioned REST APIs.

## Actors

### Human Actors

- **Cloud Administrator** — Manages Nova infrastructure including cells, aggregates, host aggregates, security groups, quotas, and service management. Capabilities include creating and managing host aggregates, configuring cell mappings, enabling/disabling nova-compute and nova-scheduler services, setting quotas and limits per project, running management CLI commands, configuring policy rules, and monitoring service health.

- **Cloud User (Tenant)** — End user who provisions and manages compute instances within their project/tenant. Capabilities include creating, listing, showing, updating, and deleting servers; booting instances from images or snapshots; resizing instances; rebooting/pausing/resuming/suspending/stopping instances; attaching/detaching volumes; listing flavors, images, hypervisors, and aggregates; accessing console via noVNC, Spice, or serial proxy; launching instances via user-data and config-drive; managing server groups; and using microversioned API features.

### System Actors

- **OpenStack Keystone** — Identity and authentication service that validates tokens, enforces RBAC policy, and provides the context for all Nova API requests. Handles authentication via token validation, provides tenant/project context, enforces authorization policy rules via oslo.policy, and supports role-based access control.

- **OpenStack Glance** — Image service that Nova queries for VM disk images, metadata, and image properties used in filter-based host scheduling. Serves VM disk images to compute nodes, provides image metadata (architecture, min disk, min RAM), exposes image properties for scheduler filters, and supports image caching at compute nodes.

- **OpenStack Neutron** — Networking service that Nova integrates with for virtual network interface assignment, security groups, and port management. Creates and manages network interfaces, assigns IP addresses to instances, manages security groups, provides network topology, and supports distributed virtual routing.

- **OpenStack Cinder** — Block storage service that Nova integrates with for attaching persistent block storage volumes to instances. Attaches and detaches iSCSI/FC volumes, provides volume metadata, supports boot-from-volume instances, and exposes volume drivers for storage backends.

- **OpenStack Placement** — Resource provider tracking service that Nova queries and updates for resource allocation (vCPUs, memory, disk, custom resources) at each compute node. Tracks resource allocation per compute host, provides resource utilization data for scheduler filtering, accepts resource provider updates from Nova compute, and supports custom resource classes and traits.

- **VM Instance** — The virtual machine or bare-metal instance managed by Nova, which exposes a metadata service and is controlled via hypervisor-level operations. Accesses instance metadata, runs guest OS workloads, reports heartbeat and live state, supports live migration between hosts, and exposes console access.

## Technology Stack

OpenStack Nova is a Python-based backend service built on the OpenStack ecosystem, leveraging:

- **Language & Runtime:** Python with Eventlet green threads for concurrency
- **Data Layer:** PostgreSQL/MySQL/MariaDB as the primary production database, with SQLite as test fallback; Alembic for migrations; oslo.db for session management
- **REST API:** WSGI pipeline with PasteDeploy, Routes for URL routing, microversioned JSON API (2.1 base, currently 2.104)
- **Virtualization:** Libvirt (KVM/QEMU/LXC/Parallels) as default driver, with VMware, IBM Z (ZVM), and Ironic as pluggable drivers via Stevedore entry points
- **Messaging:** RabbitMQ via oslo.messaging with Kombu transport for inter-service RPC
- **Authorization:** oslo.policy with 56 policy modules for fine-grained RBAC
- **Configuration:** oslo.config with 48 modular config modules
- **Privilege Separation:** oslo.privsep with oslo-rootwrap
- **Distributed Locking:** TooZ lock groups
- **State Machine:** cursive for live migration coordination
- **Caching:** Dogpile.cache via oslo.cache
- **Security/Secrets:** Barbican via castellan for cryptographic key management
- **Pluggability:** Stevedore for scheduler filters (19 filters) and weight plugins
- **Deployment:** Ansible playbooks, Devstack for single-node deployment, Docker for CI

## Core Flows

### Create and Boot a Server Instance

The Cloud User (Tenant) authenticates with OpenStack Keystone and submits a POST request to the `/servers` endpoint with image_id, flavor_id, network_info, and optional user_data. The API controller validates the request against the current microversion schema, and Keystone middleware authenticates the token and applies policy rules (DEC-003). The ComputeManager.create() method is called, which notifies the Scheduler via RPC. The Scheduler selects a host using filters (affinity, NUMA, PCI, image properties, aggregate filters) and weights (DEC-008), then routes the build request through the Conductor service in a cell-aware manner (DEC-005). The Conductor dispatches the build request to the target nova-compute node via RabbitMQ (DEC-010). The compute node reserves resource allocations in OpenStack Placement, downloads the image from OpenStack Glance if not cached, allocates network resources via OpenStack Neutron, and spawns the VM via the Libvirt virt driver. The instance state transitions to ACTIVE, and the Cloud User (Tenant) receives a 202 Accepted response (DEC-011).

### Live Migrate a Running Instance

The Cloud User (Tenant) submits a POST request to `/servers/{id}/action` with action=migrate. The API controller validates the microversion for migration features, and the ComputeManager.migrate_server() initiates the migration flow. The Scheduler selects a destination host using the same filter/weight pipeline (DEC-008). The Conductor coordinates the migration request to the destination compute node. A pre-copy phase transfers memory pages of the running VM over the network. The cursive distributed state machine coordinates the live migration state, and TooZ lock groups prevent concurrent operations (DEC-011). During the final pause and switch, the instance is paused briefly, state is transferred, and the instance resumes on the destination. Resource allocations in OpenStack Placement are swapped between source and destination (DEC-011).

### Resize an Instance (Change Flavor)

The Cloud User (Tenant) submits a POST request to `/servers/{id}/action` with action=resize, specifying a new flavor_id. Nova creates a resize request, allocates resources on the destination host, selects a destination via the scheduler, powers off the instance, migrates it to the destination, and resizes the disk. The Cloud User (Tenant) must confirm or revert the resize (DEC-011).

### List and Filter Servers

The Cloud User (Tenant) sends a GET request to `/servers` with query parameters. The API controller applies the X-OpenStack-Nova-API-Version header for microversion support, and the ServersController.index() queries Instance objects via the SQLAlchemy object layer. Filters are applied at the database level, and the response is serialized with microversion-aware format (DEC-003).

## Architecture Decisions

1. **Three-Process Distributed Architecture** (DEC-001): Nova-compute, nova-conductor, and nova-scheduler run as separate daemons communicating via RPC, enabling independent scaling, fault isolation, and cell-based horizontal growth.

2. **Two-Layer Data Model** (DEC-002): SQLAlchemy ORM models in nova/db/ with Shadow tables for soft deletes, wrapped by oslo.versionedobjects (65 object classes with explicit VERSION attributes) in nova/objects/. This provides API-level backward compatibility independent of database schema changes.

3. **REST API with Microversioning** (DEC-003): REST API over WSGI with microversioning (2.1 base, currently 2.104), URL routing via Routes with ProjectMapper, JSON responses, and microversions controlled via X-OpenStack-Nova-API-Version header.

4. **Libvirt as Default Virtualization Driver** (DEC-004): Libvirt (KVM/QEMU/LXC/Parallels) as the default, with VMware, IBM Z (ZVM), and Ironic as optional drivers loaded via Stevedore entry points.

5. **Cells v2 Architecture** (DEC-005): Cell0 is a metadata-only database; Cell1+ each have their own database, conductor, and compute hosts, enabling horizontal scaling to thousands of compute nodes.

6. **Eventlet Concurrency Model** (DEC-006): Eventlet green threads as the default, with native Python threading fallback, allowing a single process to handle thousands of concurrent connections.

7. **oslo.policy for Authorization** (DEC-007): 56 policy modules defining fine-grained RBAC rules with a custom enforcer entry point.

8. **Stevedore for Scheduler Pluggability** (DEC-008): Pluggable scheduler filters (19 filters) and weight plugins via Stevedore entry points.

9. **oslo.privsep for Privilege Separation** (DEC-009): Privileged operations execute in a separate process via oslo-rootwrap, limiting damage from API layer compromise.

10. **RabbitMQ Messaging** (DEC-010): oslo.messaging with RabbitMQ via Kombu as default transport for inter-service RPC communication.

11. **RPC Chain with State Machine Coordination** (DEC-011): Scheduler → Conductor → Compute RPC chain with cursive for live migration and TooZ for distributed locking.

12. **Modular Configuration** (DEC-012): 48 modular config modules in nova/conf/, aggregated via oslo.config entry point with section names, types, help text, and default values.
