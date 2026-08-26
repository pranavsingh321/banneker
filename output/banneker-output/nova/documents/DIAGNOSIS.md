# Engineering Diagnosis

**Generated:** 2026-08-26T00:00:00Z
**Survey Version:** 2.0
**Analysis Baseline:** HIGH

## Survey Overview

**Completion Status:** 90% complete
**Phases Captured:** Phase 1 (Project), Phase 2 (Actors), Phase 3 (Walkthroughs), Phase 4 (Backend), Phase 5 (Rubric)
**Phases Missing:** None
**Total Gaps Identified:** 6 (from rubric_coverage.gaps)
**Existing Decisions:** 12 (DEC-001 through DEC-012)

No mid-survey handoff detected. Processing complete survey.

## What Is Known

### Project Context
- **Name:** OpenStack Nova
- **One-liner:** OpenStack's distributed compute service that manages the lifecycle of instances (virtual machines and bare metal) in a cloud infrastructure, including creation, scheduling, live migration, resizing, and deletion across multi-cell deployments.
- **Problem Statement:** Cloud operators need a scalable, multi-tenant compute orchestration layer that abstracts heterogeneous virtualization technologies (KVM/QEMU, VMware, IBM Z, bare metal via Ironic) into a unified API, while supporting horizontal scaling through cells v2, integrating with other OpenStack services (Glance, Neutron, Cinder, Keystone), and providing fine-grained RBAC with microversioned REST APIs.
- **Project Type:** backend-service (large scale)
- **Has Backend:** Yes
- **Has Frontend:** No

### Actors (8 total)

**Human Actors:**

1. **Cloud Administrator** — Manages Nova infrastructure including cells, aggregates, host aggregates, security groups, quotas, and service management. Capabilities include host aggregate management, cell mapping, service enable/disable, quota configuration, nova-manage/nova-status CLI usage, and policy rule configuration.

2. **Cloud User (Tenant)** — End user who provisions and manages compute instances within their project/tenant. Capabilities include server CRUD, boot from images/snapshots, resize, reboot/pause/resume/suspend/stop, volume attach/detach, console access (noVNC/Spice/serial), user-data, and microversioned API usage.

**System Actors:**

3. **OpenStack Keystone** — Identity and authentication service. Handles token validation, tenant/project context, oslo.policy RBAC enforcement.

4. **OpenStack Glance** — Image service. Serves VM disk images, provides image metadata (architecture, min disk, min RAM), exposes image properties used by scheduler filters, supports image caching at compute nodes.

5. **OpenStack Neutron** — Networking service. Creates/manages network interfaces (ports), assigns IPs, manages security groups, provides network topology (subnets, routers), supports distributed virtual routing (OVS).

6. **OpenStack Cinder** — Block storage service. Attaches/detaches iSCSI/FC volumes, provides volume metadata (size, type, availability zone), supports boot-from-volume, exposes volume drivers.

7. **OpenStack Placement** — Resource provider tracking. Tracks resource allocation per compute host, provides utilization data for scheduler filtering, accepts resource provider updates, supports custom resource classes and traits.

8. **VM Instance** — The virtual machine or bare-metal instance managed by Nova. Exposes metadata service, runs guest OS workloads, reports heartbeat and live state, supports live migration, exposes console access.

### Walkthroughs (5 total — 4 primary, 1 secondary)

**Primary Walkthroughs:**

1. **Create and boot a server instance** (12 steps)
   - Actor: Cloud User → Keystone → Nova API → ComputeManager → Scheduler → Conductor → nova-compute → Placement → Glance → Neutron → virt driver
   - Data changes: Instance row creation, InstanceAction record, Placement resource allocations, Neutron port creation, shadow instance row
   - Error cases: NoValidHost, FlavorNotFound, ImageNotFound, QuotaExceeded, Insufficient resources, NetworkNotFound

2. **Live migrate a running instance** (9 steps)
   - Actor: Cloud User → Nova API → ComputeManager → Scheduler → Conductor → destination nova-compute
   - Data changes: Migration row creation, compute_host/host field updates, Placement allocation transfers, InstanceAction records
   - Error cases: Insufficient resources, network bandwidth, CPU incompatibility, source compute failure, conductor unreachable

3. **Resize an instance (change flavor)** (8 steps)
   - Actor: Cloud User → Nova API → ComputeManager → Scheduler → Conductor → destination nova-compute
   - Data changes: ResizeRequest record, flavor update, resource allocation adjustments, migration record
   - Error cases: No host with resources, confirmation timeout, disk resize failure, conductor unavailable

4. **List and filter servers with microversion API** (6 steps)
   - Actor: Cloud User → Nova API (GET /servers with query params)
   - Data changes: None (read-only)
   - Error cases: Invalid microversion, malformed parameters, unauthorized

**Secondary Walkthroughs:**

5. **Access instance console via noVNC proxy** (5 steps)
   - Actor: Cloud User → Keystone → Nova API → VncConsoleManager → nova-novncproxy → compute VNC server
   - Data changes: Console ticket creation, console entry logging
   - Error cases: Instance not running, VNC server not listening, ticket expired

### Backend Architecture

**Data Stores:**
- PostgreSQL (primary production database)
- MySQL/MariaDB (alternative production database)
- SQLite (test fallback)
- Alembic (database migration framework)
- oslo.db (database session management with retry logic)

**Integrations:**
- OpenStack Keystone — authentication and authorization
- OpenStack Glance — VM image service
- OpenStack Neutron — virtual networking and security groups
- OpenStack Cinder — block storage volume management
- OpenStack Placement — resource provider tracking and allocation
- RabbitMQ via oslo.messaging — inter-service RPC messaging
- Barbican via castellan — cryptographic key management
- Dogpile.cache via oslo.cache — caching layer

**Infrastructure:**
- Distributed multi-process architecture: nova-compute, nova-conductor, nova-scheduler as separate daemons
- Multi-cell deployment support (cells v2) with cell0 (metadata) and cell1+ (compute hosts)
- Eventlet green threads with native threading fallback
- Pluggable virtualization drivers via Stevedore entry points (libvirt, VMware, ZVM, Ironic)
- Pluggable scheduler filters and weights via Stevedore entry points
- WSGI pipeline via PasteDeploy (api-paste.ini)
- Ansible roles and playbooks for deployment
- Zuul CI/CD pipeline for integration testing
- DevStack for single-node deployment and testing
- Docker for containerized CI environments

### Rubric Coverage

**Covered (12 items):** project_overview, actors_identified, user_journeys, tech_stack, data_layer, api_surface, integration_boundaries, deployment_model, concurrency_model, security_model, configuration_management, plugin_extensibility

**Identified Gaps (6 items):**
1. exact_oslo_library_versions — runtime versions use >= lower_bound semantics from requirements.txt
2. metadata_service_detail — nova/api/metadata/ sub-service not examined in depth
3. optional_driver_complexity — VMware, ZVM, and Ironic drivers have additional complexity not fully explored
4. migration_file_count — full Alembic migration history may span more files than visible in scan depth
5. cell_rpc_protocol_details — exact messaging protocol between cells and conductor not fully traced
6. performance_characteristics — no benchmark data or performance profiles documented in source

## What Is Missing

### Critical Gaps (affect architecture recommendations)

1. **exact_oslo_library_versions** — Survey captures that oslo.* libraries are used but exact version constraints are not recorded. This affects the recommendation for backend framework decisions since version-specific API availability matters. **Impact:** MEDIUM — The library ecosystem is stable but version pinning affects which features are available.

2. **metadata_service_detail** — The nova/api/metadata/ sub-service that provides instance metadata is not examined in depth. **Impact:** LOW — This is a specialized sub-service that follows the same architectural patterns as the main API layer.

3. **optional_driver_complexity** — VMware, ZVM, and Ironic drivers have additional complexity not fully explored. **Impact:** LOW — These are optional pluggable drivers; the core architecture is driven by libvirt/KVM.

4. **migration_file_count** — Full Alembic migration history may span more files than visible in scan depth. **Impact:** LOW — Does not affect architectural decisions, only documentation completeness.

5. **cell_rpc_protocol_details** — Exact messaging protocol between cells and conductor not fully traced. **Impact:** MEDIUM — Cell communication is critical for the cells v2 architecture but the survey does not capture the specific RPC calls, message formats, or failure modes.

6. **performance_characteristics** — No benchmark data or performance profiles documented in source. **Impact:** MEDIUM — Scalability and performance requirements are not quantified, making capacity-related recommendations less precise.

### Information Gaps

- No explicit performance SLA or target latency captured
- No explicit availability/reliability targets (RPO/RTO) captured
- No security penetration testing or compliance requirements captured
- No explicit data retention policies for instance actions or audit logs
- No budget or resource constraints captured (though large-scale deployment implies significant resources)

## Information Quality Assessment

| Survey Section | Completeness | Confidence Impact |
|----------------|--------------|-------------------|
| Project Context | 100% | None — all required fields present |
| Actors | 100% | None — 8 actors with detailed capabilities |
| Walkthroughs | 95% | Minimal — 5 walkthroughs with 40+ total steps, data_changes, and error_cases |
| Backend Data Stores | 90% | Minor — primary and alternative databases identified, but version constraints missing |
| Backend Integrations | 95% | Minimal — 8 integrations documented with capabilities |
| Backend Infrastructure | 85% | Minor — multi-process architecture and cells v2 documented, but cell RPC details missing |
| Rubric Coverage | 80% | Minor — 12/18 items covered, 6 gaps are specific and addressable |

**Overall:** 90% complete

## Critical Unknowns

These gaps affect recommendation confidence in specific areas:

1. **Cell RPC Protocol Details** — Affects the recommendation for inter-cell communication architecture and fault-tolerance patterns. Without knowing the exact messaging protocol, we cannot precisely evaluate message durability, ordering guarantees, or failure recovery mechanisms for cross-cell operations.

2. **Performance Characteristics** — Affects scalability recommendations including compute-to-conductor ratios, cell sizing, caching strategies, and database tuning. Benchmark data would inform whether current architecture is sufficient or if additional optimization layers are needed.

3. **Exact oslo Library Versions** — Affects backend framework recommendations. Some oslo.* libraries have version-specific features (e.g., oslo.middleware, oslo.db) that change the available patterns for security, database access, and caching.

## Minimum Viable Analysis

**Assessment: PASS**

Survey provides comprehensive information for engineering recommendations. All required phases (1-5) are complete with substantial depth. The 8 identified gaps are specific and manageable, and most affect only a single recommendation area. Confidence will vary by architecture area — well-supported areas receive HIGH confidence, while areas touching rubric gaps receive MEDIUM confidence.

## Next Steps

1. Generate RECOMMENDATION.md with options analysis
2. Mark recommendations touching rubric gap areas with MEDIUM confidence
3. Generate ENGINEERING-PROPOSAL.md with ADR-format decisions
4. All proposals will require approval before merge (Phase 13)
