# Portal Integration — OpenStack Nova

**Generated:** 2026-08-26
**Project:** OpenStack Nova
**Dependencies:** STACK.md, INFRASTRUCTURE-ARCHITECTURE.md, TECHNICAL-DRAFT.md (completed)

---

## 1. Integration Overview

Nova integrates with eight external services and infrastructure components. Each integration represents a well-defined boundary where Nova either consumes services, provides services, or both.

### Integration Matrix

| # | Integration | Direction | Protocol | Purpose |
|---|-----------|-----------|----------|---------|
| 1 | OpenStack Keystone | Inbound | HTTP REST | Authentication, token validation, RBAC context |
| 2 | OpenStack Glance | Outbound | HTTP REST | VM disk image serving and metadata |
| 3 | OpenStack Neutron | Bidirectional | RPC (oslo.messaging) | Network interface assignment, security groups |
| 4 | OpenStack Cinder | Bidirectional | RPC (oslo.messaging) | Block storage volume attach/detach |
| 5 | OpenStack Placement | Bidirectional | HTTP REST | Resource provider tracking, vCPU/memory/disk allocation |
| 6 | RabbitMQ (internal) | Bidirectional | AMQP (Kombu) | Inter-service RPC messaging (Nova internal) |
| 7 | Barbican (via castellan) | Outbound | HTTP REST | Cryptographic key management |
| 8 | Dogpile.cache (via oslo.cache) | Internal | Configuration-driven | Caching layer |

---

## 2. OpenStack Keystone Integration

### 2.1 Purpose

OpenStack Keystone is the identity and authentication service for Nova. It validates API request tokens, provides project/tenant context, and enables oslo.policy authorization decisions.

### 2.2 Integration Details

| Attribute | Value |
|-----------|-------|
| **Protocol** | HTTP REST (Keystone API v3) |
| **Library** | `keystonemiddleware` (auth_token middleware) |
| **Auth Mode** | Token validation at every API request |
| **Context** | User ID, project ID, roles, authentication scope |

### 2.3 Authentication Flow

```
Client Request (with Keystone token)
    │
    ▼
┌──────────────────────────────────────────┐
│ nova-api Middleware Stack                 │
│                                           │
│  1. AuthProtocol (keystonemiddleware)     │
│     └─► Token introspection at Keystone   │
│     └─► Extract: user_id, project_id,     │
│             roles, auth_scope              │
│                                           │
│  2. Context Middleware                     │
│     └─► Build request context object      │
│     └─► Attach to WSGI environ            │
│                                           │
│  3. Policy Enforcement                     │
│     └─► oslo.policy check with roles      │
│     └─► 56 policy modules (DEC-007)       │
└──────────────────────────────────────────┘
    │
    ▼
    Allow / Deny
```

### 2.4 Configuration

Relevant config sections:
- `[keystone_authtoken]`: Keystone API endpoint, admin credentials, auth URL
- `[policy]`: Policy enforcement settings

### 2.5 Error Handling

| Scenario | Response |
|----------|----------|
| Token expired/invalid | 401 Unauthorized (Keystone rejects) |
| Token revoked | 401 Unauthorized |
| Token valid but insufficient role | 403 Forbidden (oslo.policy) |
| Keystone service unavailable | 503 Service Unavailable |

---

## 3. OpenStack Glance Integration

### 3.1 Purpose

OpenStack Glance provides VM disk images. Nova queries Glance for image metadata during build and migration, and downloads images to compute nodes when not cached locally.

### 3.2 Integration Details

| Attribute | Value |
|-----------|-------|
| **Protocol** | HTTP REST |
| **Library** | glanceclient |
| **Usage** | Image metadata retrieval, image download to compute |

### 3.3 Integration Points

| Operation | When | Details |
|-----------|------|---------|
| Get image metadata | Build request validation | Check architecture, min_disk, min_ram match flavor |
| Get image metadata | Scheduler filtering | Image properties used by `ImagePropertiesFilter` |
| Download image | Compute node build | Download to `/var/lib/nova/instances/` if not cached |
| Cache check | Before download | Check local cache (image cache on compute nodes) |

### 3.4 Image Properties for Scheduling

Scheduler filters consume Glance image properties:

| Property | Filter | Purpose |
|----------|--------|---------|
| `hw:cpu_arch` | ImagePropertiesFilter | Match CPU architecture (x86_64, ppc64, s390x) |
| `hw:require_hyperthreading` | ImagePropertiesFilter | Detect hyperthreading requirements |
| `hw:sriov_passthrough` | ImagePropertiesFilter | Detect SR-IOV requirements |
| `min_disk` | Build validation | Ensure disk allocation sufficient |
| `min_ram` | Build validation | Ensure memory allocation sufficient |

---

## 4. OpenStack Neutron Integration

### 4.1 Purpose

OpenStack Neutron manages virtual networking. Nova integrates with Neutron to create network interfaces (ports), assign IP addresses, and manage security group rules for instances.

### 4.2 Integration Details

| Attribute | Value |
|-----------|-------|
| **Protocol** | oslo.messaging RPC (not REST) |
| **Library** | neutron-lib |
| **Direction** | Bidirectional |

### 4.3 Integration Points

| Operation | Direction | When |
|-----------|-----------|------|
| Create network port | Nova → Neutron | During instance build |
| Assign IP address | Nova → Neutron | During port creation |
| Associate security groups | Nova → Neutron | During port creation |
| Delete port | Nova → Neutron | During instance deletion |
| Security group updates | Neutron → Nova | When security groups are modified |

### 4.4 Port Lifecycle

```
Instance Build
    │
    ▼
nova-neutron-agent (RPC)
    │
    ├─► Create Port (mac_address, network_uuid, fixed_ips)
    ├─► Attach Security Groups
    └─► Receive: port_id, mac_address, fixed_ip_address
         │
         ▼
    VM spawn with port attached
         │
         ▼
Instance Delete
    │
    ▼
nova-neutron-agent (RPC)
    │
    └─► Delete Port (port_id)
```

### 4.5 Security Groups

Nova integrates with Neutron security groups as the primary firewall mechanism:

| Function | Description |
|----------|-------------|
| Create rules | Nova adds security group rules; Neutron pushes to underlying networking |
| Apply rules | On instance boot, rules are applied via Neutron's agent on the compute node |
| Delete rules | On instance delete, associated rules are removed |

---

## 5. OpenStack Cinder Integration

### 5.1 Purpose

OpenStack Cinder provides persistent block storage. Nova integrates with Cinder to attach and detach iSCSI and Fibre Channel volumes to running instances.

### 5.2 Integration Details

| Attribute | Value |
|-----------|-------|
| **Protocol** | oslo.messaging RPC |
| **Library** | cinderclient / cinder-lib |
| **Direction** | Bidirectional |

### 5.3 Integration Points

| Operation | Direction | When |
|-----------|-----------|------|
| Attach volume | Nova → Cinder | Via `POST /servers/{id}/action {os-attach_volume}` |
| Detach volume | Nova → Cinder | Via `POST /servers/{id}/action {os-detach_volume}` |
| Query volume metadata | Nova → Cinder | Get size, type, availability zone, snapshot info |
| Volume status updates | Cinder → Nova | On volume state changes (in-use, error, etc.) |

### 5.4 Volume Attach Flow

```
Cloud User (Tenant)
    │
    │ POST /servers/{id}/action {os-attach_volume: {volume_id, mountpoint}}
    ▼
nova-api → Validate access, check microversion
    │
    ▼
VolumeManager (manager layer)
    │
    ├─► oslo.privsep: Privileged volume operation (DEC-009)
    │     └─► oslo-rootwrap: Whitelisted block device commands
    │
    ▼
nova-cinder-agent (RPC via oslo.messaging)
    │
    ├─► Cinder: attach_volume(volume_id, instance_uuid, mountpoint)
    │     └─► Cinder manages iSCSI/FC connection
    │     └─► Returns: device_path (e.g., /dev/vdb)
    │
    ▼
nova-compute (target host)
    │
    ├─► Attach block device to VM via libvirt
    │     └─► Update VM XML with disk device
    └─► GuestOS: Device visible to guest
```

### 5.5 Boot-from-Volume

Nova supports booting instances directly from Cinder volumes:

| Step | Description |
|------|-------------|
| 1 | Cinder volume contains a bootable image |
| 2 | Nova creates instance with `image_id = None`, `volume_id` set |
| 3 | Compute attaches volume as boot device |
| 4 | VM boots from the attached volume |
| 5 | Instance lifecycle tied to volume attachment |

---

## 6. OpenStack Placement Integration

### 6.1 Purpose

OpenStack Placement tracks resource utilization (vCPUs, memory, disk, custom resources) at each compute host. Nova queries Placement for resource data during scheduling and updates allocations during instance lifecycle operations.

### 6.2 Integration Details

| Attribute | Value |
|-----------|-------|
| **Protocol** | HTTP REST |
| **Library** | python-placementclient |
| **Direction** | Bidirectional |

### 6.3 Integration Points

| Operation | Direction | When |
|-----------|-----------|------|
| Query resource providers | Placement → Nova | Scheduler queries utilization for filter/weight |
| Query provider usages | Placement → Nova | Scheduler determines available resources |
| Create allocation | Nova → Placement | At instance build (reserve vCPUs, memory, disk) |
| Update allocation | Nova → Placement | During resize (adjust resource counts) |
| Swap allocation | Nova → Placement | During live migration (transfer from source to destination) |
| Delete allocation | Nova → Placement | During instance deletion (release resources) |

### 6.4 Resource Allocation Model

```
ResourceProvider (ComputeHost01)
├── TRAIT: CPU_INFO
├── TRAIT: MEMORY_MB
├── TRAIT: DISK_GB
├── CUSTOM: NVIDIA_GPU  <-- Custom resource classes
│
├── Allocations:
│   ├── instance-aaa: vcpus=4, memory_mb=8192, disk_gb=100
│   ├── instance-bbb: vcpus=2, memory_mb=4096, disk_gb=50
│   └── instance-ccc: vcpus=8, memory_mb=32768, disk_gb=500
│
├── Total Allocated:
│   ├── vcpus: 14 (of 32 available)
│   ├── memory_mb: 45056 (of 65536 available)
│   └── disk_gb: 650 (of 1000 available)
└── Total Reserved (no instance):
    └── vcpus: 2 (for system overhead)
```

### 6.5 Allocation Lifecycle

```
Instance Build:
    Scheduler queries Placement → Get resource utilization
    Conductor creates allocation on selected host

Instance Resize:
    Conductor creates allocation on destination host
    Conductor deletes allocation on source host (after confirmResize)

Instance Live Migration:
    Conductor swaps allocation from source to destination host

Instance Delete:
    Conductor deletes all allocations on the host

Instance Suspend/Resume:
    No allocation changes (resources remain allocated)
```

---

## 7. RabbitMQ Integration (Internal RPC)

### 7.1 Purpose

RabbitMQ via oslo.messaging provides the inter-service RPC messaging fabric that connects all Nova daemons. While technically internal to Nova, RabbitMQ is an external infrastructure dependency.

### 7.2 Integration Details

| Attribute | Value |
|-----------|-------|
| **Protocol** | AMQP 0.9.1 |
| **Library** | oslo.messaging with Kombu transport |
| **Broker** | RabbitMQ (recommended) |
| **Fallback** | ZeroMQ (not recommended), in-memory (testing only) |
| **Message Semantics** | Persistent (for build/migration requests) |

### 7.3 Queue Topology

```
nova-api queues (receive from clients, forward to scheduler/conductor)
    │
nova-scheduler queues (receive build/migration requests)
    │
nova-conductor queues (receive from API/scheduler, dispatch to compute)
    │
nova-compute queues (receive from conductor, dispatch VM operations)

Each daemon runs on one or more hosts; queues are partitioned by:
    - Service name (compute, scheduler, conductor)
    - Host (per-host compute queue)
    - Cell (cell-specific queues for cross-cell routing)
```

### 7.4 Message Durability

| Message Type | Durable Queue | Persistent Message | Rationale |
|-------------|--------------|--------------------|-----------|
| Build requests | Yes | Yes | Must not be lost if broker restarts (DEC-010) |
| Migrations | Yes | Yes | State machine coordination requires reliability |
| Heartbeats | Yes | No | Periodic health check; missed heartbeats are tolerable |
| Status updates | Yes | Yes | Instance state transitions must be recorded |

---

## 8. Barbican Integration (via castellan)

### 8.1 Purpose

Barbican provides cryptographic key management for encrypted volumes. Nova retrieves encryption keys from Barbican via the castellan library when attaching encrypted Cinder volumes.

### 8.2 Integration Details

| Attribute | Value |
|-----------|-------|
| **Protocol** | HTTP REST (Barbican API) |
| **Library** | castellan (key management abstraction) |
| **Direction** | Outbound |

### 8.3 Integration Points

| Operation | When |
|-----------|------|
| Retrieve encryption key | When attaching an encrypted volume |
| Key reference resolution | Map volume encryption key_ref to actual key |
| Key caching | oslo.cache / Dogpile.cache caches retrieved keys |

---

## 9. Dogpile.cache Integration (via oslo.cache)

### 9.1 Purpose

oslo.cache wraps Dogpile.cache to provide a unified caching layer for Nova's frequently accessed data, such as configuration options, computed values, and cached API responses.

### 9.2 Integration Details

| Attribute | Value |
|-----------|-------|
| **Protocol** | Configuration-driven (supports memcached, Redis, file-based) |
| **Library** | oslo.cache (wraps Dogpile.cache) |
| **Direction** | Internal (local caching) |

### 9.3 Cache Usage Areas

| Cache Type | Purpose | TTL |
|------------|---------|-----|
| Configuration cache | Cached oslo.config options | Until config reload |
| Object cache | Cached versioned object lookups | Configurable |
| Resource provider cache | Cached Placement data for scheduler | Configurable, typically short-lived |

---

## 10. Integration Error Handling

### 10.1 Service Availability

| Integration | Failure Mode | Nova Behavior |
|-------------|-------------|---------------|
| Keystone | Down / Unreachable | API rejects all requests with 503 |
| Glance | Down during build | Build fails; instance rolled back |
| Neutron | Down during build | Build fails; port creation error |
| Cinder | Down during attach | Volume attach fails; instance still runs |
| Placement | Down during scheduling | Scheduler cannot determine resource availability |
| Placement | Down during build | Build fails; allocations not committed |
| Barbican | Down during attach | Encrypted volume attach fails |
| RabbitMQ | Down | All inter-service communication fails |

### 10.2 Retry Strategy

Nova uses oslo.db retry logic for database operations. For external service integrations:

| Service | Retry | Backoff | Max Attempts |
|---------|-------|---------|-------------|
| Cinder RPC | Yes | Exponential | Configurable |
| Neutron RPC | Yes | Exponential | Configurable |
| Placement HTTP | Limited | Configurable | Low (short-lived failure assumed) |
| Glance HTTP | Limited | Configurable | Low (image download is not retried aggressively) |

### 10.3 Timeout Configuration

| Integration | Timeout Source |
|-------------|---------------|
| Keystone auth | `keystone_authtoken` config |
| Glance download | `glance` config section |
| Neutron RPC | `neutron` config section |
| Cinder RPC | `cinder` config section |
| Placement HTTP | `placement` config section |
| Barbican (castellan) | `castellan` config |

---

## 11. Integration Security

### 11.1 Authentication Between Services

All Nova-to-service communication is authenticated:

| Integration | Auth Method |
|-------------|-----------|
| Keystone | Service account credentials (admin user) |
| Glance | Keystone token (nova service user) |
| Neutron | Keystone token (nova service user) |
| Cinder | Keystone token (nova service user) |
| Placement | Keystone token (nova service user) |
| Barbican | Keystone token (nova service user, via castellan) |

### 11.2 Service Account

The nova service account in Keystone has:

| Role | Scope |
|------|-------|
| `admin` | `service` project |
| `member` | Individual tenant projects (for API operations) |

The service account credentials are configured in `nova.conf` under `[keystone_authtoken]`.

### 11.3 Network Security

All Nova-to-service traffic should be secured:

- **HTTPS/TLS**: Glance, Placement, Barbican (Keystone optional, internal Keystone often uses HTTP)
- **Internal network**: All inter-service traffic on a dedicated management network
- **Firewall**: Nova compute nodes should only communicate with authorized services
