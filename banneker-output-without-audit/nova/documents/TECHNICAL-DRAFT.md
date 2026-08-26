# Technical Draft — OpenStack Nova

**Generated:** 2026-08-26
**Project:** OpenStack Nova
**Dependencies:** STACK.md, INFRASTRUCTURE-ARCHITECTURE.md (completed)

---

## 1. API Surface

### 1.1 REST API Architecture

The Nova REST API is a WSGI application routed via the Routes library with a custom `ProjectMapper` (DEC-003). All endpoints return JSON. Microversion control is via the `X-OpenStack-Nova-API-Version` request header, with a base version of 2.1 and current development version of 2.104.

#### Versioning Strategy

Microversioning allows API evolution without breaking existing clients (DEC-003). Over 390 microversion changes have been made, reflecting a highly iterative development approach.

- **Base version**: 2.1 (introduced microversioning)
- **Current version**: 2.104 (latest available)
- **Header**: `X-OpenStack-Nova-API-Version: 2.104`
- **Response format**: Varies based on microversion header value
- **Backward compatibility**: Guaranteed within the 2.x family

#### Endpoint Structure

All Nova API endpoints are under `/servers` and `/servers/{id}` resource paths, plus action endpoints under `/servers/{id}/action`:

| Method | Endpoint | Action | Microversion-gated |
|--------|----------|--------|-------------------|
| `POST` | `/servers` | Create (boot) instance | Yes |
| `GET` | `/servers` | List servers (with filters) | Yes |
| `GET` | `/servers/{id}` | Show server details | Yes |
| `PUT` | `/servers/{id}` | Update server (name, metadata) | Yes |
| `DELETE` | `/servers/{id}` | Delete instance | Yes |
| `POST` | `/servers/{id}/action` | Reboot, pause, resume, suspend, migrate, resize, etc. | Yes |
| `POST` | `/servers/{id}/action` | Confirm/Revert resize | Yes |
| `GET` | `/servers/{id}/actions/os-get-vnc-console` | Get console access URL | Yes |
| `GET` | `/servers/{id}/os-console-log` | Get serial console log | Yes |

#### Request Processing Pipeline

```
HTTP Request
    │
    ▼
┌─────────────────────────────────────────────┐
│ WSGI Middleware Stack (PasteDeploy)           │
│                                               │
│  1. Keystone Authentication                  │
│     └─► Validate token, get project context   │
│                                               │
│  2. Policy Enforcement                         │
│     └─► oslo.policy check (DEC-007)           │
│                                               │
│  3. Microversion Routing                       │
│     └─► Parse X-OpenStack-Nova-API-Version    │
│     └─► Route to version-aware controller     │
│                                               │
│  4. Request Validation                         │
│     └─► Schema validation per microversion    │
│     └─► Parameter sanitization                │
│                                               │
│  5. Controller Dispatch                        │
│     └─► Routes → ProjectMapper → Controller  │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│ Controller Layer                             │
│                                               │
│  - ServersController (CRUD)                  │
│  - ServersActionController (reboot, migrate) │
│  - VNCConsoleController (console access)     │
│  - ServerGroupsController (affinity groups)  │
│  - HypervisorsController                     │
│  - AggregatesController                      │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│ Manager Layer                                │
│                                               │
│  - ComputeManager: VM lifecycle operations   │
│  - NetworkManager: Network operations         │
│  - VolumeManager: Volume attach/detach       │
│  - VncConsoleManager: Console ticket creation │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│ Object Layer                                 │
│                                               │
│  - oslo.versionedobjects (65 classes)        │
│  - VERSION attributes for API compat (DEC-002)│
│  - "Smart Managers, Dumb Data" pattern       │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│ Database Layer                               │
│                                               │
│  - SQLAlchemy ORM (nova/db/)                 │
│  - Shadow tables for soft deletes            │
│  - oslo.db session management with retry     │
└─────────────────────────────────────────────┘
```

### 1.2 Error Response Format

| HTTP Code | Error Type | Example |
|-----------|-----------|---------|
| 400 | BadRequest | Invalid microversion header, malformed parameters |
| 400 | BadVersion | Invalid or unsupported `X-OpenStack-Nova-API-Version` |
| 401 | Unauthorized | Keystone rejected token |
| 403 | RequestLimitExceeded | Quota exceeded |
| 404 | FlavorNotFound | Referenced flavor does not exist |
| 404 | ImageNotFound | Referenced image does not exist |
| 404 | NotFound | Resource not found |
| 409 | Conflict | Instance already in conflicting state |
| 500 | ServerErrors | Internal server error |

## 2. Data Model Details

### 2.1 Database Schema Layers

#### SQLAlchemy ORM Layer (`nova/db/`)

Maps directly to database tables:

| Table | Description |
|-------|-------------|
| `instances` | Primary instance records with full state |
| `instance_actions` | Audit trail of all instance operations |
| `migrations` | Migration records with status tracking |
| `resize_requests` | Resize operation records |
| `flavors` | Flavor definitions (vCPU, memory, disk specs) |
| `cell_mappings` | Cell0 mapping metadata |
| `resource_providers` | Placement resource provider records |
| `allocations` | Per-provider resource allocations |
| `shadow_instances` | Soft-deleted instance history |
| `console_tickets` | Console access ticket records |

#### Shadow Table Pattern

Shadow tables (e.g., `shadow_instances`) mirror primary tables with an additional `deleted` column and `deleted_at` timestamp. This enables:

- Audit trails for deleted instances
- Soft-delete capability without complex SQL logic
- Recovery of historical instance data
- DEC-002 rationale: Independent API-level changes from schema changes

### 2.2 Versioned Object Layer

65 oslo.versionedobjects classes provide API-level data abstraction (DEC-002):

```
┌─────────────────────────────────────────────┐
│ API Layer                                    │
│  (microversion-aware response formats)       │
└──────────┬──────────────────────────────────┘
           │
┌──────────▼──────────────────────────────────┐
│ Versioned Objects (oslo.versionedobjects)    │
│                                               │
│  Instance.VERSION = "8.0"                     │
│  InstanceAction.VERSION = "2.1"               │
│  Migration.VERSION = "3.0"                    │
│  Flavor.VERSION = "2.2"                       │
│  Cell.VERSION = "1.0"                         │
│  ... (65 classes total)                       │
│                                               │
│  Each object carries explicit VERSION attrs  │
│  enabling API backward compatibility          │
│  independent of DB schema changes             │
└──────────┬──────────────────────────────────┘
           │
┌──────────▼──────────────────────────────────┐
│ SQLAlchemy ORM (nova/db/)                    │
│                                               │
│  Instance → instances table                  │
│  InstanceAction → instance_actions table     │
│  Migration → migrations table                │
│  ShadowInstance → shadow_instances table     │
│  ...                                         │
│                                               │
│  "Smart Managers, Dumb Data" pattern         │
│  Business logic in managers, plain data in    │
│  ORM models                                   │
└──────────────────────────────────────────────┘
```

### 2.3 Key Entity Relationships

```
┌──────────────┐      1:N      ┌─────────────────┐
│  Flavor      │◄─────────────►│  Instance       │
│  (vCPU,mem)  │               │  (active)       │
└──────────────┘               └────────┬────────┘
                                        │ 1:N
                                        ▼
                              ┌─────────────────┐
                              │  InstanceAction │
                              │  (audit trail)  │
                              └─────────────────┘

┌──────────────┐      1:N      ┌─────────────────┐
│  Cell        │◄─────────────►│  Instance       │
│  (Cell0/Cell1│               │  (metadata)     │
└──────────────┘               └─────────────────┘

┌──────────────────┐      1:1      ┌─────────────────┐
│  ResourceProv-   │◄─────────────►│  ComputeNode    │
│  ider            │               │  (Nova record)  │
└──────────────────┘               └────────┬────────┘
                                            │ 1:N
                                            ▼
                                  ┌─────────────────┐
                                  │  Allocation     │
                                  │  (vCPU,mem,disk)│
                                  └─────────────────┘
```

## 3. RPC Communication Protocol

### 3.1 Inter-Service Messaging

All Nova services communicate via oslo.messaging over RabbitMQ (DEC-010):

```
┌─────────────┐    ┌──────────────────────────┐    ┌─────────────┐
│ nova-api    │    │   RabbitMQ (oslo.messaging│    │ nova-sched  │
│ (API server)│◄──►│   AMQP transport via      │◄──►│ (Host       │
│             │   │   Kombu                   │    │  selection) │
└─────────────┘    └──────────┬───────────────┘    └─────────────┘
                              │
                              │
                    ┌─────────▼─────────┐    ┌─────────────┐
                    │ nova-conductor    │    │ nova-compute│
                    │ (DB mediator,     │◄──►│ (Per-host   │
                    │  cell router)     │    │ VM manager) │
                    └───────────────────┘    └─────────────┘
```

### 3.2 RPC Chain for Build Requests (DEC-011)

```
nova-api ──RPC──► nova-scheduler ──RPC──► nova-conductor ──RPC──► nova-compute
```

The three-step RPC chain ensures:

1. **Resource coordination**: Placement resource allocation
2. **Database consistency**: Conductor mediates all database operations
3. **Cell awareness**: Requests routed to correct cell's conductor

### 3.3 Message Semantics

| Message Type | Direction | Semantics |
|-------------|-----------|-----------|
| Build request | API → Scheduler → Conductor → Compute | Fire-and-forget with acknowledgment |
| Lifecycle update | Compute → Conductor → API response | Request-response pattern |
| Heartbeat | Compute → Scheduler | Periodic health check (TTL-based) |
| Migration request | API → Scheduler → Conductor → Compute (src + dst) | Coordinated multi-hop |

### 3.4 Distributed Locking (TooZ)

TooZ lock groups prevent concurrent operations on the same instance:

```python
# Example: Lock acquired during instance build
with tooz_lock_group("instance", instance_uuid):
    # Only one operation per instance at a time
    compute_manager.create(...)
```

This prevents race conditions during build, migration, and resize operations (DEC-011).

## 4. State Machine: Live Migration (cursive)

The cursive library provides a formal distributed state machine for live migration (DEC-011):

```
┌─────────────────────────────────────────────────────────────┐
│ Migration State Machine (cursive)                            │
│                                                              │
│  INITIAL                                                     │
│    │                                                         │
│    ▼                                                         │
│  CHECK_CELL0 ──► CELL0_OK                                    │
│    │                                  │                      │
│    ▼                                  ▼                      │
│  CHECK_NEW_CELL              CELL_MIGRATION                  │
│    │                                  │                      │
│    ▼                                  ▼                      │
│  DESTINATION_READY           PREPARE                           │
│    │                                  │                      │
│    ▼                                  ▼                      │
│  START_VM              PRE_COPY ──► DRAIN_VM                   │
│    │                    │              │                      │
│    │                    │              ▼                      │
│    │                    │           SWITCH                      │
│    │                    │              │                      │
│    │                    │              ▼                      │
│    │                    │           DESTROY_SRC                │
│    │                    │              │                      │
│    │                    ▼              ▼                      │
│    │                COMPLETE ◄─────────┘                      │
│    │                                                         │
│    ▼                                                         │
│  FAILED (revert path) ──► ERROR                              │
│                                                              │
│ TooZ lock: One migration per instance at a time              │
└─────────────────────────────────────────────────────────────┘
```

## 5. Virtualization Driver Architecture (DEC-004)

### 5.1 Pluggable Driver Model

```
┌─────────────────────────────────────────────────────────┐
│ nova-compute                                             │
│                                                         │
│  VirtAPI (hypervisor interface)                         │
│    │                                                    │
│    ▼                                                    │
│  DriverLoader (Stevedore)                                │
│    │                                                    │
│    ├──► LibvirtDriver (KVM/QEMU/LXC/Parallels) [default]│
│    ├──► VMwareVCDriver                                  │
│    ├──► IBMZVMDriver                                    │
│    └──► IronicDriver (bare metal)                       │
│                                                         │
│  Each driver implements:                                 │
│    - spawn() / destroy()                                 │
│    - live_migrate()                                      │
│    - reboot() / power_on() / power_off()                 │
│    - get_info()                                          │
│    - get_diagnostics()                                   │
│    - attach/detach_volume()                              │
└─────────────────────────────────────────────────────────┘
```

Drivers are loaded via Stevedore entry points at startup. The default is LibvirtDriver; alternative drivers are selected via configuration.

### 5.2 Hypervisor Operations

| Operation | libvirt/KVM | VMware | IBM Z (ZVM) | Ironic (bare metal) |
|-----------|-----------|--------|-------------|-------------------|
| Spawn VM | `virsh create` | VIAPI | z/VM commands | PXE boot |
| Live Migrate | libvirt live migration | VMware vMotion | z/VM CP Migrate | Not supported |
| Snapshot | libvirt snapshot | VMware snapshots | N/A | N/A (no VM) |
| Console (VNC) | libvirt VNC | VNC proxy | Console server | IPMI/Redfish |

## 6. Scheduler Plugin Architecture (DEC-008)

### 6.1 Filter Pipeline

```
Request from conductor
    │
    ▼
┌─────────────────────────────────────────────────┐
│ RequestFilter.get_filters() → [Filter1, Filter2… │
│                             Filter19]            │
└─────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────┐
│ Filter 1: HostFilter (basic requirements)       │
│    ├─► AggregateInstanceExtraSpecsFilter         │
│    ├─► NUMATopologyFilter                        │
│    ├─► PCISteeringFilter                         │
│    └─► ... (19 filters total, pluggable)        │
└─────────────────────────────────────────────────┘
    │ (candidate hosts only)
    ▼
┌─────────────────────────────────────────────────┐
│ WeightFilter.get_weights() → [WeightFn1, …]     │
│    ├─► WeightFilter (balanced resource usage)    │
│    ├─► RAMWeightFilter                           │
│    └─► AggregateInstanceExtraSpecsWeightFilter   │
└─────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────┐
│ HostScore = Σ(filter_score × weight_factor)     │
│ Select host with highest score                  │
└─────────────────────────────────────────────────┘
```

Operators enable only the filters and weights needed for their deployment. Stevedore entry points allow custom filter and weight development.

## 7. Authorization Enforcement (DEC-007)

### 7.1 Policy Check Flow

```
API Request (e.g., POST /servers)
    │
    ▼
┌──────────────────────────────────────┐
│ Middleware Stack (PasteDeploy)        │
│                                       │
│  Keystone middleware                  │
│    └─► Get user role context           │
│                                       │
│  Policy middleware (oslo.policy)      │
│    └─► Load policy module for endpoint │
│    └─► Check: "compute:create"        │
│    └─► Check: "compute:create:tags"   │
│                                       │
│  Nova custom enforcer                 │
│    └─► nova.policy:get_enforcer        │
│    └─► Custom Nova-specific rules      │
└──────────────────────────────────────┘
    │
    ▼
│ Allow → Process request               │
│ Deny →  403 Forbidden                 │
```

### 7.2 Policy File Organization

56 policy modules correspond to API modules, providing granular control:

| Policy Module | API Area |
|---------------|----------|
| `compute` | Server CRUD, actions |
| `compute/atomic_operations` | Live migration, resize |
| `compute/atomic_operations/attach_volume` | Volume attachment |
| `compute/atomic_operations/detach_volume` | Volume detachment |
| `compute/service_actions` | Pause, suspend, resume |
| `compute/availability_zone` | Availability zone management |
| `compute/migrations` | Migration operations |
| `identity` | Keystone integration |
| `network` | Neutron integration |
| `osapi_v3` | API v3 endpoints |
| `privileged` | Privileged operations |
| ... | (56 total) |

## 8. Integration Points Detail

### 8.1 OpenStack Placement Integration

- **Purpose**: Track and allocate vCPUs, memory, disk, and custom resources per compute host
- **Protocol**: HTTP REST API
- **Operations**:
  - `GET /resources`: Query resource allocations for a provider
  - `PUT /resources`: Update resource allocations
  - `POST /allocations`: Create resource allocations for an instance on a host
  - `DELETE /allocations`: Release resource allocations
- **Timing**: Allocations reserved at build time, swapped during migration, released on delete

### 8.2 OpenStack Neutron Integration

- **Purpose**: Virtual network interface management
- **Protocol**: oslo.messaging RPC
- **Operations**:
  - Create network port for instance
  - Assign IP address to port
  - Apply security group rules
  - Delete port on instance deletion

### 8.3 OpenStack Cinder Integration

- **Purpose**: Block storage volume management
- **Protocol**: oslo.messaging RPC
- **Operations**:
  - Attach iSCSI/FC volume to instance (requires root privilege, oslo.privsep: DEC-009)
  - Detach volume from instance
  - Query volume metadata (size, type, availability zone)
  - Boot-from-volume support

### 8.4 OpenStack Glance Integration

- **Purpose**: VM disk image serving
- **Protocol**: HTTP REST
- **Operations**:
  - Get image metadata (architecture, min disk, min RAM)
  - Download image to compute node (if not cached locally)
  - Image properties used by scheduler filters (e.g., `hw:cpu_arch`)

### 8.5 Barbican Integration (via castellan)

- **Purpose**: Cryptographic key management for instance encryption
- **Protocol**: HTTP REST (via castellan library)
- **Operations**: Retrieve encryption keys for encrypted volumes

## 9. Configuration Architecture (DEC-012)

48 modular config modules in `nova/conf/`, each defining oslo.config OPT objects:

```
nova.conf (aggregate)
├── [DEFAULT]                    (global defaults)
├── [api]                       (API server settings)
├── [cinder]                    (Cinder integration)
├── [compute]                   (compute node config)
├── [conductor]                 (conductor service)
├── [cells]                     (cells v2 config)
├── [default]                   (common defaults)
├── [glance]                    (Glance integration)
├── [keystone_authtoken]        (Keystone auth)
├── [neutron]                   (Neutron integration)
├── [placement]                 (Placement service)
├── [policy]                    (policy settings)
├── [rpc]                       (messaging config)
├── [vnc]                       (VNC proxy settings)
├── [spice]                     (Spice console)
├── ... (48 modules total)
└── [privsep]                   (privilege separation)
```

Each module defines options with section, name, type, help text, and default value. oslo-config-generator produces a complete `nova.conf` sample.
