# OpenStack Nova - Sitemap

**Project Type:** backend-service

This sitemap shows the hierarchical route structure extracted from project walkthroughs. Each route is annotated with HTTP method, actor access, and authentication requirements.

---

## Server Management

Routes for querying and listing compute instances within a project.

- **`GET /servers`**
  - Method: `GET`
  - Actor: Cloud User (Tenant)
  - Auth: Protected (authenticated)
  - Data: Read-only
  - Walkthrough: List and filter servers with microversion API — Step 1
  - Query params: `status`, `image_id`, `flavor_id`, `host`, `project_id`
  - Header: `X-OpenStack-Nova-API-Version` (microversion)
  - Response: 200 OK — paginated server list with metadata links

- **`POST /servers`**
  - Method: `POST`
  - Actor: Cloud User (Tenant)
  - Auth: Protected (authenticated)
  - Data: Instance row created with status=BUILDING, InstanceAction record created for the build operation, Resource provider updates in Placement (allocations table), Neutron port created with MAC address assignment, Shadow instance row created for historical tracking
  - Walkthrough: Create and boot a server instance — Step 1
  - Payload: `image_id`, `flavor_id`, `network_info`, optional `user_data`
  - Response: 202 Accepted — server object containing `id`, `status`, and `links`

---

## Server Actions

POST-based action endpoint for mutating server state (migrate, resize, confirmResize, revertResize, reboot, pause, resume, suspend, stop).

- **`POST /servers/{id}/action`**
  - Method: `POST`
  - Actor: Cloud User (Tenant)
  - Auth: Protected (authenticated)
  - Data: Migration row created with initial status=check_cell0, Instance compute_host and host fields updated on destination, Placement allocations transferred between compute hosts, InstanceAction records logged, ResizeRequest record created in database, Instance flavor updated to new flavor, Resource allocations adjusted on both source and destination, Migration record created with status=completed or reverted
  - Walkthroughs:
    - Live migrate a running instance — Steps 1, 7–9
    - Resize an instance (change flavor) — Steps 1–8
  - Body parameter: `action` — values include `migrate`, `resize`, `confirmResize`, `revertResize`
  - Response: 202 Accepted — migration ID or resize confirmation required

---

## Console Access

Routes for obtaining remote console access to instances.

- **`GET /servers/{id}/actions/os-get-vnc-console`**
  - Method: `GET`
  - Actor: Cloud User (Tenant)
  - Auth: Protected (authenticated)
  - Data: Console ticket created with expiration timestamp, Console entry logged in the database
  - Walkthrough: Access instance console via noVNC proxy — Step 1
  - Response: 200 OK — console URL and type (`novnc`, `spicehtml5`, or `serial`)
  - Proxy: `nova-novncproxy` tunnels WebSocket to compute node

---

## Actor Access Summary

### Cloud User (Tenant)

**Role:** End user who provisions and manages compute instances within their project/tenant.

**Accessible Routes:** 4

| Method | Path | Feature | Auth |
|--------|------|---------|------|
| GET | `/servers` | List/filter servers | Protected (authenticated) |
| POST | `/servers` | Create/boot server | Protected (authenticated) |
| POST | `/servers/{id}/action` | Server actions (migrate, resize, etc.) | Protected (authenticated) |
| GET | `/servers/{id}/actions/os-get-vnc-console` | VNC console access | Protected (authenticated) |

---

## Walkthrough Traceability Matrix

| Walkthrough | Feature Area | Routes Extracted |
|-------------|-------------|-----------------|
| Create and boot a server instance | Server Lifecycle | `POST /servers` |
| Live migrate a running instance | Server Actions | `POST /servers/{id}/action` (action=migrate) |
| Resize an instance (change flavor) | Server Actions | `POST /servers/{id}/action` (action=resize, confirmResize, revertResize) |
| List and filter servers with microversion API | Server Management | `GET /servers` |
| Access instance console via noVNC proxy | Console Access | `GET /servers/{id}/actions/os-get-vnc-console` |

---

**Generated:** 2026-08-26T00:00:00Z

**Source:** Survey walkthrough data (5 walkthroughs analyzed)

**Traceability:** Every route in this sitemap is traceable to a specific walkthrough step in the survey data.
