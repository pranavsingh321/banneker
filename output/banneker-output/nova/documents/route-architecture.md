# OpenStack Nova - Route Architecture

**Project Type:** backend-service

This document provides a detailed route inventory, navigation flows by actor, API surface summary, authentication boundaries, data flow annotations, and traceability mapping for all routes extracted from survey walkthroughs.

---

## Route Inventory

| Path | Method | Actor | Auth | Feature Area | Data Flow |
|------|--------|-------|------|--------------|-----------|
| `/servers` | GET | Cloud User (Tenant) | Protected (authenticated) | Server Management | Read-only |
| `/servers` | POST | Cloud User (Tenant) | Protected (authenticated) | Server Lifecycle | Create: Instance row, InstanceAction, Placement allocations, Neutron port, Shadow instance |
| `/servers/{id}/action` | POST | Cloud User (Tenant) | Protected (authenticated) | Server Actions | Create/Update: Migration, ResizeRequest, Instance field updates, Placement allocations, InstanceAction |
| `/servers/{id}/actions/os-get-vnc-console` | GET | Cloud User (Tenant) | Protected (authenticated) | Console Access | Create: Console ticket, Console log entry |

**Total Routes:** 4 (distinct paths)  
**Total Route Entries (with method):** 5  
**API Endpoints:** 4 (all are REST API routes)

---

## Navigation Flows by Actor

Each actor's typical navigation sequence extracted from walkthrough steps.

### Cloud User (Tenant)

**Role:** End user who provisions and manages compute instances within their project/tenant.

**Capabilities:** Create, list, show, update, and delete servers; boot from images/snapshots; resize; reboot, pause, resume, suspend, stop; attach/detach volumes; console access; server groups; microversioned API features.

---

#### Flow 1: Create and Boot a Server Instance

Derived from: *Create and boot a server instance* (12 steps)

| # | Action | Route | Method | Data Flow |
|---|--------|-------|--------|-----------|
| 1 | User authenticates with Keystone and submits server creation request | `/servers` | POST | Create: Instance row (BUILDING), InstanceAction, Placement allocations, Neutron port, Shadow instance |
| 2 | API controller validates request against current microversion schema | (internal) | — | Validation |
| 3 | Keystone middleware authenticates token and applies policy rules | (internal) | — | AuthN/AuthZ |
| 4 | ComputeManager.create() notifies Scheduler via RPC | (internal RPC) | — | RPC call |
| 5 | Scheduler selects host using filters (affinity, NUMA, PCI, image properties, aggregate) | (internal) | — | Filter/weight |
| 6 | Scheduler routes build request to conductor (cell-aware) | (internal RPC) | — | Cell routing |
| 7 | Conductor dispatches build to target nova-compute node via RPC | (internal RPC) | — | RPC dispatch |
| 8 | Compute node reserves resource allocations in Placement | (internal) | — | Placement update |
| 9 | Compute node downloads image from Glance (if not cached) | (internal) | — | Image fetch |
| 10 | Compute node allocates network resources via Neutron | (internal) | — | Port creation |
| 11 | Compute node spawns VM via virt driver (libvirt/KVM) | (internal) | — | VM spawn |
| 12 | Compute node updates Instance state to ACTIVE | (internal DB) | — | State transition |
| 13 | User receives 202 Accepted with server creation response | `/servers` | POST | Response |

**State Transitions:** `BUILDING` → `ACTIVE`

---

#### Flow 2: Live Migrate a Running Instance

Derived from: *Live migrate a running instance* (9 steps)

| # | Action | Route | Method | Data Flow |
|---|--------|-------|--------|-----------|
| 1 | User submits POST with action=migrate | `/servers/{id}/action` | POST | Create: Migration row (check_cell0), Instance compute_host/host update, Placement allocation transfer, InstanceAction logs |
| 2 | API controller validates microversion for migration | (internal) | — | Validation |
| 3 | ComputeManager.migrate_server() initiates flow | (internal) | — | Migration orchestration |
| 4 | Scheduler selects destination host (same filter/weight pipeline) | (internal) | — | Filter/weight |
| 5 | Conductor coordinates migration to destination compute | (internal RPC) | — | RPC coordination |
| 6 | Pre-copy: compute nodes transfer memory pages | (internal) | — | Memory transfer |
| 7 | TooZ lock groups prevent concurrent operations | (internal) | — | Locking |
| 8 | Final pause and switch: instance paused, state transferred, resumed | (internal) | — | State switch |
| 9 | Instance actions updated, Placement allocations swapped | (internal) | — | Completion update |
| 10 | User receives 202 Accepted with migration ID | `/servers/{id}/action` | POST | Response |

**State Transitions:** Running → `MIGRATING` → `VERIFY_RESUME` → `RESUMED`

---

#### Flow 3: Resize an Instance (Change Flavor)

Derived from: *Resize an instance (change flavor)* (8 steps)

| # | Action | Route | Method | Data Flow |
|---|--------|-------|--------|-----------|
| 1 | User submits POST with action=resize, specifying new flavor_id | `/servers/{id}/action` | POST | Create: ResizeRequest, Instance flavor update, Resource allocation adjustment, Migration record |
| 2 | API controller verifies resize permissions and target flavor exists | (internal) | — | Validation |
| 3 | Nova creates resize request and allocates resources on destination | (internal) | — | Resource reservation |
| 4 | Scheduler selects destination host | (internal) | — | Host selection |
| 5 | Instance powered off and migrated to destination (shutdown migration) | (internal) | — | Migration |
| 6 | Disk resized on destination compute node | (internal) | — | Disk resize |
| 7 | Instance boots on destination with new flavor specs | (internal) | — | Boot |
| 8 | User confirms: POST with action=confirmResize | `/servers/{id}/action` | POST | Release source resources, mark migration complete |
| 9 | User reverts: POST with action=revertResize | `/servers/{id}/action` | POST | Move instance/disk back to original host |

**State Transitions:** Running → `VERIFY_RESIZE` → `ACTIVE` (confirm) or original host (revert)

---

#### Flow 4: List and Filter Servers

Derived from: *List and filter servers with microversion API* (6 steps)

| # | Action | Route | Method | Data Flow |
|---|--------|-------|--------|-----------|
| 1 | User sends GET /servers with query parameters | `/servers` | GET | Read-only — paginated server list |
| 2 | API controller applies X-OpenStack-Nova-API-Version header | (internal) | — | Microversion routing |
| 3 | ServersController.index() queries Instance objects | (internal DB) | — | Database query |
| 4 | Filters applied at DB level via SQLAlchemy | (internal) | — | SQL filtering |
| 5 | View module serializes response (microversion-aware format) | (internal) | — | Serialization |
| 6 | User receives filtered list with metadata links | `/servers` | GET | Response: 200 OK |

---

#### Flow 5: Access Instance Console via noVNC Proxy

Derived from: *Access instance console via noVNC proxy* (5 steps)

| # | Action | Route | Method | Data Flow |
|---|--------|-------|--------|-----------|
| 1 | User authenticates with Keystone, requests console access | `/servers/{id}/actions/os-get-vnc-console` | GET | Create: Console ticket (with expiration), Console log entry |
| 2 | API controller validates access, creates console ticket | (internal) | — | Ticket generation |
| 3 | nova-novncproxy receives VNC connection request with ticket | (internal) | — | Proxy routing |
| 4 | Proxy authenticates ticket, forwards WebSocket to compute node | (internal) | — | WebSocket tunnel |
| 5 | User sees VM console via noVNC WebSocket | (proxy) | — | Browser display |

---

## API Surface Summary

All identified routes are REST API endpoints exposed by the Nova API service (nova-api).

### Servers Resource

| Method | Path | Description | Auth | Data |
|--------|------|-------------|------|------|
| GET | `/servers` | List and filter servers by status, image, flavor, host, project | Protected | Read-only |
| POST | `/servers` | Create and boot a new server instance | Protected | Create: instance, action, placement, neutron port, shadow row |
| POST | `/servers/{id}/action` | Perform server action (migrate, resize, confirmResize, revertResize) | Protected | Create/Update: migration, resize request, instance fields, placement, instance actions |

### Console Resource

| Method | Path | Description | Auth | Data |
|--------|------|-------------|------|------|
| GET | `/servers/{id}/actions/os-get-vnc-console` | Request VNC/console access ticket for an instance | Protected | Create: console ticket, console log entry |

### Summary by HTTP Method

| Method | Count | Percentage |
|--------|-------|------------|
| GET | 2 | 40% |
| POST | 3 | 60% |

### Summary by Response Status

| Status | Occurrences | Used By |
|--------|-------------|---------|
| 200 OK | 2 | List servers, Console access |
| 202 Accepted | 3 | Create server, Migrate server, Resize server |
| 400 BadVersion | 0 (error case) | Invalid microversion |
| 400 BadRequest | 0 (error case) | Malformed query params |
| 401 Unauthorized | 0 (error case) | Invalid Keystone token |
| 403 RequestLimitExceeded | 0 (error case) | Quota exceeded |
| 404 FlavorNotFound / ImageNotFound | 0 (error case) | Missing resources |

---

## Authentication Boundaries

### Protected Routes (4)

All routes require Keystone authentication. The Keystone middleware layer sits in the WSGI pipeline (configured via `api-paste.ini`) and validates tokens before any route handler is reached.

| Path | Method | Auth Requirement |
|------|--------|-----------------|
| `/servers` | GET | Protected (authenticated) — Keystone token validation, project context |
| `/servers` | POST | Protected (authenticated) — Keystone token validation, RBAC policy check |
| `/servers/{id}/action` | POST | Protected (authenticated) — Keystone token validation, RBAC per action |
| `/servers/{id}/actions/os-get-vnc-console` | GET | Protected (authenticated) — Keystone token validation, RBAC policy check |

### Public Routes (0)

No public routes were identified in the surveyed walkthroughs. This is consistent with Nova's design as a backend compute orchestration service where all API access is tenant-scoped and authenticated.

### Boundary Visualization

```
┌──────────────────────────────────────────────────────────────┐
│  PUBLIC ZONE                                                 │
│  0 routes (no auth required — Nova is a backend service)     │
├──────────────────────────────────────────────────────────────┤
│  AUTHENTICATED ZONE                                          │
│  4 routes (Keystone token required)                          │
│                                                              │
│  ├─ GET    /servers                          (list/filter)  │
│  ├─ POST   /servers                          (create)       │
│  ├─ POST   /servers/{id}/action            (migrate, resize)│
│  └─ GET    /servers/{id}/actions/os-get-vnc-console  (console)│
├──────────────────────────────────────────────────────────────┤
│  ADMIN ZONE                                                  │
│  0 routes in surveyed walkthroughs                           │
│  (Admin routes such as /os-aggregates, /os-services,         │
│   /os-quota-sets exist in Nova but were not captured in the  │
│   surveyed walkthroughs)                                     │
└──────────────────────────────────────────────────────────────┘
```

---

## Data Flow Annotations

Routes that modify application state, grouped by resource.

### Instance (Server) Lifecycle

#### `POST /servers` — Create Server

- **Actor:** Cloud User (Tenant)
- **Data Changes:**
  - Instance row created with status=BUILDING
  - InstanceAction record created for the build operation
  - Resource provider updates in Placement (allocations table)
  - Neutron port created with MAC address assignment
  - Shadow instance row created for historical tracking
- **Walkthrough:** Create and boot a server instance — Step 1
- **External Dependencies:** Placement (resource allocation), Neutron (network), Glance (image)

#### `POST /servers/{id}/action` — Migrate Server

- **Actor:** Cloud User (Tenant)
- **Data Changes:**
  - Migration row created with initial status=check_cell0
  - Instance compute_host and host fields updated on destination
  - Placement allocations transferred between compute hosts
  - InstanceAction records logged for each migration step
- **Walkthrough:** Live migrate a running instance — Steps 1, 7–9
- **External Dependencies:** Placement (resource swap)

#### `POST /servers/{id}/action` — Resize Server

- **Actor:** Cloud User (Tenant)
- **Data Changes:**
  - ResizeRequest record created in database
  - Instance flavor updated to new flavor
  - Resource allocations adjusted on both source and destination
  - Migration record created with status=completed or reverted
- **Walkthrough:** Resize an instance (change flavor) — Steps 1–8
- **External Dependencies:** Placement (resource adjustment)

### Console Access

#### `GET /servers/{id}/actions/os-get-vnc-console` — Get Console Ticket

- **Actor:** Cloud User (Tenant)
- **Data Changes:**
  - Console ticket created with expiration timestamp
  - Console entry logged in the database
- **Walkthrough:** Access instance console via noVNC proxy — Step 1
- **External Dependencies:** nova-novncproxy (console proxy), VNC server on compute node

### Read-Only Routes

#### `GET /servers` — List Servers

- **Actor:** Cloud User (Tenant)
- **Data Changes:** None (pure read)
- **Walkthrough:** List and filter servers with microversion API — Steps 1–6
- **Query:** status, image_id, flavor_id, host, project_id
- **Microversion:** X-OpenStack-Nova-API-Version header

---

## Integration Boundaries

Routes that interact with external OpenStack services:

| Nova Route | External Service | Interaction Type | Description |
|------------|-----------------|-----------------|-------------|
| `POST /servers` | OpenStack Placement | RPC/API call | Reserve vCPUs, memory, disk allocations |
| `POST /servers` | OpenStack Neutron | RPC/API call | Create network port, assign IP |
| `POST /servers` | OpenStack Glance | HTTP call | Download image (if not cached) |
| `POST /servers/{id}/action` (migrate) | OpenStack Placement | RPC/API call | Swap resource allocations between hosts |
| `POST /servers/{id}/action` (resize) | OpenStack Placement | RPC/API call | Adjust resource allocations |
| All routes | OpenStack Keystone | Middleware | Token validation, RBAC policy enforcement |

---

## Microversion Strategy

All routes support microversioning via the `X-OpenStack-Nova-API-Version` header.

- **Request validation:** API controller validates the header against the current microversion schema
- **Response variation:** View module serializes responses in microversion-aware format
- **Feature gating:** Some actions (e.g., migration features) require specific microversions to be set
- **Invalid version:** Returns 400 BadVersion

---

## RPC and Internal Communication

While the REST API routes above are the external surface, Nova's internal architecture uses extensive RPC messaging that is not exposed as HTTP routes:

| Internal Component | RPC Target | Purpose |
|--------------------|-----------|---------|
| nova-api → nova-scheduler | BuildRequest | Request host selection for new server |
| nova-scheduler → nova-conductor | BuildRequest (cell-aware) | Route to correct cell's conductor |
| nova-conductor → nova-compute | BuildInstance | Dispatch instance build to compute node |
| nova-conductor → nova-compute | MigrateServer | Dispatch migration request |
| nova-compute → nova-compute | Live migration data transfer | Memory page pre-copy |

These RPC paths use `oslo.messaging` over RabbitMQ and are not part of the REST API surface.

---

## Traceability

All routes in this document are extracted from survey walkthrough steps. Each route can be traced back to:

- **Walkthrough:** The feature scenario name
- **Step(s):** The specific step numbers in that walkthrough where the route is invoked
- **Action:** The user or system action that revealed the route

### Complete Traceability Map

| Route | Walkthrough | Step(s) | Source Text |
|-------|------------|---------|-------------|
| `POST /servers` | Create and boot a server instance | 1 | "User authenticates with Keystone and submits POST /servers with image_id, flavor_id, network_info, and optional user_data" |
| `GET /servers` | List and filter servers with microversion API | 1 | "User sends GET /servers with query parameters (status, image_id, flavor_id, host, project_id)" |
| `POST /servers/{id}/action` (migrate) | Live migrate a running instance | 1 | "User submits POST /servers/{id}/action with action=migrate on the target server" |
| `POST /servers/{id}/action` (resize) | Resize an instance (change flavor) | 1 | "User submits POST /servers/{id}/action with action=resize, specifying a new flavor_id" |
| `POST /servers/{id}/action` (confirmResize) | Resize an instance (change flavor) | 7 | "User must confirm (POST /servers/{id}/action with action=confirmResize)" |
| `POST /servers/{id}/action` (revertResize) | Resize an instance (change flavor) | 7 | "or revert (action=revertResize)" |
| `GET /servers/{id}/actions/os-get-vnc-console` | Access instance console via noVNC proxy | 1 | "User authenticates with Keystone and requests GET /servers/{id}/actions/os-get-vnc-console" |

### Survey Statistics

| Metric | Value |
|--------|-------|
| Walkthroughs analyzed | 5 |
| Total walkthrough steps | 40 |
| Routes extracted | 4 distinct paths (5 method+path combinations) |
| API endpoints | 4 |
| Actors with routes | 1 of 8 (Cloud User (Tenant)) |
| Public routes | 0 |
| Protected routes | 4 |
| Admin routes | 0 (not in surveyed walkthroughs) |

---

**Generated:** 2026-08-26T00:00:00Z

**Survey version:** 2.0
