# Technology Stack — OpenStack Nova

**Generated:** 2026-08-26
**Project:** OpenStack Nova
**One-liner:** OpenStack's distributed compute service that manages the lifecycle of instances (virtual machines and bare metal) in a cloud infrastructure.

---

## 1. Language & Runtime

| Element | Value |
|---------|-------|
| **Language** | Python |
| **Runtime** | CPython with Eventlet green threads (default), with native threading fallback |
| **Style Guide** | PEP 8, enforced via `pep8` and `stestr` test infrastructure |
| **Concurrency Backend** | `eventlet` (default), configurable to `threading` via `concurrency_backend` option (see DEC-006) |

The project uses the OpenStack oslo library ecosystem exclusively. No asyncio is used; the architecture is built on eventlet green threads with a native threading fallback for compatibility environments (DEC-006).

## 2. Web Framework & API

| Element | Value |
|---------|-------|
| **HTTP Layer** | WSGI (Web Server Gateway Interface) |
| **Pipeline** | PasteDeploy (`api-paste.ini`) |
| **Routing** | Routes library with custom `ProjectMapper` |
| **API Format** | JSON responses only |
| **Versioning** | Microversioning via `X-OpenStack-Nova-API-Version` header (base 2.1, current 2.104) |
| **Versioning ID** | DEC-003 |

The REST API runs as a WSGI application, compatible with any WSGI server in the OpenStack ecosystem. Microversioning allows backward-compatible API evolution without creating permanent URL version branches.

## 3. Database Layer

| Element | Value |
|---------|-------|
| **Primary Database** | PostgreSQL (production default) |
| **Alternative Databases** | MySQL / MariaDB |
| **Test Database** | SQLite |
| **ORM** | SQLAlchemy |
| **Migrations** | Alembic |
| **Session Management** | oslo.db (with automatic retry logic) |

Data models are defined in `nova/db/` using SQLAlchemy ORM, with Shadow tables for soft deletes and audit trails (DEC-002). The ORM sits behind the versioned object layer, which provides API-level backward compatibility (see Section 5).

## 4. Data Model Layer

| Element | Value |
|---------|-------|
| **ORM Layer** | `nova/db/` — SQLAlchemy models |
| **Object Layer** | `nova/objects/` — `oslo.versionedobjects` (65 object classes) |
| **Pattern** | "Smart Managers, Dumb Data" — business logic in managers, plain data in objects |
| **Versioned Objects** | Each object class carries an explicit `VERSION` attribute for API compatibility |

The two-layer data model separates database schema evolution (SQLAlchemy + Alembic) from API version changes (versioned objects). Shadow tables provide soft-delete capability for audit and recovery (DEC-002).

## 5. Messaging & RPC

| Element | Value |
|---------|-------|
| **Library** | oslo.messaging |
| **Transport** | RabbitMQ via Kombu (default) |
| **Alternative Transports** | ZeroMQ, in-memory (configurable) |
| **Purpose** | Inter-service RPC: API → Scheduler → Conductor → Compute |
| **Locking** | TooZ distributed lock groups |
| **State Machine** | cursive (for live migration coordination) |
| **Transport Choice** | DEC-010 |

oslo.messaging provides the RPC channel between all Nova daemons (nova-api, nova-scheduler, nova-conductor, nova-compute) and between Nova and external services (DEC-010). Message persistence on RabbitMQ is essential for build request reliability (DEC-011).

## 6. Virtualization Drivers

| Element | Value |
|---------|-------|
| **Default Driver** | libvirt (KVM/QEMU/LXC/Parallels) |
| **Pluggable Drivers** | Stevedore entry points |
| **Optional Drivers** | VMware, IBM Z (ZVM), bare metal (Ironic) |
| **Driver Interface** | Pluggable via Stevedore |
| **Driver Choice** | DEC-004 |

libvirt is the production default. Alternative hypervisors load via Stevedore entry points without modifying core code. This enables Nova to support heterogeneous hardware (DEC-004).

## 7. Scheduler

| Element | Value |
|---------|-------|
| **Plugin System** | Stevedore entry points |
| **Filters** | 19 pluggable scheduler filters |
| **Weights** | Pluggable weight functions |
| **Base Class** | Custom `RequestFilter` with `get_filters()` and `get_weights()` pattern |
| **Scheduler Choice** | DEC-008 |

Scheduler filters evaluate candidate hosts; weight functions rank them. Operators enable only the filters their deployment requires (DEC-008).

## 8. Authorization & Security

| Element | Value |
|---------|-------|
| **Policy Engine** | oslo.policy |
| **Policy Files** | 56 policy modules |
| **Enforcer** | Custom entry point `nova.policy:get_enforcer` |
| **Privilege Separation** | oslo.privsep with helpers in `nova/privsep/` |
| **Root Command Wrapping** | oslo-rootwrap (whitelist-based) |
| **Authorization Choice** | DEC-007 |
| **Privilege Isolation** | DEC-009 |

oslo.policy provides fine-grained RBAC enforced at every API endpoint. oslo.privsep separates privileged operations (host commands, block device operations) into a separate process, ensuring the untrusted API layer cannot escalate privileges (DEC-009).

## 9. Configuration

| Element | Value |
|---------|-------|
| **Library** | oslo.config |
| **Modules** | 48 config modules in `nova/conf/` |
| **Format** | INI-style with section, type, help text, and defaults |
| **Generator** | oslo-config-generator (entry point registration) |
| **Config Choice** | DEC-012 |

Each Nova subsystem has its own configuration module, mirroring the codebase architecture. The modular approach supports per-subsystem documentation and validation.

## 10. Deployment & Tooling

| Element | Value |
|---------|-------|
| **Deployment Automation** | Ansible roles and playbooks |
| **CI/CD Pipeline** | Zuul |
| **Single-Node Deployment** | Devstack |
| **CI Containerization** | Docker |
| **Test Framework** | stestr (not pytest) |
| **Lint / Style** | pep8 (enforced via tox and stestr) |

## 11. External Service Integrations

Nova integrates with the following OpenStack services and infrastructure components:

| Integration | Purpose |
|-------------|---------|
| **OpenStack Keystone** | Authentication, token validation, RBAC context |
| **OpenStack Glance** | VM disk image serving and metadata |
| **OpenStack Neutron** | Network interface assignment, security groups, port management |
| **OpenStack Cinder** | Block storage volume attach/detach |
| **OpenStack Placement** | Resource provider tracking (vCPUs, memory, disk, custom resources) |
| **Barbican (via castellan)** | Cryptographic key management |
| **Dogpile.cache (via oslo.cache)** | Caching layer |
| **RabbitMQ (via oslo.messaging)** | Inter-service RPC messaging |

## 12. Architecture Decisions Reference

| Decision | Summary |
|----------|---------|
| DEC-001 | Three-process distributed architecture (compute, conductor, scheduler) |
| DEC-002 | Two-layer data model with versioned objects and Shadow tables |
| DEC-003 | REST API with microversioning (2.1 base → 2.104) |
| DEC-004 | libvirt as default driver, pluggable via Stevedore |
| DEC-005 | Cells v2 for horizontal scaling |
| DEC-006 | Eventlet green threads with threading fallback |
| DEC-007 | oslo.policy for fine-grained RBAC (56 policy modules) |
| DEC-008 | Stevedore-based pluggable scheduler filters and weights |
| DEC-009 | oslo.privsep for privilege separation |
| DEC-010 | oslo.messaging with RabbitMQ/Kombu transport |
| DEC-011 | Scheduler → Conductor → Compute RPC chain with cursive state machine |
| DEC-012 | Modular oslo.config options (48 modules) |
