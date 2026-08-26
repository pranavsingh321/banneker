# Technology Stack — OpenStack Nova

## Stack Overview

OpenStack Nova is a large-scale, distributed Python backend service built entirely on the OpenStack ecosystem of libraries and frameworks. The stack is designed for horizontal scalability, pluggability, and compatibility with the broader OpenStack cloud platform.

| Category | Technology | Purpose |
|----------|-----------|---------|
| Language | Python | Primary programming language |
| Concurrency | Eventlet | Green thread-based non-blocking I/O |
| Web Framework | WSGI / PasteDeploy | HTTP request handling pipeline |
| Routing | Routes | URL mapping with ProjectMapper |
| Database ORM | SQLAlchemy | ORM layer with Shadow table support |
| Database Migration | Alembic | Schema versioning and migration |
| Database Sessions | oslo.db | Session management with retry logic |
| Database (Primary) | PostgreSQL | Production database |
| Database (Alternative) | MySQL/MariaDB | Alternative production database |
| Database (Test) | SQLite | Test environment fallback |
| RPC Transport | oslo.messaging | Inter-service RPC messaging |
| Message Broker | RabbitMQ | Message queue via Kombu |
| Serialization | Kombu | Message delivery with acknowledgments |
| Caching | Dogpile.cache | Distributed caching layer via oslo.cache |
| Authorization | oslo.policy | Fine-grained RBAC (56 policy modules) |
| Configuration | oslo.config | Modular config with 48 modules |
| Privilege Separation | oslo.privsep | Separated privilege execution |
| Command Whitelist | oslo-rootwrap | Explicit whitelist for host commands |
| Distributed Locking | TooZ | Lock groups for distributed operations |
| State Machine | cursive | Live migration coordination |
| Plugin Loading | Stevedore | Dynamic plugin entry points |
| Virtualization Driver | Libvirt | Default hypervisor driver (KVM/QEMU/LXC/Parallels) |
| Alternative Drivers | VMware | VMware vSphere virtualization |
| Alternative Drivers | ZVM | IBM Z (s390x) virtualization |
| Alternative Drivers | Ironic | Bare metal provisioning |
| Security Secrets | Barbican | Cryptographic key management via castellan |
| Deployment | Ansible | Infrastructure deployment automation |
| Test Deployment | Devstack | Single-node OpenStack deployment for testing |
| CI/CD | Zuul | Integration testing pipeline |
| Containerization | Docker | Containerized CI environments |

## Technology Rationale

### Python with Eventlet (DEC-006)

Python was chosen as the primary language for OpenStack services, providing a balance of developer productivity, extensive ecosystem libraries, and readability. Eventlet green threads provide non-blocking I/O at the application level, allowing a single process to handle thousands of concurrent connections. This approach leverages the existing oslo.* library ecosystem which is built on eventlet, avoiding the need to migrate to asyncio. A native Python threading fallback is available via the concurrency_backend configuration option for environments where eventlet is incompatible.

### WSGI and PasteDeploy (DEC-003)

The REST API runs over WSGI with a PasteDeploy pipeline defined in api-paste.ini. This provides a standard deployment interface compatible with all OpenStack services and any WSGI-compliant HTTP server. The middleware stack processes authentication, authorization, and request transformation before reaching the route handlers.

### Routes with ProjectMapper (DEC-003)

URL routing is handled by the Routes library with Nova's custom ProjectMapper, which supports Nova-specific URL patterns including nested resource paths (e.g., `/os-availability-zone`, `/os-instance-actions`). This provides flexible URL mapping without requiring a full web framework.

### SQLAlchemy with Shadow Tables (DEC-002)

SQLAlchemy ORM models reside in nova/db/ with Shadow tables implementing soft deletes. Shadow tables provide audit trails and soft delete capability without complex SQL logic. The model layer separates business logic from data representation, making both independently testable.

### Alembic for Migrations (DEC-002)

Alembic manages database schema versioning, enabling incremental schema changes without breaking existing deployments. Each migration is independently reversible, supporting safe rolling updates across Nova service instances.

### oslo.db with Retry Logic (DEC-002)

oslo.db provides session management with automatic retry on transient database failures (connection drops, lock timeouts). This is critical for a distributed system where database connections may fail intermittently.

### PostgreSQL as Primary Database (DEC-002)

PostgreSQL is the recommended production database for Nova, offering strong consistency, advanced indexing, and reliable transactional guarantees. MySQL/MariaDB is supported as an alternative. SQLite is used only for test environments.

### oslo.messaging with RabbitMQ (DEC-010)

Inter-service RPC communication uses oslo.messaging with RabbitMQ via Kombu as the default transport. RabbitMQ provides message persistence, ensuring that build requests and migration tasks are not lost during broker restarts. oslo.messaging provides a transport abstraction allowing alternative transports (ZeroMQ, in-memory) via configuration.

### oslo.policy with RBAC (DEC-007)

Authorization uses oslo.policy with 56 policy modules covering all API endpoints. Each policy module corresponds to an API module, providing granular control over which roles can perform which actions. A custom policy enforcer entry point (nova.policy:get_enforcer) allows Nova-specific policy behavior.

### oslo.config with Modular Configuration (DEC-012)

Configuration is organized into 48 modular config files under nova/conf/, each corresponding to a Nova subsystem. oslo.config provides unified CLI parsing, config file handling, and runtime reloading. The entry point registration enables oslo-config-generator to produce the complete nova.conf reference file.

### oslo.privsep with oslo-rootwrap (DEC-009)

Privileged operations (host commands, block device operations) are decorated with oslo.privsep decorators and execute in a separate process via oslo-rootwrap. This ensures that even if the API layer is compromised, the damage is limited to unprivileged operations. Rootwrap explicitly whitelists allowed host commands.

### Stevedore for Pluggability (DEC-008)

Stevedore entry points enable dynamic loading of scheduler filters (19 filters) and weight plugins. Different cloud deployments have vastly different scheduling requirements, and pluggable filters allow operators to enable only the filters they need without modifying core code.

### Libvirt as Default Driver (DEC-004)

Libvirt (KVM/QEMU/LXC/Parallels) is the default virtualization driver because it is the most widely deployed virtualization stack in OpenStack environments with the most mature feature set. VMware, IBM Z (ZVM), and Ironic are supported as optional drivers loaded via Stevedore entry points, allowing Nova to support diverse hardware without coupling the core codebase to specific hypervisor logic.

### TooZ and cursive for Distributed Coordination (DEC-011)

TooZ provides distributed lock groups that prevent concurrent operations on the same instance across Nova services. The cursive library provides a formal distributed state machine for live migration, preventing race conditions during the complex pre-copy and switchover phases.

### Barbican and castellan for Secrets (DEC-009)

Barbican provides cryptographic key management, accessed through castellan. This enables Nova to store and manage encryption keys for features like encrypted instance disks without exposing key material to Nova processes.

## Hosting & Infrastructure

OpenStack Nova does not target a specific cloud hosting platform. Instead, it is designed to be deployed on bare metal or virtualized infrastructure using:

- **Ansible playbooks** for infrastructure deployment
- **Devstack** for single-node deployment and testing
- **Docker** for containerized CI environments
- **Zuul** for integration testing pipelines

The distributed architecture (nova-compute, nova-conductor, nova-scheduler as separate daemons) enables deployment across heterogeneous infrastructure, from small single-cell deployments to large multi-cell clouds with thousands of compute nodes (DEC-005).

## Integrations

OpenStack Nova integrates with the following OpenStack services:

| Integration | Purpose |
|-------------|---------|
| OpenStack Keystone | Authentication, authorization, and token validation |
| OpenStack Glance | VM disk image serving and metadata |
| OpenStack Neutron | Virtual network interface assignment, security groups, and port management |
| OpenStack Cinder | Persistent block storage volume attachment and management |
| OpenStack Placement | Resource provider tracking and allocation |

Additional integrations:
- **RabbitMQ via oslo.messaging** — Inter-service RPC messaging transport
- **Barbican via castellan** — Cryptographic key management
- **Dogpile.cache via oslo.cache** — Caching layer

## Dependencies

OpenStack Nova depends on the following major library categories:

- **oslo.* libraries** — oslo.db, oslo.config, oslo.messaging, oslo.policy, oslo.privsep, oslo.rootwrap, oslo.cache (OpenStack shared library suite)
- **SQLAlchemy** — Database ORM
- **Alembic** — Database migration framework
- **Eventlet** — Green thread concurrency
- **Routes** — URL routing
- **PasteDeploy** — WSGI pipeline configuration
- **Stevedore** — Plugin entry point management
- **Kombu** — Messaging abstraction for RabbitMQ
- **TooZ** — Distributed locking primitives
- **cursive** — Distributed state machine
- **castellan** — Cryptographic key abstraction layer

## Constraints

- **No asyncio:** Nova uses eventlet green threads; asyncio is not introduced due to the eventlet-based oslo.* ecosystem (DEC-006)
- **No direct database access from compute nodes:** nova-compute cannot connect directly to the database; all database operations go through nova-conductor (DEC-001)
- **Python 3 only:** Modern Nova requires Python 3.x
- **Microversion compatibility:** API responses vary by microversion (2.1 through 2.104), requiring clients to use appropriate headers (DEC-003)
- **Cell isolation:** Cell0 has no compute hosts; Cell1+ have independent databases and conductors (DEC-005)
- **Root requirements:** nova-compute runs as root for hypervisor operations; privilege separation is mandatory (DEC-009)
