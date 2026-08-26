# Infrastructure Architecture — OpenStack Nova

**Generated:** 2026-08-26
**Project:** OpenStack Nova
**Dependencies:** STACK.md (completed)

---

## 1. Architecture Overview

OpenStack Nova uses a distributed multi-process architecture where each service runs as an independent daemon, communicating via RPC through RabbitMQ (DEC-001). The architecture is designed for horizontal scalability, fault isolation, and security through separation of concerns.

### 1.1 Process Topology

```
                              ┌─────────────────────────────────────────┐
                              │              RabbitMQ                   │
                              │           (oslo.messaging)              │
                              └──────────┬──────────────────────────────┘
                                         │ AMQP
        ┌────────────────────────────────┼────────────────────────────────┐
        │                                │                                │
   ┌────┴────┐                     ┌────┴────┐                     ┌────┴────┐
   │ nova-   │◄── RPC ────────────►│ nova-   │◄── RPC ────────────►│ nova-  │
   │ api     │                     │ conductor│                     │compute│
   │ (WSGI)  │                     │         │                     │ (per  │
   │         │◄── RPC ────────────►│         │◄── RPC ────────────►│ host) │
   └────┬────┘                     └────┬────┘                     └────┬──┘
        │                               │                               │
        │                              ┌┴┐                              │
        │   Keystone (auth)             │V│  ← Virtualization layer     │
        │   Glance (images)             │M│                              │
        │   Neutron (networking)        │ │                              │
        │   Cinder (storage)            │ │                              │
        │   Placement (resources)       │ │                              │
        │                               │ │                              │
   ┌────┴────────────────────────────────┴┴──────────────────────────────┘
   │
   ▼
┌─────────────────────────────────────────────────┐
│              PostgreSQL / MySQL DB               │
│                                                  │
│  ┌──────────┐  ┌──────────────┐  ┌────────────┐ │
│  │ Cell0 DB │  │ Cell1 DB     │  │ Cell N DB  │ │
│  │(metadata)│  │(compute cell)│  │(compute cell)│
│  └──────────┘  └──────────────┘  └────────────┘ │
└─────────────────────────────────────────────────┘
```

### 1.2 Daemon Responsibilities

| Daemon | Process | Scales | DB Access |
|--------|---------|--------|-----------|
| `nova-api` | WSGI HTTP server | Vertically (thread count) | Read-only via conductor |
| `nova-scheduler` | RPC worker pool | Horizontally per cell | Read-only via conductor |
| `nova-conductor` | RPC background worker | Horizontally per cell | Full read/write |
| `nova-compute` | Per-host RPC listener | Horizontally per host | None |

Key constraint: **nova-compute nodes have no direct database access** (DEC-001). All database operations flow through nova-conductor, which centralizes data access and provides a security boundary.

## 2. Cells v2 Architecture

Nova's horizontal scaling is achieved through Cells v2 (DEC-005), which partitions compute resources into independent cells, each with its own database, conductor, and compute hosts.

### 2.1 Cell Hierarchy

```
                    ┌──────────────────────┐
                    │    Cell0 (Global)     │
                    │  Metadata only        │
                    │  Cell mappings        │
                    │  Instance inventory   │
                    └───────┬──────────────┘
                            │ lookup
            ┌───────────────┼───────────────┐
            │               │               │
     ┌──────┴──────┐ ┌──────┴──────┐ ┌──────┴──────┐
     │  Cell1      │ │  Cell2      │ │  Cell N     │
     │  (Region A) │ │  (Region B) │ │  (Region Z) │
     │  ┌─────────┐│ │ ┌─────────┐│ │ ┌─────────┐│
     │  │Conductor││ │ │Conductor││ │ │Conductor││
     │  │Scheduler││ │ │Scheduler││ │ │Scheduler││
     │  │Computes ││ │ │Computes ││ │ │Computes ││
     │  │(host1..)││ │ │(host1..)││ │ │(host1..)││
     │  └─────────┘│ │ └─────────┘│ │ └─────────┘│
     └──────────────┘ └────────────┘ └────────────┘
```

**Cell0** (metadata cell):
- Contains only lightweight instance metadata: UUID, hostname, power state, and cell mapping information.
- No compute resource tracking (vCPUs, memory, disk).
- Used for global instance lookup and routing.
- A single Cell0 exists for the entire Nova deployment.

**Cell1+** (compute cells):
- Each cell has its own full database, conductor, and scheduler.
- Cells track full instance state including compute resource allocations.
- Cells are independent — a failure in one cell does not affect others.
- New cells can be added without downtime.

### 2.2 Cell Routing

Build requests from nova-api are routed to the appropriate cell's conductor:

1. nova-api receives a request and determines which cell the target instance (or new instance) belongs to.
2. For new instances, the API queries Cell0 to identify the cell to target, then routes to that cell's conductor via RPC.
3. The cell's conductor dispatches to the appropriate compute node via the cell's RabbitMQ queue.
4. Cross-cell operations (e.g., live migration between cells) are coordinated by the global conductor layer.

## 3. Infrastructure Components

### 3.1 Nova-API

The HTTP API daemon, running as a WSGI application.

- **Protocol**: HTTP/REST over JSON
- **Server**: Any WSGI-compatible server (Apache mod_wsgi, Nginx/uWSGI, gunicorn)
- **Pipeline**: PasteDeploy `api-paste.ini` defines the middleware chain
- **Concurrency**: Eventlet green threads (default), configurable to native threading (DEC-006)
- **Middleware stack**:
  - Token authentication (OpenStack Keystone)
  - Policy enforcement (oslo.policy, DEC-007)
  - Microversion routing (DEC-003)
  - Request validation and serialization

### 3.2 Nova-Scheduler

The host selection daemon.

- **Input**: Build/migration requests from nova-conductor via RPC
- **Process**:
  1. Receives request from conductor
  2. Queries Placement for resource utilization data
  3. Applies scheduler filters (DEC-008): 19 pluggable filters including Affinity, NUMATopology, PCISteering, AggregateInstanceExtraSpecsFilter, ImagePropertiesFilter, and others
  4. Applies weight functions to rank candidate hosts
  5. Selects the best-fit host
  6. Returns the selected host to the conductor via RPC
- **External dependencies**: OpenStack Placement (resource data), OpenStack Glance (image metadata for filters)

### 3.3 Nova-Conductor

The database access mediator and cell router.

- **Role**: Centralizes all database operations; compute nodes cannot connect to the database directly (DEC-001)
- **Functions**:
  - Routes requests between cells (cell0 → cell1+ routing)
  - Executes database operations on behalf of compute nodes
  - Manages resource allocations in OpenStack Placement
  - Coordinates live migration and resize workflows
  - Manages instance state transitions
- **RPC endpoints**: Receives requests from scheduler and API; dispatches to compute nodes

### 3.4 Nova-Compute

Per-host daemon managing VM lifecycle.

- **Deployment**: One instance per compute host
- **Process**:
  - Listens on RabbitMQ RPC queue for build/migrate/delete requests from conductor
  - Manages the VM lifecycle on its host: spawn, pause, resume, suspend, reboot, migrate, delete
  - Reports heartbeats to scheduler for service health monitoring
  - Updates resource allocations in Placement
  - Handles console proxy connections (noVNC, Spice)
- **Privilege**: Runs as root (required for hypervisor operations); uses oslo.privsep for privilege separation (DEC-009)
- **Virtualization**: Driven by pluggable virt drivers (DEC-004): libvirt/KVM (default), VMware, IBM Z/ZVM, Ironic (bare metal)

## 4. Data Flow

### 4.1 Build Request Flow

```
Cloud User (Tenant)
       │
       │ POST /servers {image_id, flavor_id, network_info}
       ▼
┌───────────────────────────────────────────────────────────────────────┐
│ nova-api (WSGI, Eventlet, Keystone auth, Policy check)                │
│  │                                                                      │
│  ├─► Keystone: Validate token, get project context                      │
│  ├─► oslo.policy: Check authorization (DEC-007)                         │
│  └─► ComputeManager.create()                                           │
│        │                                                                  │
│        │ RPC: Send build request to scheduler                             │
│        ▼                                                                  │
└────────┼────────────────────────────────────────────────────────────────┘
         │ RPC (oslo.messaging, DEC-010)
         ▼
┌───────────────────────────────────────────────────────────────────────┐
│ nova-scheduler                                                         │
│  │                                                                      │
│  ├─► Query Placement: Get resource utilization                          │
│  ├─► Query Glance: Get image metadata                                   │
│  ├─► Apply scheduler filters (DEC-008): Affinity, NUMA, PCI,           │
│  │      Aggregate filters, ImageProperties, etc.                        │
│  ├─► Apply weight functions                                             │
│  └─► Select best host                                                   │
│        │                                                                  │
│        │ RPC: Send selected host + build request to conductor             │
│        ▼                                                                  │
└────────┼────────────────────────────────────────────────────────────────┘
         │ RPC
         ▼
┌───────────────────────────────────────────────────────────────────────┐
│ nova-conductor                                                           │
│  │                                                                        │
│  ├─► Determine target cell (Cell0 lookup → Cell N)                        │
│  ├─► Route to correct cell's conductor                                   │
│  ├─► Create Instance object in database                                  │
│  └─► Reserve resource allocations in Placement                           │
│        │                                                                    │
│        │ RPC: Dispatch build to target compute node                         │
│        ▼                                                                    │
└────────┼──────────────────────────────────────────────────────────────────┘
         │ RPC (cell-aware)
         ▼
┌───────────────────────────────────────────────────────────────────────┐
│ nova-compute (target host)                                               │
│  │                                                                       │
│  ├─► TooZ: Acquire distributed lock on instance (DEC-011)                │
│  ├─► Download image from Glance (if not cached locally)                  │
│  ├─► Allocate network via Neutron: Create port, assign IP                │
│  ├─► Spawn VM via virt driver (libvirt/KVM default, DEC-004)             │
│  ├─► Update Instance object state → ACTIVE                               │
│  ├─► Release TooZ lock                                                    │
│  └─► Heartbeat to scheduler                                               │
│                                                                       │
│  Hypervisor layer: libvirt/KVM/ QEMU/LXC (DEC-004)                       │
└───────────────────────────────────────────────────────────────────────┘
```

### 4.2 Live Migration Flow

```
Cloud User (Tenant)
       │
       │ POST /servers/{id}/action {action: migrate}
       ▼
nova-api → ComputeManager.migrate_server()
       │ RPC
       ▼
nova-scheduler → Select destination host (same filter/weight pipeline)
       │ RPC
       ▼
nova-conductor → Coordinate across cells
       │ RPC
       ▼
nova-compute (destination)
       │
       │ ── cursive state machine (DEC-011) ──►
       │   1. PRE_COPY: Transfer memory pages
       │   2. SET_DEST: Configure destination
       │   3. DRAIN_VM: Pause source instance
       │   4. SWITCH: Transfer state, resume destination
       │   5. COMPLETE: Finalize migration
       │
       │ TooZ lock groups prevent concurrent instance operations
       │ Placement allocations transferred between hosts
       ▼
Instance state: ACTIVE → MIGRATING → VERIFY_RESUME → RESUMED
```

## 5. Security Architecture

### 5.1 Network Security

```
                  ┌─────────────────────┐
   External Users │    nova-api (WSGI)  │
   (REST API)     │  ◄── Keystone auth  │
                  │  ◄── Policy check   │
                  └──────────┬──────────┘
                             │ RPC (internal)
                  ┌──────────┴──────────┐
                  │ nova-scheduler      │◄── Placement (resource data)
                  │ nova-conductor      │◄── PostgreSQL (DB access)
                  └──────────┬──────────┘
                             │ RPC (cell internal)
                  ┌──────────┴──────────┐
                  │ nova-compute (per   │
                  │  host, runs as root)│
                  │                     │
                  │  oslo.privsep (DEC- │
                  │   009): Separated   │
                  │  privileged ops     │
                  │  oslo-rootwrap:     │
                  │  Whitelisted cmds   │
                  └─────────────────────┘
```

Security boundaries:

- **Compute nodes** have no direct database access (DEC-001): All DB operations go through conductor
- **nova-compute** runs as root (required for hypervisor operations) but uses oslo.privsep (DEC-009) to compartmentalize privileged operations
- **OpenStack Keystone** authenticates all API requests and provides project/tenant context
- **oslo.policy** (DEC-007) enforces fine-grained RBAC at every API endpoint
- **oslo-rootwrap** whitelists allowed host commands on compute nodes

### 5.2 Privilege Separation (DEC-009)

```
nova-compute process
  │
  ├─ Unprivileged operations: Manage VM state, read logs, query host info
  │
  └─ Privileged operations (oslo.privsep):
       │
       ├─ Host command execution → oslo-rootwrap (whitelist check)
       ├─ Block device operations (attach/detach iSCSI/FC volumes)
       ├─ Network bridging (create OVS bridges, configure interfaces)
       └─ File system operations (write configuration, create directories)
            │
            ▼
       [Separate privileged helper process]
```

oslo.privsep decorators mark privileged functions; they execute in a separate process via oslo-rootwrap, which enforces a whitelist of allowed host commands.

## 6. Configuration Architecture

Configuration is modular, with 48 config modules in `nova/conf/` (DEC-012):

- Each subsystem has its own configuration section
- Options are defined as oslo.config OPT objects with section, type, help text, and defaults
- oslo-config-generator produces a complete `nova.conf` sample file
- Configuration can be reloaded at runtime

### Key Configuration Areas

| Config Module | Purpose |
|---------------|---------|
| `api` | API server settings, microversion limits |
| `cinder` | Cinder integration (volume attach/detach) |
| `compute` | Compute node settings |
| `conductor` | Conductor service configuration |
| `cells` | Cells v2 settings (cell0/Cell N configuration) |
| `default` | Global defaults |
| `glance` | Glance image service settings |
| `keystone_authtoken` | Keystone authentication |
| `neutron` | Neutron networking settings |
| `placement` | Placement service settings |
| `policy` | Policy enforcement settings |
| `rpc` | Messaging/RPC configuration |

## 7. Deployment Model

### 7.1 Production Deployment

- Deployed via Ansible roles and playbooks
- Each Nova service runs as a separate systemd-managed daemon
- Multiple Nova-API instances behind a load balancer for horizontal scaling
- One nova-scheduler and one nova-conductor per cell
- One nova-compute per compute host
- PostgreSQL or MySQL database (PostgreSQL recommended for production)

### 7.2 Testing & Development

| Tool | Purpose |
|------|---------|
| Devstack | Single-node deployment for development and testing |
| Zuul | CI/CD pipeline for integration testing (gate) |
| Docker | Containerized CI environments |
| stestr | Test execution framework (not pytest) |
| tox | Test environment management |

## 8. Technology Stack Mapping

Infrastructure components are drawn from the documented technology stack (STACK.md):

| Component | Technology | Decision |
|-----------|-----------|----------|
| Process model | Python daemons, Eventlet | DEC-001, DEC-006 |
| RPC transport | oslo.messaging, RabbitMQ/Kombu | DEC-010 |
| Distributed locking | TooZ | DEC-011 |
| Migration coordination | cursive state machine | DEC-011 |
| Pluggable drivers | Stevedore entry points | DEC-004 |
| Pluggable schedulers | Stevedore, RequestFilter base | DEC-008 |
| Policy enforcement | oslo.policy, 56 modules | DEC-007 |
| Privilege separation | oslo.privsep, oslo-rootwrap | DEC-009 |
| Cells partitioning | Cell0 metadata + Cell1+ compute | DEC-005 |
| Database access | oslo.db, SQLAlchemy, Alembic | DEC-002 |
