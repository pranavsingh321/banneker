# Technical Draft — OpenStack Nova

## Data Model

### Core Entities

#### Instance

The central entity representing a virtual machine or bare-metal instance managed by OpenStack Nova.

| Attribute | Type | Constraint | Description |
|-----------|------|------------|-------------|
| uuid | string (UUID) | Primary key, required | Unique identifier for the instance |
| hostname | string | Optional | Instance hostname (defaults to uuid) |
| launch_index | integer | Default 0 | Boot index within a server group |
| name | string | Optional | Human-readable display name |
| user_id | string | Required | Keystone user ID that owns the instance |
| project_id | string | Required | Keystone project/tenant ID |
| image_ref | string | Nullable | Reference to Glance image (nullable for resize) |
| root_gb | integer | Nullable | Root disk size in GB |
| ephemeral_gb | integer | Nullable | Ephemeral disk size in GB |
| flavor_id | string | Required | Reference to flavor specification |
| vm_mode | string | Default xml | VM startup mode: xen:pv, xen:hvm, kvm:libvirt, etc. |
| scheduled_at | datetime | Nullable | Timestamp of scheduler selection |
| created_at | datetime | Required | Record creation timestamp |
| updated_at | datetime | Nullable | Last update timestamp |
| deleted_at | datetime | Nullable | Soft delete timestamp |
| deleted | integer | Default 0 | Soft delete flag |
| locked | boolean | Default False | Instance lock status |
| locked_by | string | Nullable | Lock holder (process, uuid) |
| power_state | integer | Default 4 | Power state (NOSTATE=0, RUNNING=1, SHUTDOWN=4, etc.) |
| task_state | string | Nullable | Current task state (resize_migrate, etc.) |
| vm_state | string | Default stopped | Virtual machine state (stopped, running, paused, etc.) |
| progress | integer | Default 0 | Operation progress (0-100) |
| availability_zone | string | Nullable | Availability zone for placement |
| host | string | Nullable | Current compute host |
| scheduled_host | string | Nullable | Scheduled compute host |
| node | string | Nullable | Physical node identifier |
| cell_name | string | Nullable | Cell name for cell-aware routing |
| architecture | string | Nullable | Guest OS architecture |
| os_type | string | Nullable | Guest OS type |
| guest_id | string | Nullable | Guest OS BIOS UUID |
| launch_time | datetime | Nullable | Instance launch timestamp |
| disable_terminator | boolean | Default False | Disable delete on host down |

**Relationships:**
- Belongs to one Flavor
- Belongs to one Project (OpenStack Keystone)
- References one Image (OpenStack Glance)
- May have many InstanceActions
- May have many VirtualInterfaces
- May have many BlockDeviceMapping
- May have one Migration (during migration operations)
- May have one ResizeRequest (during resize operations)

#### InstanceAction

Tracks individual operations performed on an Instance, providing audit trail and diagnostic information.

| Attribute | Type | Constraint | Description |
|-----------|------|------------|-------------|
| uuid | string (UUID) | Primary key | Unique action identifier |
| action | string | Required | Action name (e.g., "migrate_server", "reboot", "resize") |
| operation | string | Required | Operation name (e.g., "start", "end", "error") |
| start_task_at | datetime | Nullable | Task start timestamp |
| end_task_at | datetime | Nullable | Task end timestamp |
| state | string | Required | Task state (running, finished, error) |
| expected_event | string | Nullable | Expected next event in task chain |
| created_at | datetime | Required | Record creation timestamp |
| updated_at | datetime | Nullable | Last update timestamp |
| deleted_at | datetime | Nullable | Soft delete timestamp |
| deleted | integer | Default 0 | Soft delete flag |

**Relationships:**
- Belongs to one Instance
- May contain sub-task Event records

#### InstanceActionEvent

Sub-task details within an InstanceAction for granular tracking.

| Attribute | Type | Constraint | Description |
|-----------|------|------------|-------------|
| action_id | string (UUID) | Foreign key → InstanceAction | Parent action |
| event | string | Required | Event name (e.g., "pre_schedule") |
| event_time | datetime | Required | Event timestamp |
| message | string | Nullable | Human-readable event message |
| created_at | datetime | Required | Record creation timestamp |

### Scheduler Entities

#### RequestSpec

Carries scheduling context and resource requirements for a build or migration request.

| Attribute | Type | Constraint | Description |
|-----------|------|------------|-------------|
| uuid | string (UUID) | Primary key | Request specification identifier |
| instance_uuid | string | Required | Associated Instance UUID |
| instance_type | string | Required | Flavor reference |
| requested_properties | JSON | Nullable | Scheduler filter requirements |
| requested_capabilities | JSON | Nullable | Weight function parameters |
| instance_group_policy | JSON | Nullable | Server group affinity/anti-affinity policy |
| created_at | datetime | Required | Creation timestamp |
| updated_at | datetime | Nullable | Last update timestamp |

### Cell Entities

#### CellMapping

Defines the topology of cells within the Nova deployment.

| Attribute | Type | Constraint | Description |
|-----------|------|------------|-------------|
| uuid | string (UUID) | Primary key | Cell mapping identifier |
| name | string | Required | Cell name ("cell0" is reserved for metadata) |
| transport_url | string | Required | RabbitMQ transport URL |
| database_connection | string | Required | Cell-specific database connection (cell0=None) |
| created_at | datetime | Required | Creation timestamp |
| updated_at | datetime | Nullable | Last update timestamp |

#### ComputeNode

Tracks resource allocation data for a compute host.

| Attribute | Type | Constraint | Description |
|-----------|------|------------|-------------|
| uuid | string (UUID) | Primary key | Compute host identifier |
| host_name | string | Required | Hostname of the compute node |
| vcpus_used | integer | Default 0 | Reserved vCPUs |
| vcpus | integer | Required | Total vCPUs |
| memory_bytes_used | bigint | Default 0 | Reserved memory (bytes) |
| memory_bytes | bigint | Required | Total memory (bytes) |
| local_gb_used | bigint | Default 0 | Reserved local disk (GB) |
| local_gb | bigint | Required | Total local disk (GB) |
| disk_available_least | bigint | Nullable | Minimum available disk |
| hypervisor_type | string | Required | Hypervisor type (kvm, lxc, esx, etc.) |
| hypervisor_version | integer | Nullable | Hypervisor version |
| cpu_allocation_ratio | float | Required | CPU overcommit ratio |
| ram_allocation_ratio | float | Required | Memory overcommit ratio |
| disk_allocation_ratio | float | Required | Disk overcommit ratio |
| running_vms | integer | Default 0 | Number of running VMs |
| current_workload | integer | Default 0 | Current workload (running VMs) |
| created_at | datetime | Required | Creation timestamp |
| updated_at | datetime | Nullable | Last update timestamp |
| deleted_at | datetime | Nullable | Soft delete timestamp |

### Migration Entities

#### Migration

Tracks a migration operation between compute hosts.

| Attribute | Type | Constraint | Description |
|-----------|------|------------|-------------|
| id | integer | Primary key | Migration identifier (auto-increment) |
| instance_uuid | string | Required | Target Instance UUID |
| source_compute | string | Required | Source compute host |
| dest_compute | string | Nullable | Destination compute host (set at creation) |
| source_node | string | Nullable | Source physical node |
| dest_node | string | Nullable | Destination physical node |
| migration_type | integer | Nullable | Migration type code |
| status | string | Required | Migration status (check_cell0, check_source, pre_live_migration, etc.) |
| token | string | Nullable | Migration token for destination auth |
| version | integer | Required | Migration object version |
| created_at | datetime | Required | Creation timestamp |
| updated_at | datetime | Nullable | Last update timestamp |
| dest_host_bytes | bigint | Nullable | Destination host allocated bytes |
| dest_cpus | integer | Nullable | Destination CPU allocation |
| dest_disks | bigint | Nullable | Destination disk allocation |
| dest_ram | integer | Nullable | Destination RAM allocation |
| created_at | datetime | Required | Record creation timestamp |

### Resize Entities

#### ResizeRequest

Tracks resize (flavor change) operations.

| Attribute | Type | Constraint | Description |
|-----------|------|------------|-------------|
| id | integer | Primary key | Resize request identifier |
| instance_uuid | string | Required | Target Instance UUID |
| old_instance_type_id | string | Required | Previous flavor UUID |
| new_instance_type_id | string | Required | New flavor UUID |
| source_compute | string | Nullable | Source compute host |
| dest_compute | string | Nullable | Destination compute host |
| status | string | Required | Resize status (confirmed, reverted, post-copy-migrate, etc.) |
| created_at | datetime | Required | Creation timestamp |
| updated_at | datetime | Nullable | Last update timestamp |

### Flavor Entities

#### Flavor

Defines instance resource specifications (tuples).

| Attribute | Type | Constraint | Description |
|-----------|------|------------|-------------|
| id | integer or string | Primary key | Flavor identifier (UUID or alias) |
| name | string | Required | Human-readable name ("m1.tiny", "m1.large", etc.) |
| vcpus | integer | Required | Number of vCPUs |
| memory_mb | integer | Required | Memory in MB |
| disk | integer | Required | Root disk in GB |
| ephemeral | integer | Default 0 | Ephemeral disk in GB |
| swap | integer | Default 0 | Swap in MB |
| rxtx_factor | float | Default 1.0 | Network bandwidth factor |
| vcpus_weight | integer | Nullable | CPU scheduling weight |
| is_public | boolean | Default True | Visible to all projects |
| created_at | datetime | Required | Creation timestamp |
| updated_at | datetime | Nullable | Last update timestamp |
| deleted | integer | Default 0 | Soft delete flag |
| deleted_at | datetime | Nullable | Soft delete timestamp |
| properties | JSON | Nullable | Flavor extra-spec properties |

## API Surface

### REST API Overview

OpenStack Nova exposes a REST API over WSGI with microversioned JSON responses (DEC-003). The API base path is `/v2.1` with the microversion specified via the `X-OpenStack-Nova-API-Version` header (base version 2.1, current version 2.104).

### Core Resource Endpoints

#### Servers (Instances)

| Method | Path | Description | Microversion |
|--------|------|-------------|--------------|
| GET | `/servers` | List all servers (paginated) | 2.1+ |
| GET | `/servers/{server_id}` | Show server details | 2.1+ |
| POST | `/servers` | Create a new server | 2.1+ |
| PUT | `/servers/{server_id}` | Update server (name, metadata) | 2.2+ |
| DELETE | `/servers/{server_id}` | Delete a server | 2.1+ |

##### GET /servers (List Servers)

**Query Parameters:**
- `status` — Filter by vm_state (active, shutdown, error, etc.)
- `image_id` — Filter by image reference
- `flavor_id` — Filter by flavor reference
- `host` — Filter by compute host
- `project_id` — Filter by project/tenant
- `name` — Filter by server name
- `limit` — Maximum results per page
- `marker` — Pagination marker UUID
- `changes-since` — ISO 8601 timestamp for changes since

**Response:** 200 OK with paginated server list

##### POST /servers (Create Server)

**Request Body:**
```json
{
  "server": {
    "name": "my-instance",
    "image_id": "image-uuid",
    "flavor_id": "flavor-uuid",
    "networks": [{"uuid": "network-uuid"}],
    "availability_zone": "nova",
    "user_data": "base64-encoded-script",
    "config_drive": true,
    "metadata": {"key": "value"},
    "max_count": 1,
    "min_count": 1
  }
}
```

**Response:** 202 Accepted with server object containing id, status, and links

##### PUT /servers/{server_id} (Update Server)

**Request Body:**
```json
{
  "server": {
    "name": "new-name",
    "metadata": {"key": "value"}
  }
}
```

**Response:** 200 OK with updated server object

##### DELETE /servers/{server_id} (Delete Server)

**Response:** 202 Accepted

#### Server Actions

| Method | Path | Description |
|--------|------|-------------|
| POST | `/servers/{server_id}/action` | Perform server action |

##### POST /servers/{server_id}/action

**Action Types:**
| Action | Description | Microversion |
|--------|-------------|--------------|
| reboot | Reboot the instance | 2.1+ |
| restart | Hard or soft restart | 2.1+ |
| pause | Pause the running instance | 2.1+ |
| unpause | Unpause a paused instance | 2.1+ |
| suspend | Suspend the instance | 2.1+ |
| resume | Resume a suspended instance | 2.1+ |
| stop | Stop the instance (graceful shutdown) | 2.88+ |
| start | Start a stopped instance | 2.88+ |
| lock | Lock the instance (prevent operations) | 2.1+ |
| unlock | Unlock the instance | 2.1+ |
| migrate | Live migrate the instance | 2.15+ |
| shelve | Shelve the instance (save to storage) | 2.1+ |
| unshelve | Unshelve the instance | 2.1+ |
| rescue | Rescue the instance to recovery mode | 2.1+ |
| unrescue | Unrescue the instance | 2.1+ |
| rebuild | Rebuild the instance (replace disk) | 2.1+ |
| resize | Resize the instance (change flavor) | 2.1+ |
| confirmResize | Confirm resize operation | 2.1+ |
| revertResize | Revert resize operation | 2.1+ |
| createBackup | Create an instance backup | 2.1+ |

**Request Body (example - resize):**
```json
{
  "resize": {
    "flavorRef": "flavor-uuid"
  }
}
```

##### POST /servers/{server_id}/action (Resize Confirmation)

**Request Body:**
```json
{
  "confirmResize": {}
}
```

**Response:** 204 No Content

#### Server Security Groups

| Method | Path | Description |
|--------|------|-------------|
| POST | `/servers/{server_id}/action` (addSecurityGroup) | Add security group |
| POST | `/servers/{server_id}/action` (removeSecurityGroup) | Remove security group |

#### Server Metadata

| Method | Path | Description |
|--------|------|-------------|
| GET | `/servers/{server_id}/metadata` | Get all metadata |
| GET | `/servers/{server_id}/metadata/{key}` | Get single metadata item |
| PUT | `/servers/{server_id}/metadata` | Update metadata (merge) |
| POST | `/servers/{server_id}/metadata` | Create/update metadata items |
| DELETE | `/servers/{server_id}/metadata/{key}` | Delete metadata item |

#### Server Actions API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/servers/{server_id}/os-instance-actions` | List actions on instance |
| GET | `/servers/{server_id}/os-instance-actions/{id}` | Show specific action |
| GET | `/servers/{server_id}/os-instance-actions/{id}/events` | List action events |

### Console Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/servers/{server_id}/os-get-vnc-console` | Create noVNC console ticket |
| POST | `/servers/{server_id}/os-get-spice-console` | Create Spice console ticket |
| POST | `/servers/{server_id}/os-get-serial-console` | Create serial console ticket |

### Microversion-Aware Response Format

Response format varies by microversion. For example, the `OS-EXT-SRV-ATTR:instance_name` extension field was added in microversion 2.42. Each microversion (390+ changes) may add fields, deprecate fields, or change response structure. The X-OpenStack-Nova-API-Version header controls the response format (DEC-003).

## Business Logic

### Server Creation (ComputeManager.create()) (DEC-011)

The server creation flow follows a strict pipeline:

1. **API validation:** Verify request schema against microversion, check quotas
2. **Policy check:** oslo.policy evaluates the `compute:create` rule (DEC-007)
3. **Instance creation:** Database record with status=BUILDING is created
4. **Scheduler notification:** Build request sent to scheduler via RabbitMQ
5. **Host selection:** Scheduler applies filters and weights (DEC-008)
6. **Cell routing:** Conductor routes to appropriate cell (DEC-005)
7. **Compute dispatch:** Conductor sends build request to nova-compute
8. **Resource reservation:** nova-compute reserves allocations in OpenStack Placement
9. **Image preparation:** Download from OpenStack Glance if not cached
10. **Network setup:** Create port via OpenStack Neutron, assign IP
11. **VM spawn:** Launch VM via Libvirt driver (DEC-004)
12. **State update:** Instance state transitions BUILDING → ACTIVE

### Live Migration (DEC-011)

The live migration flow uses the cursive distributed state machine and TooZ distributed locking:

1. **Pre-check:** Validate migration feasibility (CPU compatibility, resource availability, network reachability)
2. **Destination reservation:** Allocate resources on destination compute node in Placement
3. **Pre-copy phase:** Transfer memory pages from source to destination (iterative, reducing dirty pages)
4. **Downtime phase:** Instance paused, remaining memory pages transferred, block devices attached
5. **Switchover:** Instance resumed on destination, source resources released
6. **Cleanup:** Update Instance.host, Instance.compute_host, release source allocations

The cursive state machine tracks migration state (check_cell0 → check_source → pre_live_migration → live_migration → post_live_migration_at_source → finish_migration → verify_resize → confirm_resize → completed) and ensures transitions follow valid paths (DEC-011).

### Resize Flow (DEC-011)

1. **Validation:** Verify target flavor exists, user has resize permission
2. **Power down:** Instance is powered off (unlike live migration which keeps it running)
3. **Resource allocation:** Allocate resources on destination host
4. **Disk migration:** Move/resize disk on destination compute node
5. **Boot on destination:** Instance boots with new flavor specs (vCPUs, memory, disk)
6. **Pending confirmation:** Instance enters VERIFY_RESIZE state
7. **Confirmation:** User must confirm (→ completes resize) or revert (→ moves back)

### Scheduler Filter/Weight Pipeline (DEC-008)

The scheduler operates in two phases:

**Filter Phase (get_filters):**
- ComputeFilter — Instance architecture matches host
- AvailableRamFilter — Host has enough free memory
- AvailabilityZoneFilter — Host is in requested availability zone
- AgentAvailableFilter — Compute service is enabled
- CoreFilter — Host has enough free vCPUs
- DiskFilter — Host has enough free disk
- FilterBuilderFilter — Dynamically adds filters based on request properties
- HostFilter — Default pass-through
- ImagePropertiesFilter — Image properties match host traits
- RamFilter — (alias for AvailableRamFilter)
- SameHostFilter — Anti-affinity: must be on same host
- DifferentHostFilter — Anti-affinity: must be on different host
- AggregateInstanceExtraSpecsFilter — Aggregate extra-spec matching
- AggregateHostInfoFilter — Aggregate host info matching
- AggregateHostnameFilter — Aggregate hostname filtering
- ComputeFilter — Compute service capabilities
- ComputeCapabilitiesFilter — Compute capabilities matching
- PciFilter — PCI passthrough requirements
- RamFilter — Available RAM
- RetryFilter — Excludes hosts from previous attempt
- ServerGroupAffinityFilter — Server group affinity
- ServerGroupAntiAffinityFilter — Server group anti-affinity
- ServerGroupProximityFilter — Server group proximity
- Image RAM and disk filters
- AggregateMultiTenancyIsolationFilter — Multi-tenancy isolation

**Weight Phase (get_weights):**
- RamWeight — Prefer hosts with more free RAM
- ComputeWeight — Weight based on compute host metadata
- RAMReservationWeight — Prefer hosts with reserved RAM
- RAMReservatioWeight — (secondary RAM weight)
- Aggregate instance counts — Prefer less loaded aggregates

## Error Handling

### HTTP Error Responses

| Status Code | Error Type | Trigger Condition |
|-------------|-----------|-------------------|
| 400 | BadRequest | Invalid request body, invalid microversion, malformed parameters |
| 401 | Unauthorized | Invalid or expired Keystone token |
| 403 | Forbidden | Policy rule denies the action (oslo.policy rejection) |
| 404 | NotFound | Instance, flavor, image, or aggregate not found |
| 409 | Conflict | Instance locked, operation already in progress |
| 413 | OverLimit | Quota exceeded |
| 500 | ServerError | Internal Nova error (conductor unreachable, database error) |
| 503 | ServiceUnavailable | nova-compute or nova-scheduler unavailable |

### Error Cases

#### Build Failures
- **NoValidHost:** Scheduler returns no candidates (quota exceeded, insufficient resources, aggregate filters reject all hosts) → 400 with NoValidHost error body
- **FlavorNotFound:** Requested flavor does not exist → 404
- **ImageNotFound:** Requested image does not exist or is not accessible → 404
- **QuotaExceeded:** Project quota for vCPUs, memory, or instances exceeded → 413 RequestLimitExceeded
- **NetworkNotFound:** Requested network does not exist → 404
- **PortCreationFailed:** OpenStack Neutron cannot create the network port → 400
- **ConductorUnreachable:** nova-conductor not responding on RabbitMQ → 503

#### Migration Failures
- **InsufficientResources:** Destination lacks required resources → 400
- **IncompatibleCPU:** Source and destination have CPU capability mismatch → 400
- **SourceComputeDown:** Source compute node goes down during migration → 500, instance lost
- **NetworkTimeout:** Live migration network transfer times out → 500
- **ConductorUnreachable:** Conductor cannot route migration request → 503

#### Resize Failures
- **NoHostResources:** No host has resources for target flavor → 400
- **Timeout:** User does not confirm resize within configured timeout → automatic revert
- **DiskResizeFailed:** Disk resize operation fails on destination → automatic revert

### Error Response Format

```json
{
  "computeFault": {
    "code": 500,
    "message": "No valid host found for create",
    "details": "NoValidHost: No host matched scheduler filters"
  }
}
```

### Retry Logic (DEC-002)

- **Database operations:** oslo.db provides automatic retry on transient failures (connection drops, lock timeouts, deadlock detection)
- **RPC calls:** oslo.messaging with RabbitMQ provides message persistence and delivery guarantees (DEC-010)
- **Conductor RPC:** Retry on conductor unavailability with exponential backoff
- **Placement API:** Retry on resource allocation failures with backoff

## Testing Strategy

### Test Framework

OpenStack Nova uses stestr (OpenStack's test runner) for test execution, with Tox for environment management. The test suite is organized as follows:

**Test Categories:**
- **Unit tests:** Test individual functions and classes with mocked dependencies
- **Functional tests:** Test API endpoints with an in-memory database and mocked external services
- **Tempest integration tests:** End-to-end tests running against a full OpenStack deployment

### Test Infrastructure

- **Devstack:** Single-node OpenStack deployment for functional testing
- **Gate:** Zuul-based continuous integration that runs full integration tests
- **Tempest:** OpenStack integration test suite for cross-service validation

### Test Data Requirements

- **Instance factories:** Create test instances with all attribute combinations
- **Flavor fixtures:** Pre-defined flavors (m1.tiny, m1.small, m1.medium, m1.large, m1.xlarge)
- **Compute node fixtures:** Pre-configured compute hosts with known resource allocations
- **Cell fixtures:** Multi-cell test environments with separate databases

### Key Test Patterns

- **Fake driver:** In-memory compute driver for testing without hypervisor dependencies
- **Database isolation:** Each test runs in a separate database transaction with cleanup
- **Service mock:** Mock nova-conductor, nova-scheduler, and external service interactions
- **Eventlet-aware tests:** Test infrastructure enforces greenlet leak detection

### Testing Concurrency (DEC-006)

- Tests must not leak greenlets (eventlet green thread reference counting enforced)
- Concurrency tests verify that eventlet and native threading fallback produce consistent results
- Race condition tests verify TooZ lock behavior during concurrent instance operations
