# Portal Integration — OpenStack Nova

## Integration Overview

OpenStack Nova integrates with eight external services and message brokers to provide full compute orchestration capabilities within the OpenStack cloud ecosystem. Each integration has defined data exchange patterns, authentication mechanisms, and failure handling strategies.

| Integration | Type | Purpose | Direction |
|-------------|------|---------|-----------|
| OpenStack Keystone | Identity service | Authentication and RBAC authorization | Inbound (Nova calls Keystone) |
| OpenStack Glance | Image service | VM disk image serving and metadata | Outbound (Nova queries Glance) |
| OpenStack Neutron | Networking service | Virtual network interface, security groups, port management | Bidirectional |
| OpenStack Cinder | Block storage service | Persistent block volume attachment | Bidirectional |
| OpenStack Placement | Resource tracking | Resource provider allocation tracking | Bidirectional |
| RabbitMQ (oslo.messaging) | Message broker | Inter-service RPC communication | Internal (Nova processes) |
| Barbican (castellan) | Secret management | Cryptographic key management | Inbound (Nova queries Barbican) |
| Dogpile.cache (oslo.cache) | Caching layer | Distributed caching | Internal (Nova processes) |

## OpenStack Keystone

### Purpose

OpenStack Keystone provides authentication, token validation, and RBAC authorization for all Nova API requests. Nova relies on Keystone for:
- Token validation for every API request
- Tenant/project context for resource isolation
- Role-based access control enforcement via oslo.policy

### Authentication Flow

1. **Client authenticates** with Keystone `/v3/auth/tokens` endpoint
2. **Keystone issues token** with scopes, project/tenant context, and role assignments
3. **Client presents token** to Nova via X-Auth-Token header
4. **Nova Keystone middleware** validates token by calling Keystone's `/v3/tokens` endpoint
5. **Token validation response** includes user ID, project ID, and roles
6. **oslo.policy** evaluates the relevant policy rule (e.g., `compute:create`, `compute:delete`)
7. **Access granted or denied** based on policy evaluation

### Data Exchanged

| Data | Source | Usage |
|------|--------|-------|
| Token | Keystone → Nova | Per-request authentication |
| User ID | Keystone → Nova | Instance ownership, audit trail |
| Project ID | Keystone → Nova | Resource isolation, quota enforcement |
| Roles | Keystone → Nova | Policy rule evaluation (e.g., `admin`, `member`) |

### API Contract

- **Endpoint:** Keystone admin URL (internal Keystone service endpoint)
- **Protocol:** HTTP/HTTPS JSON API (Keystone v3)
- **Authentication:** nova-api service credentials (username, password, domain)
- **Rate limiting:** Keystone applies rate limits to token validation requests
- **Retry:** nova-api retries failed token validation requests (network failures)

### Error Handling

| Error | Cause | Nova Response |
|-------|-------|---------------|
| 401 Unauthorized | Invalid/expired token | Pass through to client (401) |
| 403 Forbidden | Token valid but insufficient permissions | oslo.policy denies (403 Forbidden) |
| 503 Service Unavailable | Keystone unreachable | nova-api returns 503 to client |
| Timeout | Keystone response timeout | nova-api retries once, then returns 503 |

### Configuration

Nova configures Keystone authentication in nova.conf under `[keystone_authtoken]`:
- `auth_url` — Keystone authentication URL
- `username` — Nova service account username
- `password` — Nova service account password
- `project_domain_name` / `user_domain_name` — Domain configuration
- `auth_type` — Authentication plugin (typically "password")

## OpenStack Glance

### Purpose

OpenStack Glance provides VM disk images that Nova uses to boot instances. Nova interacts with Glance for:
- Image metadata queries (architecture, min disk, min RAM)
- Image property access for scheduler filtering
- Image downloads to compute nodes for instance boot
- Image caching at compute nodes

### Data Exchanged

| Data | Direction | Usage |
|------|-----------|-------|
| Image ID (UUID) | Nova → Glance | Image reference lookup |
| Image metadata | Glance → Nova | Architecture, min disk, min RAM, image_type, disk_format |
| Image properties | Glance → Nova | Custom properties (e.g., hw_disk_bus, hw_scsi_model) for scheduler filtering |
| Image data (stream) | Glance → nova-compute | Disk image download for VM creation |
| Image cache status | nova-compute → internal | Local image cache tracking at compute nodes |

### API Contract

- **Endpoint:** Glance API endpoint (internal Glance service URL)
- **Protocol:** HTTP/HTTPS JSON API (Glance v2)
- **Authentication:** nova-api service credentials (Keystone-authenticated)
- **Image download:** HTTP range requests for large image files (supports resume)
- **Rate limiting:** Glance applies rate limits to metadata and image data requests
- **Timeout:** Configurable timeout for image downloads (large images may take minutes)

### Error Handling

| Error | Cause | Nova Response |
|-------|-------|---------------|
| 404 Not Found | Image does not exist | 404 ImageNotFound to client |
| 403 Forbidden | No access to image | 403 to client (policy check fails) |
| 503 Service Unavailable | Glance unreachable | Build fails with error, retries on next attempt |
| Download timeout | Large image exceeds timeout | nova-compute retries download, may retry with backoff |
| Corrupted image | Image data integrity check fails | nova-compute re-downloads image |

### Error Handling Details

- **Scheduler image property filtering:** If Glance is unreachable during scheduler filtering, the ImagePropertiesFilter uses cached properties or skips the filter (configurable)
- **Image download failure:** nova-compute retries image download with exponential backoff (configurable retry count)
- **Caching:** Compute nodes cache downloaded images locally; on cache hit, Glance is not queried

## OpenStack Neutron

### Purpose

OpenStack Neutron provides virtual networking capabilities that Nova uses to attach instances to networks. Nova interacts with Neutron for:
- Creating and managing network ports (virtual NICs)
- Assigning IP addresses to instances
- Managing security group rules (firewall)
- Querying network topology (subnets, routers)
- Supporting distributed virtual routing (OVS)

### Data Exchanged

| Data | Direction | Usage |
|------|-----------|-------|
| Port creation request | Nova → Neutron | Create network port with MAC, IP, device_id |
| Port data | Neutron → Nova | Port ID, MAC address, IP addresses, network ID |
| Security group rules | Neutron → Nova | Applied as iptables rules on compute node |
| Security group binding | Nova → Neutron | Bind security groups to ports |
| Port update/deletion | Nova → Neutron | On instance resize, migration, delete |

### API Contract

- **Endpoint:** Neutron API endpoint (internal Neutron service URL)
- **Protocol:** HTTP/HTTPS JSON API (Neutron REST API)
- **Authentication:** nova-api and nova-compute service credentials (Keystone-authenticated)
- **Timeout:** Configurable timeout for port operations (typically 30 seconds)
- **Retries:** Configurable retry count for transient failures

### Error Handling

| Error | Cause | Nova Response |
|-------|-------|---------------|
| NetworkNotFound | Referenced network does not exist | 404 to client |
| PortCreationFailed | Neutron cannot create port (e.g., insufficient IP addresses) | Build fails, instance remains in BUILDING state |
| SecurityGroupNotFound | Referenced security group does not exist | 404 to client |
| 503 Service Unavailable | Neutron unreachable | Build fails with error, may retry |
| Timeout | Neutron response timeout | Retry with backoff, then fail build |

### Integration with Security Groups

Nova interacts with Neutron security groups in two modes:
1. **Linux bridge mode:** Nova-managed iptables rules on compute nodes (legacy)
2. **ML2/OVS mode:** Neutron-managed security groups via OVS firewall driver

Security group rules are applied at the Neutron level in ML2 mode, and Nova only handles security group assignment to ports.

## OpenStack Cinder

### Purpose

OpenStack Cinder provides persistent block storage that Nova attaches to instances. Nova interacts with Cinder for:
- Attaching iSCSI and FC volumes to running instances
- Detaching volumes from instances
- Managing volume metadata (size, type, availability zone)
- Supporting boot-from-volume instances
- Exposing volume drivers for different storage backends

### Data Exchanged

| Data | Direction | Usage |
|------|-----------|-------|
| Volume attachment request | Nova → Cinder | Attach volume to instance at compute host |
| Volume data | Cinder → Nova | Volume ID, device path, attachment ID |
| Volume detachment request | Nova → Cinder | Detach volume from instance |
| Volume metadata | Cinder → Nova | Size, type, availability zone, status |
| Boot-from-volume info | Nova → Cinder | Volume ID as boot source |

### API Contract

- **Endpoint:** Cinder API endpoint (internal Cinder service URL)
- **Protocol:** HTTP/HTTPS JSON API (Cinder v2/v3)
- **Authentication:** nova-compute service credentials (Keystone-authenticated)
- **Volume operations:** API calls are synchronous (wait for completion)
- **Timeout:** Configurable timeout for volume attachment/detachment (typically 300 seconds)
- **Retries:** Configurable retry count for transient failures

### Error Handling

| Error | Cause | Nova Response |
|-------|-------|---------------|
| VolumeNotFound | Referenced volume does not exist | 404 to client |
| VolumeAttachmentFailed | Cinder cannot attach volume (e.g., volume in-use) | Instance build/resize fails |
| VolumeNotBootable | Volume cannot boot instance | 400 to client |
| 503 Service Unavailable | Cinder unreachable | Build fails, may retry after backoff |
| Timeout | Cinder response timeout | Retry with backoff, then fail |

## OpenStack Placement

### Purpose

OpenStack Placement provides resource provider tracking and allocation for compute hosts. Nova interacts with Placement for:
- Tracking resource allocation per compute host (vCPUs, memory, disk, custom resources)
- Providing resource utilization data for scheduler filtering
- Accepting resource provider updates from Nova compute
- Supporting custom resource classes and traits

### Data Exchanged

| Data | Direction | Usage |
|------|-----------|-------|
| Resource allocation | Nova → Placement | Reserve vCPUs, memory, disk, custom resources |
| Resource allocation swap | Nova → Placement | Transfer allocations between hosts (migration) |
| Resource release | Nova → Placement | Release allocations (instance delete, resize revert) |
| Resource provider info | Nova → Placement | Register compute host with Placement |
| Resource provider traits | Nova → Placement | Register host capabilities (CPU features, NUMA) |
| Resource utilization | Placement → Nova | Query available resources per host (scheduler filtering) |

### API Contract

- **Endpoint:** Placement API endpoint (internal Placement service URL)
- **Protocol:** HTTP/HTTPS JSON API (Placement v1.0+)
- **Authentication:** nova-compute and nova-scheduler service credentials (Keystone-authenticated)
- **Content-Type:** `application/json`
- **Accept:** `application/json`
- **Timeout:** Very short timeout for scheduler queries (typically 5 seconds) — scheduling is latency-sensitive
- **Retries:** Minimal retries — Placement queries are fast; failures typically indicate misconfiguration

### Error Handling

| Error | Cause | Nova Response |
|-------|-------|---------------|
| 404 Not Found | Resource provider not registered | Scheduler rejects host |
| 409 Conflict | Concurrent modification of allocations | Retry with backoff |
| 422 Unprocessable Entity | Invalid allocation (negative, overflow) | Fail build/migration |
| 503 Service Unavailable | Placement unreachable | Scheduler falls back to cached data or rejects all hosts |
| Timeout | Placement response timeout | Scheduler rejects host, may retry |

### Placement Integration with Scheduler (DEC-008)

The scheduler's Host aggregates filter uses Placement data to determine available resources on each host:
- vCPU count vs. vCPUs used → available vCPUs
- Memory bytes vs. memory bytes used → available memory
- Disk GB vs. disk used → available disk
- Custom resource classes → availability for specialized workloads (GPU, FPGA, etc.)
- Host traits → CPU features, NUMA topology, storage backend type

This is the primary source of truth for resource availability — the scheduler does not trust database-reported values.

## RabbitMQ (oslo.messaging)

### Purpose

RabbitMQ serves as the message broker for inter-service RPC communication within Nova. oslo.messaging with Kombu transport abstracts RabbitMQ for:
- RPC requests between nova-api, nova-scheduler, nova-conductor, and nova-compute
- Message queuing with acknowledgment and delivery guarantees
- Fan-out messaging for broadcast operations
- Dead-letter queues for failed messages

### Architecture (DEC-010)

- **RabbitMQ** — Default message broker, provides message persistence
- **oslo.messaging** — Transport abstraction, supports RabbitMQ, ZeroMQ, in-memory transports
- **Kombu** — RabbitMQ client library with automatic retry, reconnection, and acknowledgment

### Queues

| Queue | Publisher | Consumer | Purpose |
|-------|-----------|----------|---------|
| scheduler | nova-api | nova-scheduler | Build/migration requests |
| scheduler_request_queue | nova-scheduler | nova-conductor | Selected hosts for builds |
| conductor | nova-scheduler, nova-api | nova-conductor | Cell-aware routing, DB operations |
| compute.<hostname> | nova-conductor | nova-compute | VM lifecycle operations |
| cell.<cellname> | nova-conductor (cell0) | nova-conductor (cell1+) | Cross-cell communication |

### Error Handling

| Error | Cause | Nova Response |
|-------|-------|---------------|
| Connection failure | RabbitMQ broker down | oslo.messaging auto-reconnects with exponential backoff |
| Message ack failure | Consumer crashes mid-processing | Message remains unacknowledged, re-delivered on reconnect |
| Queue full | Message production exceeds consumption | oslo.messaging blocks producer until space available |
| Dead letter queue | Message exceeds retry limit | Message moved to DLQ, logged for inspection |

## Barbican (via castellan)

### Purpose

Barbican provides cryptographic key management for Nova features that require encryption, accessed through castellan. Nova interacts with Barbican for:
- Managing encryption keys for instance disk encryption
- Storing and retrieving cryptographic key material
- Supporting key rotation for encrypted volumes

### Data Exchanged

| Data | Direction | Usage |
|------|-----------|-------|
| Key reference (UUID) | Barbican → Nova | Key UUID for encryption operations |
| Key metadata | Barbican → Nova | Key state, creation time, algorithms |
| Encryption operations | Nova → castellan → Barbican | Key access for encryption/decryption |

### Error Handling

| Error | Cause | Nova Response |
|-------|-------|---------------|
| KeyNotFound | Referenced Barbican key does not exist | Build/resize fails |
| 503 Service Unavailable | Barbican unreachable | Use cached key material or fail operation |
| KeyExpired | Key has passed expiration | Key rotation required before operation |

## Dogpile.cache (via oslo.cache)

### Purpose

Dogpile.cache provides a distributed caching layer for Nova, accessed through oslo.cache for:
- Caching frequently accessed data (Flavor, Image, Aggregate lookups)
- Reducing database query load for read-heavy operations
- Caching scheduler filter results

### Data Cached

| Cache Entry | TTL | Purpose |
|-------------|-----|---------|
| Flavor by ID | Configurable | Avoid repeated flavor DB lookups |
| Aggregate by name | Configurable | Avoid repeated aggregate DB lookups |
| Scheduler filter cache | Configurable | Cache filter results for rapid host evaluation |

### Error Handling

| Error | Cause | Nova Response |
|-------|-------|---------------|
| Cache miss | Key not in cache (cold start, expired) | Fall back to database query |
| Cache backend unavailable | memcached/redis unreachable | Cache bypassed, direct DB queries |
| Serialization error | Object cannot be serialized | Cache entry dropped |

## Integration Security

### Authentication Pattern

All Nova-to-external-service calls use Keystone service tokens:
1. Nova service authenticates with Keystone using service credentials (from nova.conf)
2. Keystone issues a service token scoped to the target service
3. Nova presents the service token to the target service
4. The target service validates the token with Keystone

### Network Security

- **Internal endpoints:** All service endpoints use internal (private network) URLs
- **TLS/mTLS:** TLS is configurable for all service endpoints (enabled in production deployments)
- **Firewall rules:** Open security group rules for internal Nova service traffic
- **Secret management:** Barbican stores sensitive credentials (not plain-text in config)

### Credential Storage

| Credential | Storage Location | Notes |
|-----------|-----------------|-------|
| Keystone admin credentials | nova.conf `[keystone_authtoken]` | Plain-text INI config (standard for OpenStack) |
| Barbican master key | Barbican (external) | Never stored in Nova |
| TLS certificates | System certificate store | Managed by deployment tooling |
