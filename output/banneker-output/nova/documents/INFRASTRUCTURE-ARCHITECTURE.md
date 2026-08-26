# Infrastructure Architecture — OpenStack Nova

## System Topology

OpenStack Nova follows a distributed multi-process architecture where four service types communicate via RPC over a message broker. The system is organized around cells for horizontal scaling and privilege separation for security.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        API Layer                                    │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐              │
│  │  nova-api    │  │ nova-api     │  │  nova-api     │  ... (W)    │
│  │  (WSGI/      │  │  (WSGI/      │  │  (WSGI/       │              │
│  │   PasteDeploy│  │   PasteDeploy│  │   PasteDeploy)│              │
│  └──────┬──────┘  └──────┬───────┘  └──────┬────────┘              │
│         │                 │                  │                      │
└─────────┼─────────────────┼──────────────────┼──────────────────────┘
          │                 │                  │
          ▼                 ▼                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Message Broker (RabbitMQ)                         │
│              oslo.messaging / Kombu transport                        │
└──────────┬──────────────────────────────────────────┬───────────────┘
           │ RPC/AMQP                                │ RPC/AMQP
           ▼                                         ▼
┌──────────────────────┐          ┌──────────────────────────────────┐
│   nova-conductor     │◄────────►│ nova-scheduler                  │
│   (DB operations)    │          │ (Host selection & filtering)     │
│   Cell-aware routing │          │ (Stevedore filters/weights)      │
└──────┬───────────────┘          └──────────────────────────────────┘
       │ RPC
       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        Cell Layer (Cells v2)                        │
│  ┌────────────────────────────────┐  ┌──────────────────────────┐  │
│  │         Cell0                  │  │        Cell1+            │  │
│  │  (Metadata only, no compute)   │  │  (Compute hosts)         │  │
│  │  ┌─────────────────────────┐   │  │  ┌────────────────────┐  │  │
│  │  │ nova-conductor          │   │  │  │ nova-conductor     │  │  │
│  │  │ (cell0 metadata only)   │   │  │  │ (cell-aware ops)   │  │  │
│  │  └─────────────────────────┘   │  │  └────────┬───────────┘  │  │
│  │                                │  │           │              │  │
│  │                                │  │  ┌────────┴───────────┐  │  │
│  │                                │  │  │   nova-compute(s)   │  │  │
│  │                                │  │  │   (Libvirt/KVM,    │  │  │
│  │                                │  │  │   VMware, Ironic)  │  │  │
│  │                                │  │  └────────────────────┘  │  │
│  └────────────────────────────────┘  └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
           │                                          │
           ▼                                          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        Data Layer                                   │
│  ┌──────────────────┐   ┌─────────────────────────────────────┐     │
│  │   PostgreSQL     │   │      Placement Service               │     │
│  │   (Primary DB)   │   │      (Resource allocations)          │     │
│  │   / MySQL/MariaDB│   │      / RabbitMQ                      │     │
│  └──────────────────┘   └─────────────────────────────────────┘     │
│  ┌──────────────────┐   ┌─────────────────────────────────────┐     │
│  │   SQLite         │   │      Glance                          │     │
│  │   (Test only)    │   │      (VM disk images)                │     │
│  └──────────────────┘   └─────────────────────────────────────┘     │
│                                    ┌─────────────────────────────┐  │
│                                    │      Neutron                  │  │
│                                    │      (Networking)             │  │
│                                    └─────────────────────────────┘  │
│                                    ┌─────────────────────────────┐  │
│                                    │      Cinder                  │  │
│                                    │      (Block storage)         │  │
│                                    └─────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Summary

| Component | Process | Direct DB Access? | Purpose |
|-----------|---------|--------------------|---------|
| nova-api | WSGI workers | No | REST API endpoint, request validation, microversion handling (DEC-003) |
| nova-conductor | Daemon | Yes | Centralized database operations, cell-aware routing (DEC-001, DEC-005) |
| nova-scheduler | Daemon | No | Host selection via filters and weights (DEC-008) |
| nova-compute | Daemon | No | VM lifecycle management via hypervisor drivers (DEC-001, DEC-004) |
| nova-novncproxy | Proxy | No | noVNC console proxy for VM console access |
| Placement | Separate service | No (own DB) | Resource provider tracking and allocation |

### Data Stores

| Store | Description | Usage |
|-------|-------------|-------|
| PostgreSQL (primary) | Production relational database | Instance state, actions, migrations, cell mappings, quotas |
| MySQL/MariaDB (alternative) | Alternative production database | Same schema as PostgreSQL |
| SQLite (test) | Lightweight test database | Test environment fallback |
| Placement database | Own database instance | Resource provider tracking, allocation records |
| Neutron database | Separate OpenStack service database | Port state, network topology |

## Data Flows

### Server Build Flow

1. **Cloud User (Tenant)** authenticates with OpenStack Keystone → submits POST /servers
2. **nova-api** validates microversion, authenticates token via Keystone middleware, applies policy rules (DEC-003, DEC-007)
3. **nova-api** calls ComputeManager.create() → routes to **nova-scheduler** via RabbitMQ (DEC-010)
4. **nova-scheduler** applies filter/weight pipeline (DEC-008):
   - Affinity/anti-affinity filters
   - NUMA topology filter
   - PCI passthrough filter
   - Image properties filter (architecture, min disk, min RAM)
   - Aggregate filters
   - Availability zone filter
5. **nova-scheduler** routes to appropriate **nova-conductor** based on cell mapping (DEC-005)
6. **nova-conductor** routes to target **nova-compute** in the selected cell via RabbitMQ (DEC-010)
7. **nova-compute**:
   - Reserves resource allocations in OpenStack Placement (vCPUs, memory, disk)
   - Downloads image from OpenStack Glance (if not cached locally)
   - Allocates network resources via OpenStack Neutron (creates port, assigns IP)
   - Spawns VM via Libvirt virt driver (DEC-004)
   - Updates Instance state to ACTIVE
8. **nova-compute** updates database through nova-conductor
9. Response flows back to Cloud User (Tenant): 202 Accepted

### Live Migration Flow

1. **Cloud User (Tenant)** submits POST /servers/{id}/action with action=migrate
2. **nova-api** validates microversion for migration features
3. **ComputeManager.migrate_server()** initiates flow
4. **nova-scheduler** selects destination host (DEC-008)
5. **nova-conductor** coordinates migration to destination compute node
6. **Pre-copy phase:** Source nova-compute transfers memory pages over network
7. **cursive** state machine coordinates migration state (DEC-011)
8. **TooZ** lock groups prevent concurrent operations (DEC-011)
9. **Final switch:** Instance paused, state transferred, instance resumed on destination
10. **Placement** resource allocations swapped between source and destination hosts (DEC-011)
11. **nova-conductor** updates Instance.compute_host and Instance.host fields

### Cell Routing Flow

- Cell0 is a metadata-only database with no compute hosts (DEC-005)
- Cell1+ each have independent database, conductor, and compute hosts
- nova-conductor routes build/migration requests to the correct cell based on Instance.cell_mapping
- Cross-cell operations (e.g., migrations between cells) require conductor mediation
- Cell0 stores aggregate metadata, cell mappings, and Instance metadata for hosts in all cells

## Deployment Architecture

### Cell Architecture (DEC-005)

Nova supports multi-cell deployments for horizontal scaling:

- **Cell0** — Central metadata database storing aggregate information, cell mappings, and instance metadata for all cells. Contains no compute hosts.
- **Cell1+** — Each cell is an independent deployment containing:
  - nova-compute nodes (managed within the cell)
  - nova-conductor (cell-specific, handles DB and compute communication)
  - nova-scheduler (cell-specific scheduler scope)
  - Dedicated database instance

Cells can be added, removed, or migrated independently, enabling cloud operators to grow Nova horizontally without a single point of failure.

### Process Isolation (DEC-001)

The three-process architecture separates responsibilities:

- **nova-compute** — Runs on compute nodes, manages VM lifecycle, has no database access
- **nova-conductor** — Centralized service (multiple instances for HA), handles all database operations
- **nova-scheduler** — Stateless service (multiple instances for HA), selects compute hosts

This separation enables:
- Independent scaling of each service type
- Fault isolation (a compute node failure does not affect scheduler or conductor)
- Security (compute nodes have no direct database access)
- Deployment flexibility (compute nodes can run in untrusted tenant environments)

### Deployment Models

| Model | Components | Scale |
|-------|-----------|-------|
| Single-cell (Devstack) | nova-api, nova-conductor, nova-scheduler, nova-compute on one node | Development/testing |
| Multi-cell (production) | Cell0 conductor + Cell1+ with separate conductor, scheduler, compute per cell | Large-scale production |
| HA deployment | Multiple API, conductor, scheduler instances behind load balancer | High availability |

### Configuration (DEC-012)

All Nova services share a unified configuration file (nova.conf) with modular sections:
- 48 config modules under nova/conf/
- Sections: [DEFAULT], [api_database], [database], [keystone_authtoken], [vnc], [libvirt], [scheduler], etc.
- oslo.config provides unified CLI, config file parsing, and runtime reloading
- oslo-config-generator generates reference nova.conf from all config modules

## Security Boundaries

### Trust Zones

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Cloud User  │────►│  nova-api    │────►│ nova-conductor│
│  (Tenant)    │     │  (Untrusted) │     │  (Trusted)   │
│              │     │              │     │              │
│  Cloud Admin │────►│  nova-api    │────►│ nova-compute │
│              │     │              │     │  (Root)      │
└──────────────┘     └──────┬───────┘     └──────┬───────┘
                            │                     │
                            ▼                     ▼
                     ┌──────────────┐     ┌──────────────┐
                     │  RabbitMQ    │     │  Hypervisor  │
                     │  (Trusted)   │     │  (Root)      │
                     └──────┬───────┘     └──────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │ nova-scheduler│
                     │  (Trusted)   │
                     └──────────────┘
```

### Authentication (DEC-003, DEC-007)

- **API Authentication:** Keystone middleware validates every API request token
- **Policy Enforcement:** oslo.policy enforces RBAC at each API endpoint (56 policy modules)
- **Token Scope:** Tokens carry project/tenant context and role assignments
- **Microversion Awareness:** Policy rules can be versioned with microversions

### Privilege Separation (DEC-009)

- nova-compute runs as root (required for hypervisor operations)
- oslo.privsep separates privileged code paths into a separate process
- oslo-rootwrap whitelists allowed host commands
- API-layer code cannot execute privileged operations directly
- Compromised API code is limited to unprivileged database operations via conductor

### Network Security

- nova-compute nodes have no direct database access (database calls go through conductor)
- RPC traffic over RabbitMQ uses TLS/mTLS for transport encryption (configurable)
- Neutron security groups provide VM-level firewall rules
- Barbican/castellan manages encryption key material separately from Nova

## Scalability Considerations

### Horizontal Scaling (DEC-005)

- **Cells v2** enables independent scaling of compute hosts across cells
- Each cell has its own database, conductor, and scheduler
- Cell0 handles metadata aggregation across cells
- Add cells without modifying existing cells

### Concurrency Model (DEC-006)

- nova-api uses Eventlet green threads, handling thousands of concurrent connections per process
- nova-conductor uses native threads for database operations
- nova-compute uses eventlet for concurrent VM operations per node
- Test infrastructure enforces greenlet leak detection to prevent resource exhaustion

### Database Scaling

- **Connection pooling:** oslo.db manages connection pools with automatic retries
- **Cell isolation:** Each cell has its own database, reducing contention
- **Shadow tables:** Soft deletes implemented via parallel tables rather than complex SQL
- **Object versioning:** oslo.versionedobjects provides API-level versioning independent of schema changes (DEC-002)

### Scheduling Scalability (DEC-008)

- Pluggable scheduler filters allow operators to enable only needed filters
- Weight functions are computable in parallel per host
- RequestSpec carries pre-computed resource requirements
- Pluggable architecture allows custom filters for deployment-specific scheduling

## Monitoring & Observability

### Service Health

- **nova-status** command provides health checks for all Nova subsystems
- Service registration in RabbitMQ enables heartbeat monitoring
- nova-manage provides migration and cell management diagnostics

### Logging

- Python logging with context-aware loggers per service
- InstanceAction records track all operations on each Instance
- Actions include start/end timestamps, status, and error information
- All RPC calls are logged with trace context

### Metrics

- Eventlet green thread count and utilization
- Database connection pool metrics (active, idle, waiting)
- RabbitMQ queue depths and message delivery rates
- Scheduler filter/weight execution time
- Cell RPC response latencies

### Audit Trail

- Instance database rows maintain full state history
- InstanceAction table logs every operation with timestamps
- Migration records track migration lifecycle
- Shadow Instance table retains historical state for soft-deleted instances (DEC-002)
- Cell mappings are versioned and auditable
