# OpenStack Nova — Context Bundle

Generated: 2026-08-26T00:00:00Z

This bundle contains project planning artifacts for LLM agent consumption. It includes structured survey data, architecture decisions, and priority planning documents.

---

## Table of Contents

1. Survey Data
2. Architecture Decisions
3. Technical Summary
4. Technology Stack
5. Infrastructure Architecture
6. Technical Draft
7. Portal Integration
8. Engineering Diagnosis
9. Engineering Recommendations
10. Engineering Proposals

---

## Survey Data

This is the raw survey data from the Banneker discovery interview. All project requirements and flows are derived from this.

```json
{
  "survey_metadata": {
    "version": "2.0",
    "created": "2026-08-26T00:00:00Z",
    "runtime": "opencode",
    "status": "complete"
  },
  "project": {
    "name": "OpenStack Nova",
    "one_liner": "OpenStack's distributed compute service that manages the lifecycle of instances (virtual machines and bare metal) in a cloud infrastructure, including creation, scheduling, live migration, resizing, and deletion across multi-cell deployments.",
    "problem": "Cloud operators need a scalable, multi-tenant compute orchestration layer that abstracts heterogeneous virtualization technologies (KVM/QEMU, VMware, IBM Z, bare metal via Ironic) into a unified API, while supporting horizontal scaling through cells v2, integrating with other OpenStack services (Glance for images, Neutron for networking, Cinder for block storage, Keystone for authentication), and providing fine-grained RBAC with microversioned REST APIs.",
    "has_backend": true,
    "has_frontend": false,
    "project_type": "backend-service",
    "scale": "large"
  },
  "actors": [
    {
      "name": "Cloud Administrator",
      "type": "human",
      "role": "Manages Nova infrastructure including cells, aggregates, host aggregates, security groups, quotas, and service management.",
      "capabilities": [
        "Create, update, and delete host aggregates",
        "Manage cell mappings and database synchronization",
        "Enable/disable nova-compute and nova-scheduler services",
        "Configure quotas and limits per project",
        "Run nova-manage and nova-status management CLI commands",
        "Configure policy rules and security group defaults",
        "Monitor service health via nova-status"
      ]
    },
    {
      "name": "Cloud User (Tenant)",
      "type": "human",
      "role": "End user who provisions and manages compute instances within their project/tenant.",
      "capabilities": [
        "Create, list, show, update, and delete servers (instances)",
        "Boot instances from images or snapshots",
        "Resize instances (change flavor)",
        "Reboot, pause, resume, suspend, and stop instances",
        "Attach and detach volumes",
        "List and show flavors, images, hypervisors, and aggregates",
        "Access console via noVNC, Spice, or serial proxy",
        "Launch instances via user-data and config-drive",
        "Manage server groups (anti-affinity, affinity policies)",
        "Use microversioned API features"
      ]
    },
    {
      "name": "OpenStack Keystone",
      "type": "system",
      "role": "Identity and authentication service that validates tokens, enforces RBAC policy, and provides the context for all Nova API requests.",
      "capabilities": [
        "Authenticate API requests via token validation",
        "Provide tenant/project context",
        "Enforce authorization policy rules via oslo.policy",
        "Support role-based access control"
      ]
    },
    {
      "name": "OpenStack Glance",
      "type": "system",
      "role": "Image service that Nova queries for VM disk images, metadata, and image properties used in filter-based host scheduling.",
      "capabilities": [
        "Serve VM disk images to compute nodes",
        "Provide image metadata (architecture, min disk, min RAM)",
        "Expose image properties used by scheduler filters",
        "Support image caching at compute nodes"
      ]
    },
    {
      "name": "OpenStack Neutron",
      "type": "system",
      "role": "Networking service that Nova integrates with for virtual network interface assignment, security groups, and port management.",
      "capabilities": [
        "Create and manage network interfaces (ports)",
        "Assign IP addresses to instances",
        "Manage security groups (firewall rules)",
        "Provide network topology (subnets, routers)",
        "Support distributed virtual routing (OVS)"
      ]
    },
    {
      "name": "OpenStack Cinder",
      "type": "system",
      "role": "Block storage service that Nova integrates with for attaching persistent block storage volumes to instances.",
      "capabilities": [
        "Attach and detach iSCSI/FC volumes to instances",
        "Provide volume metadata (size, type, availability zone)",
        "Support boot-from-volume instances",
        "Expose volume drivers for storage backends"
      ]
    },
    {
      "name": "OpenStack Placement",
      "type": "system",
      "role": "Resource provider tracking service that Nova queries and updates for resource allocation (vCPUs, memory, disk, custom resources) at each compute node.",
      "capabilities": [
        "Track resource allocation per compute host",
        "Provide resource utilization data for scheduler filtering",
        "Accept resource provider updates from Nova compute",
        "Support custom resource classes and traits"
      ]
    },
    {
      "name": "VM Instance",
      "type": "system",
      "role": "The virtual machine or bare-metal instance managed by Nova, which exposes a metadata service and is controlled via hypervisor-level operations.",
      "capabilities": [
        "Access instance metadata via local metadata service",
        "Run guest OS workloads",
        "Report heartbeat and live state",
        "Support live migration between hosts",
        "Expose console access (noVNC, Spice, serial)"
      ]
    }
  ],
  "walkthroughs": [
    {
      "name": "Create and boot a server instance",
      "type": "primary",
      "steps": [
        "User authenticates with Keystone and submits POST /servers with image_id, flavor_id, network_info, and optional user_data",
        "API controller validates the request against the current microversion schema",
        "Keystone middleware authenticates the token and applies policy rules",
        "ComputeManager.create() is called, which notifies the Scheduler via RPC",
        "Scheduler selects a host using filters (affinity, NUMA, PCI, image properties, aggregate filters) and weights",
        "Scheduler routes the build request to the appropriate conductor service (cell-aware)",
        "Conductor dispatches the build request to the target nova-compute node via RPC",
        "Compute node reserves resource allocations in Placement (vCPUs, memory, disk)",
        "Compute node downloads the image from Glance (if not cached)",
        "Compute node allocates network resources via Neutron (creates port, assigns IP)",
        "Compute node spawns the VM via the virt driver (libvirt/KVM by default)",
        "Compute node updates the Instance object state to ACTIVE",
        "User receives 202 Accepted with server creation response"
      ],
      "system_responses": [
        "202 Accepted with server object containing id, status, and links",
        "Instance transitions through BUILDING -> ACTIVE states",
        "Placement resource allocations committed on the compute host",
        "Neutron port created and associated with the instance network",
        "Glance image referenced and cached on compute node"
      ],
      "data_changes": [
        "Instance row created with status=BUILDING",
        "InstanceAction record created for the build operation",
        "Resource provider updates in Placement (allocations table)",
        "Neutron port created with MAC address assignment",
        "Shadow instance row created for historical tracking"
      ],
      "error_cases": [
        "No suitable host found: Scheduler returns no candidates, API returns 400 NoValidHost",
        "Flavor not found: API returns 404 FlavorNotFound",
        "Image not found: API returns 404 ImageNotFound",
        "Quota exceeded: API returns 403 RequestLimitExceeded",
        "Insufficient resources: Scheduler filter rejects all hosts due to placement constraints",
        "Neutron network unavailable: Build fails with NetworkNotFound or PortCreationFailed"
      ]
    },
    {
      "name": "Live migrate a running instance",
      "type": "primary",
      "steps": [
        "User submits POST /servers/{id}/action with action=migrate on the target server",
        "API controller validates the microversion for migration features",
        "ComputeManager.migrate_server() initiates the migration flow",
        "Scheduler selects a destination host using the same filter/weight pipeline as build",
        "Conductor coordinates the migration request to the destination compute node",
        "Pre-copy phase: compute nodes transfer memory pages of the running VM over the network",
        "cursive distributed state machine coordinates the live migration state machine",
        "TooZ lock groups prevent concurrent operations on the same instance",
        "Final pause and switch: instance paused briefly, state transferred, instance resumed on destination",
        "Instance actions updated to reflect the migration completion",
        "Placement resource allocations swapped between source and destination",
        "User receives 202 Accepted"
      ],
      "system_responses": [
        "202 Accepted with migration ID",
        "Instance enters MIGRATING state, then VERIFY_RESUME, then RESUMED",
        "Source compute node releases resource allocations",
        "Destination compute node receives resource allocations",
        "Migration record created with status=finished"
      ],
      "data_changes": [
        "Migration row created with initial status=check_cell0",
        "Instance compute_host and host fields updated on destination",
        "Placement allocations transferred between compute hosts",
        "InstanceAction records logged for each migration step"
      ],
      "error_cases": [
        "Destination host lacks sufficient resources: migration rejected during pre-check",
        "Network bandwidth insufficient: live migration stalls or times out",
        "Incompatible CPU between hosts: migration fails with CPU capability mismatch",
        "Source compute goes down during migration: instance lost, must be restored from storage",
        "Conductor unreachable: build request cannot be dispatched"
      ]
    },
    {
      "name": "Resize an instance (change flavor)",
      "type": "primary",
      "steps": [
        "User submits POST /servers/{id}/action with action=resize, specifying a new flavor_id",
        "API controller verifies the user has permissions to resize and the target flavor exists",
        "Nova creates a resize request and allocates resources on the destination host",
        "Scheduler selects a destination host for the resized instance",
        "Instance is powered off and migrated to the destination (similar to live migration but with shutdown)",
        "Disk is resized on the destination compute node",
        "Instance boots on the destination with new flavor specs",
        "User must confirm (POST /servers/{id}/action with action=confirmResize) or revert (action=revertResize)",
        "On confirm: source resources released, migration marked complete",
        "On revert: instance and disk moved back to original host"
      ],
      "system_responses": [
        "202 Accepted with resize confirmation required",
        "Instance enters VERIFY_RESIZE state until confirmed",
        "Disk resized on destination compute node",
        "New flavor specs applied (vCPUs, memory, disk)"
      ],
      "data_changes": [
        "ResizeRequest record created in database",
        "Instance flavor updated to new flavor",
        "Resource allocations adjusted on both source and destination",
        "Migration record created with status=completed or reverted"
      ],
      "error_cases": [
        "No host with sufficient resources for target flavor: resize rejected",
        "User does not confirm within timeout: resize automatically reverts",
        "Disk resize fails on destination: revert triggered automatically",
        "Conductor service unavailable: resize request cannot proceed"
      ]
    },
    {
      "name": "List and filter servers with microversion API",
      "type": "primary",
      "steps": [
        "User sends GET /servers with query parameters (status, image_id, flavor_id, host, project_id)",
        "API controller applies X-OpenStack-Nova-API-Version header for microversion",
        "ServersController.index() queries Instance objects via the object layer",
        "Filters applied at the database level via SQLAlchemy queries",
        "View module serializes the response with microversion-aware response format",
        "User receives filtered list of servers with metadata links"
      ],
      "system_responses": [
        "200 OK with paginated server list",
        "Response format varies based on microversion",
        "Links to server details, actions, and migrations included"
      ],
      "data_changes": [],
      "error_cases": [
        "Invalid microversion header: API returns 400 BadVersion",
        "Malformed query parameters: API returns 400 BadRequest",
        "Unauthorized: Keystone rejects token, API returns 401 Unauthorized"
      ]
    },
    {
      "name": "Access instance console via noVNC proxy",
      "type": "secondary",
      "steps": [
        "User authenticates with Keystone and requests GET /servers/{id}/actions/os-get-vnc-console",
        "API controller validates access and creates a console ticket via VncConsoleManager",
        "nova-novncproxy service receives the VNC connection request with the ticket",
        "Proxy authenticates the ticket and forwards the WebSocket connection to the compute node's VNC server",
        "User sees the VM console in their browser via the noVNC WebSocket connection"
      ],
      "system_responses": [
        "200 OK with console URL and type (novnc/spicehtml5/serial)",
        "Proxy tunnels WebSocket traffic between browser and compute node",
        "Ticket expires after configured timeout"
      ],
      "data_changes": [
        "Console ticket created with expiration timestamp",
        "Console entry logged in the database"
      ],
      "error_cases": [
        "Instance not running: console request rejected",
        "VNC server not listening on compute node: proxy returns 500",
        "Ticket expired: authentication rejected by proxy"
      ]
    }
  ],
  "backend": {
    "applicable": true,
    "data_stores": [
      "PostgreSQL (primary production database)",
      "MySQL/MariaDB (alternative production database)",
      "SQLite (test fallback)",
      "Alembic (database migration framework)",
      "oslo.db (database session management with retry logic)"
    ],
    "integrations": [
      "OpenStack Keystone — authentication and authorization",
      "OpenStack Glance — VM image service",
      "OpenStack Neutron — virtual networking and security groups",
      "OpenStack Cinder — block storage volume management",
      "OpenStack Placement — resource provider tracking and allocation",
      "RabbitMQ via oslo.messaging — inter-service RPC messaging",
      "Barbican via castellan — cryptographic key management",
      "Dogpile.cache via oslo.cache — caching layer"
    ],
    "infrastructure": [
      "Distributed multi-process architecture: nova-compute, nova-conductor, nova-scheduler as separate daemons",
      "Multi-cell deployment support (cells v2) with cell0 (metadata) and cell1+ (compute hosts)",
      "Eventlet green threads with native threading fallback",
      "Pluggable virtualization drivers via Stevedore entry points (libvirt, VMware, ZVM, Ironic)",
      "Pluggable scheduler filters and weights via Stevedore entry points",
      "WSGI pipeline via PasteDeploy (api-paste.ini)",
      "Ansible roles and playbooks for deployment",
      "Zuul CI/CD pipeline for integration testing",
      "Devstack for single-node deployment and testing",
      "Docker for containerized CI environments"
    ]
  },
  "rubric_coverage": {
    "covered": [
      "project_overview",
      "actors_identified",
      "user_journeys",
      "tech_stack",
      "data_layer",
      "api_surface",
      "integration_boundaries",
      "deployment_model",
      "concurrency_model",
      "security_model",
      "configuration_management",
      "plugin_extensibility"
    ],
    "gaps": [
      "exact_oslo_library_versions — runtime versions use >= lower_bound semantics from requirements.txt",
      "metadata_service_detail — nova/api/metadata/ sub-service not examined in depth",
      "optional_driver_complexity — VMware, ZVM, and Ironic drivers have additional complexity not fully explored",
      "migration_file_count — full Alembic migration history may span more files than visible in scan depth",
      "cell_rpc_protocol_details — exact messaging protocol between cells and conductor not fully traced",
      "performance_characteristics — no benchmark data or performance profiles documented in source"
    ]
  }
}
```

---

## Architecture Decisions

All architectural choices with rationale and alternatives considered.

```json
{
  "decisions": [
    {
      "id": "DEC-001",
      "question": "How should compute orchestration be distributed across processes?",
      "choice": "Three-process distributed architecture: nova-compute, nova-conductor, and nova-scheduler run as separate daemons communicating via RPC (oslo.messaging).",
      "rationale": "Separating compute, conductor, and scheduler into distinct processes enables independent scaling, fault isolation, and cell-based horizontal growth. Compute nodes have no direct database access, improving security and allowing them to run in untrusted tenant environments. The conductor service centralizes database operations, reducing the attack surface of compute nodes.",
      "alternatives_considered": [
        {
          "option": "Monolithic single-process Nova",
          "rejected_because": "Would not scale horizontally; compute nodes would need direct database access, creating security risks and bottlenecks"
        },
        {
          "option": "Microservices with separate API per function",
          "rejected_because": "OpenStack ecosystem requires tightly integrated services; finer granularity would add complexity without proportional benefit at the time of design"
        }
      ],
      "phase": "backend",
      "timestamp": "2026-08-26T00:00:00Z"
    },
    {
      "id": "DEC-002",
      "question": "How should Nova manage its data models across API versions and database migrations?",
      "choice": "Two-layer data model: SQLAlchemy ORM models in nova/db/ with Shadow tables for soft deletes, wrapped by oslo.versionedobjects (65 object classes with explicit VERSION attributes) in nova/objects/.",
      "rationale": "Versioned objects provide API-level backward compatibility independent of database schema changes. Shadow tables enable audit trails and soft deletes without complex SQL logic. The 'Smart Managers, Dumb Data' pattern separates business logic from data, making both independently testable.",
      "alternatives_considered": [
        {
          "option": "Single ORM model layer without versioned objects",
          "rejected_because": "Would require database migrations for every API change, breaking backward compatibility"
        },
        {
          "option": "Flat NoSQL data store",
          "rejected_because": "OpenStack services expect relational data with strong consistency; SQL provides necessary transactional guarantees"
        }
      ],
      "phase": "backend",
      "timestamp": "2026-08-26T00:00:00Z"
    },
    {
      "id": "DEC-003",
      "question": "What is the REST API communication strategy and versioning approach?",
      "choice": "REST API over WSGI with microversioning (2.1 base, currently 2.104). URL routing via Routes library with a custom ProjectMapper. All endpoints return JSON. Microversions controlled via X-OpenStack-Nova-API-Version header.",
      "rationale": "Microversioning allows Nova to evolve its API without breaking existing clients. The 390+ microversion changes show a highly iterative development approach. WSGI with PasteDeploy provides a standard deployment interface compatible with all OpenStack services. JSON-only response simplifies client code.",
      "alternatives_considered": [
        {
          "option": "URL-based versioning (e.g., /v1/, /v2/)",
          "rejected_because": "URL-based versions create permanent URL endpoints that cannot be deprecated; microversion header allows deprecation while keeping a single endpoint path"
        },
        {
          "option": "GraphQL API",
          "rejected_because": "OpenStack ecosystem uses REST; changing to GraphQL would break compatibility with existing client SDKs and tooling"
        }
      ],
      "phase": "backend",
      "timestamp": "2026-08-26T00:00:00Z"
    },
    {
      "id": "DEC-004",
      "question": "Which virtualization backend should be the default?",
      "choice": "Libvirt (KVM/QEMU/LXC/Parallels) as the default driver, with VMware, IBM Z (ZVM), and bare metal (Ironic) as optional drivers loaded via Stevedore entry points.",
      "rationale": "Libvirt is the most widely deployed virtualization stack in OpenStack environments and has the most mature feature set. Pluggable driver architecture via Stevedore allows Nova to support diverse hardware without coupling the core codebase to specific hypervisor logic.",
      "alternatives_considered": [
        {
          "option": "Make all drivers first-class with equal complexity in core",
          "rejected_because": "Would bloat the core codebase with driver-specific code that only a fraction of users need"
        },
        {
          "option": "Container-only runtime (Docker/LXC)",
          "rejected_because": "At the time of Nova's design, VM workloads dominated cloud demand; containers are handled by separate OpenStack projects (Sahara, Magnum)"
        }
      ],
      "phase": "backend",
      "timestamp": "2026-08-26T00:00:00Z"
    },
    {
      "id": "DEC-005",
      "question": "How should Nova scale to support thousands of compute nodes?",
      "choice": "Cells v2 architecture: Cell0 is a metadata-only database; Cell1+ each have their own database, conductor, and compute hosts. Conductor routes requests between cells via RPC.",
      "rationale": "Single-database Nova hits scalability limits around a few thousand hosts due to database connection pools and lock contention. Cell isolation allows each cell to scale independently with its own compute, conductor, and database — enabling cloud providers to grow Nova horizontally.",
      "alternatives_considered": [
        {
          "option": "Database partitioning within a single Nova deployment",
          "rejected_because": "Database-level partitioning is harder to manage and still creates a single point of failure for the conductor"
        },
        {
          "option": "Fully distributed without cells (peer-to-peer compute)",
          "rejected_because": "Without the conductor/routing layer, there is no centralized resource tracking or scheduling coordination"
        }
      ],
      "phase": "backend",
      "timestamp": "2026-08-26T00:00:00Z"
    },
    {
      "id": "DEC-006",
      "question": "What concurrency model should Nova use for handling requests?",
      "choice": "Eventlet green threads as the default concurrency model, with a native Python threading fallback via concurrency_backend configuration option.",
      "rationale": "Eventlet provides non-blocking I/O at the application level, allowing a single process to handle thousands of concurrent connections. The threading fallback accommodates environments where eventlet is incompatible (e.g., certain glibc versions, profiler tools). Test infrastructure enforces greenlet leak detection to prevent resource exhaustion.",
      "alternatives_considered": [
        {
          "option": "Asyncio-based concurrency",
          "rejected_because": "oslo.* library ecosystem is built on eventlet; migrating to asyncio would require rewriting the entire dependency chain"
        },
        {
          "option": "Thread-per-request with native Python threads",
          "rejected_because": "Native threads consume more memory and OS resources than green threads; would require more compute nodes for the same load"
        }
      ],
      "phase": "backend",
      "timestamp": "2026-08-26T00:00:00Z"
    },
    {
      "id": "DEC-007",
      "question": "How should authorization be enforced across the API layer?",
      "choice": "oslo.policy with 56 policy modules defining fine-grained RBAC rules. Custom policy enforcer entry point (nova.policy:get_enforcer). Policy rules checked at each API endpoint via the middleware stack.",
      "rationale": "oslo.policy is the OpenStack standard for authorization, enabling consistent policy management across all OpenStack services. 56 policy files correspond to API modules, providing granular control over which roles can perform which actions. Centralized enforcer entry point allows Nova-specific policy behavior.",
      "alternatives_considered": [
        {
          "option": "Custom authorization framework",
          "rejected_because": "Would not be compatible with existing OpenStack policy tools (oslopolicy-sample-generator, nova-policy CLI) and would diverge from ecosystem standards"
        },
        {
          "option": "Attribute-based access control (ABAC)",
          "rejected_because": "oslo.policy supports role-based rules which are simpler to manage and audit; ABAC complexity was not justified for Nova's use case"
        }
      ],
      "phase": "backend",
      "timestamp": "2026-08-26T00:00:00Z"
    },
    {
      "id": "DEC-008",
      "question": "How should Nova support pluggable scheduler filters and weight functions?",
      "choice": "Stevedore entry points for scheduler filters (19 filters) and weight plugins, with a custom RequestFilter base class providing get_filters() and get_weights() pattern.",
      "rationale": "Different cloud deployments have vastly different hardware and scheduling requirements (NUMA topology, PCI passthrough, affinity, availability zones). Pluggable filters allow operators to enable only the filters they need. Stevedore provides a standard Python plugin loading mechanism.",
      "alternatives_considered": [
        {
          "option": "Hard-coded scheduler logic",
          "rejected_because": "Would force all operators to use the same scheduling policy, which does not work across heterogeneous deployments"
        },
        {
          "option": "External scheduler service",
          "rejected_because": "Scheduling is latency-sensitive and requires tight integration with placement resource data; external service would add network overhead"
        }
      ],
      "phase": "backend",
      "timestamp": "2026-08-26T00:00:00Z"
    },
    {
      "id": "DEC-009",
      "question": "How should privileged operations be isolated from untrusted API code?",
      "choice": "oslo.privsep with privilege separation helpers in nova/privsep/. Privileged operations (host commands, block device operations) are decorated with privsep decorators and execute in a separate process via oslo-rootwrap.",
      "rationale": "Nova-compute runs as root to manage VMs but should not trust input from the API layer. Privilege separation ensures that even if an API controller is compromised, the damage is limited to unprivileged operations. Rootwrap adds an additional layer by explicitly whitelisting allowed host commands.",
      "alternatives_considered": [
        {
          "option": "Run nova-compute as unprivileged user",
          "rejected_because": "Many hypervisor operations (KVM, network bridging, block device attachment) require root privileges; running unprivileged would disable most functionality"
        },
        {
          "option": "Sudo-based privilege escalation",
          "rejected_because": "oslo.privsep is more secure than sudo (compartmentalized privilege, no shared credentials) and more efficient (no password prompt overhead)"
        }
      ],
      "phase": "backend",
      "timestamp": "2026-08-26T00:00:00Z"
    },
    {
      "id": "DEC-010",
      "question": "What is the messaging transport for inter-service RPC communication?",
      "choice": "oslo.messaging with RabbitMQ via Kombu as the default transport. Message queues handle RPC requests between API, scheduler, conductor, and compute services.",
      "rationale": "RabbitMQ is the most widely deployed message broker in OpenStack deployments. oslo.messaging provides a transport abstraction that allows switching transports (RabbitMQ, ZeroMQ, in-memory) via configuration. Kombu provides robust message delivery with acknowledgments and dead-letter queues.",
      "alternatives_considered": [
        {
          "option": "ZeroMQ transport",
          "rejected_because": "ZeroMQ has no message persistence; lost messages during broker restart would cause data inconsistency. RabbitMQ's persistence guarantees are essential for build requests and migrations."
        },
        {
          "option": "Direct TCP connections between services",
          "rejected_because": "Would create tight coupling between services, make horizontal scaling difficult, and lack message queuing semantics"
        }
      ],
      "phase": "backend",
      "timestamp": "2026-08-26T00:00:00Z"
    },
    {
      "id": "DEC-011",
      "question": "How should build requests be coordinated between scheduler and compute?",
      "choice": "Scheduler → Conductor → Compute RPC chain with cursive distributed state machine for live migration coordination and TooZ lock groups for distributed locking.",
      "rationale": "The three-step RPC chain ensures that resource allocation (Placement), database updates (Conductor), and VM lifecycle (Compute) are coordinated through consistent pathways. Cursive provides a formal state machine for live migration, preventing race conditions during the complex pre-copy and switchover phases. TooZ prevents concurrent operations on the same instance.",
      "alternatives_considered": [
        {
          "option": "Direct Scheduler → Compute RPC",
          "rejected_because": "Would bypass the conductor layer, losing database consistency guarantees and cell-aware routing"
        },
        {
          "option": "Synchronous build (no RPC layer)",
          "rejected_because": "Synchronous builds would block API threads during potentially long-running VM provisioning, degrading API throughput"
        }
      ],
      "phase": "backend",
      "timestamp": "2026-08-26T00:00:00Z"
    },
    {
      "id": "DEC-012",
      "question": "How should configuration options be organized across the codebase?",
      "choice": "Modular config options in nova/conf/ (48 config modules), aggregated via oslo.config entry point. All options defined as oslo.config OPT objects with section names, types, help text, and default values.",
      "rationale": "Modular config files mirror Nova's subsystem architecture — each subsystem has its own config module. oslo.config provides a unified CLI interface, config file parsing, and runtime reloading. The entry point registration enables oslo-config-generator to produce a complete nova.conf sample.",
      "alternatives_considered": [
        {
          "option": "Single monolithic config file",
          "rejected_because": "With 48+ subsystems, a single config file would be unwieldy and difficult to navigate. Modular approach enables per-subsystem documentation and validation."
        },
        {
          "option": "YAML/JSON config format instead of oslo.config INI-style",
          "rejected_because": "oslo.config supports the existing OpenStack deployment tooling (oslo-config-generator, Devstack, Ansible) and is the ecosystem standard"
        }
      ],
      "phase": "backend",
      "timestamp": "2026-08-26T00:00:00Z"
    }
  ]
}
```

---

## Technical Summary

Source: `.banneker/documents/TECHNICAL-SUMMARY.md`

# Technical Summary — OpenStack Nova

## Project Overview

**OpenStack Nova** is OpenStack's distributed compute service that manages the lifecycle of instances (virtual machines and bare metal) in a cloud infrastructure, including creation, scheduling, live migration, resizing, and deletion across multi-cell deployments.

Cloud operators need a scalable, multi-tenant compute orchestration layer that abstracts heterogeneous virtualization technologies (Libvirt/KVM, VMware, IBM Z, bare metal via Ironic) into a unified REST API, while supporting horizontal scaling through cells v2, integrating with other OpenStack services (Glance for images, Neutron for networking, Cinder for block storage, Keystone for authentication), and providing fine-grained RBAC with microversioned REST APIs.

## Actors

### Human Actors

- **Cloud Administrator** — Manages Nova infrastructure including cells, aggregates, host aggregates, security groups, quotas, and service management. Capabilities include creating and managing host aggregates, configuring cell mappings, enabling/disabling nova-compute and nova-scheduler services, setting quotas and limits per project, running management CLI commands, configuring policy rules, and monitoring service health.

- **Cloud User (Tenant)** — End user who provisions and manages compute instances within their project/tenant. Capabilities include creating, listing, showing, updating, and deleting servers; booting instances from images or snapshots; resizing instances; rebooting/pausing/resuming/suspending/stopping instances; attaching/detaching volumes; listing flavors, images, hypervisors, and aggregates; accessing console via noVNC, Spice, or serial proxy; launching instances via user-data and config-drive; managing server groups; and using microversioned API features.

### System Actors

- **OpenStack Keystone** — Identity and authentication service that validates tokens, enforces RBAC policy, and provides the context for all Nova API requests.

- **OpenStack Glance** — Image service that Nova queries for VM disk images, metadata, and image properties used in filter-based host scheduling.

- **OpenStack Neutron** — Networking service that Nova integrates with for virtual network interface assignment, security groups, and port management.

- **OpenStack Cinder** — Block storage service that Nova integrates with for attaching persistent block storage volumes to instances.

- **OpenStack Placement** — Resource provider tracking service that Nova queries and updates for resource allocation (vCPUs, memory, disk, custom resources) at each compute node.

- **VM Instance** — The virtual machine or bare-metal instance managed by Nova, which exposes a metadata service and is controlled via hypervisor-level operations.

## Technology Stack

OpenStack Nova is a Python-based backend service built on the OpenStack ecosystem, leveraging:

- **Language & Runtime:** Python with Eventlet green threads for concurrency
- **Data Layer:** PostgreSQL/MySQL/MariaDB as the primary production database, with SQLite as test fallback; Alembic for migrations; oslo.db for session management
- **REST API:** WSGI pipeline with PasteDeploy, Routes for URL routing, microversioned JSON API (2.1 base, currently 2.104)
- **Virtualization:** Libvirt (KVM/QEMU/LXC/Parallels) as default driver, with VMware, IBM Z (ZVM), and Ironic as pluggable drivers via Stevedore entry points
- **Messaging:** RabbitMQ via oslo.messaging with Kombu transport for inter-service RPC
- **Authorization:** oslo.policy with 56 policy modules for fine-grained RBAC
- **Configuration:** oslo.config with 48 modular config modules
- **Privilege Separation:** oslo.privsep with oslo-rootwrap
- **Distributed Locking:** TooZ lock groups
- **State Machine:** cursive for live migration coordination
- **Caching:** Dogpile.cache via oslo.cache
- **Security/Secrets:** Barbican via castellan for cryptographic key management
- **Pluggability:** Stevedore for scheduler filters (19 filters) and weight plugins
- **Deployment:** Ansible playbooks, Devstack for single-node deployment, Docker for CI

## Core Flows

### Create and Boot a Server Instance

The Cloud User (Tenant) authenticates with OpenStack Keystone and submits a POST request to the `/servers` endpoint with image_id, flavor_id, network_info, and optional user_data. The API controller validates the request against the current microversion schema, and Keystone middleware authenticates the token and applies policy rules (DEC-003). The ComputeManager.create() method is called, which notifies the Scheduler via RPC. The Scheduler selects a host using filters (affinity, NUMA, PCI, image properties, aggregate filters) and weights (DEC-008), then routes the build request through the Conductor service in a cell-aware manner (DEC-005). The Conductor dispatches the build request to the target nova-compute node via RabbitMQ (DEC-010). The compute node reserves resource allocations in OpenStack Placement, downloads the image from OpenStack Glance if not cached, allocates network resources via OpenStack Neutron, and spawns the VM via the Libvirt virt driver. The instance state transitions to ACTIVE, and the Cloud User (Tenant) receives a 202 Accepted response (DEC-011).

### Live Migrate a Running Instance

The Cloud User (Tenant) submits a POST request to `/servers/{id}/action` with action=migrate. The API controller validates the microversion for migration features, and the ComputeManager.migrate_server() initiates the migration flow. The Scheduler selects a destination host using the same filter/weight pipeline (DEC-008). The Conductor coordinates the migration request to the destination compute node. A pre-copy phase transfers memory pages of the running VM over the network. The cursive distributed state machine coordinates the live migration state, and TooZ lock groups prevent concurrent operations (DEC-011). During the final pause and switch, the instance is paused briefly, state is transferred, and the instance resumes on the destination. Resource allocations in OpenStack Placement are swapped between source and destination (DEC-011).

### Resize an Instance (Change Flavor)

The Cloud User (Tenant) submits a POST request to `/servers/{id}/action` with action=resize, specifying a new flavor_id. Nova creates a resize request, allocates resources on the destination host, selects a destination via the scheduler, powers off the instance, migrates it to the destination, and resizes the disk. The Cloud User (Tenant) must confirm or revert the resize (DEC-011).

### List and Filter Servers

The Cloud User (Tenant) sends a GET request to `/servers` with query parameters. The API controller applies the X-OpenStack-Nova-API-Version header for microversion support, and the ServersController.index() queries Instance objects via the SQLAlchemy object layer. Filters are applied at the database level, and the response is serialized with microversion-aware format (DEC-003).

## Architecture Decisions

1. **Three-Process Distributed Architecture** (DEC-001): Nova-compute, nova-conductor, and nova-scheduler run as separate daemons communicating via RPC, enabling independent scaling, fault isolation, and cell-based horizontal growth.

2. **Two-Layer Data Model** (DEC-002): SQLAlchemy ORM models in nova/db/ with Shadow tables for soft deletes, wrapped by oslo.versionedobjects (65 object classes with explicit VERSION attributes) in nova/objects/. This provides API-level backward compatibility independent of database schema changes.

3. **REST API with Microversioning** (DEC-003): REST API over WSGI with microversioning (2.1 base, currently 2.104), URL routing via Routes with ProjectMapper, JSON responses, and microversions controlled via X-OpenStack-Nova-API-Version header.

4. **Libvirt as Default Virtualization Driver** (DEC-004): Libvirt (KVM/QEMU/LXC/Parallels) as the default, with VMware, IBM Z (ZVM), and Ironic as optional drivers loaded via Stevedore entry points.

5. **Cells v2 Architecture** (DEC-005): Cell0 is a metadata-only database; Cell1+ each have their own database, conductor, and compute hosts, enabling horizontal scaling to thousands of compute nodes.

6. **Eventlet Concurrency Model** (DEC-006): Eventlet green threads as the default, with native Python threading fallback, allowing a single process to handle thousands of concurrent connections.

7. **oslo.policy for Authorization** (DEC-007): 56 policy modules defining fine-grained RBAC rules with a custom enforcer entry point.

8. **Stevedore for Scheduler Pluggability** (DEC-008): Pluggable scheduler filters (19 filters) and weight plugins via Stevedore entry points.

9. **oslo.privsep for Privilege Separation** (DEC-009): Privileged operations execute in a separate process via oslo-rootwrap, limiting damage from API layer compromise.

10. **RabbitMQ Messaging** (DEC-010): oslo.messaging with RabbitMQ via Kombu as default transport for inter-service RPC communication.

11. **RPC Chain with State Machine Coordination** (DEC-011): Scheduler → Conductor → Compute RPC chain with cursive for live migration and TooZ for distributed locking.

12. **Modular Configuration** (DEC-012): 48 modular config modules in nova/conf/, aggregated via oslo.config entry point with section names, types, help text, and default values.

---

## Technology Stack

Source: `.banneker/documents/STACK.md`

# Technology Stack — OpenStack Nova

## Stack Overview

OpenStack Nova is a large-scale, distributed Python backend service built entirely on the OpenStack ecosystem of libraries and frameworks. The stack is designed for horizontal scalability, pluggability, and compatibility with the broader OpenStack cloud platform.

| Category | Technology | Purpose |
|----------|-----------|---------|
| Language | Python | Primary programming language |
| Concurrency | Eventlet | Green thread-based non-blocking I/O |
| Web Framework | WSGI / PasteDeploy | HTTP request handling pipeline |
| Routing | Routes | URL mapping with ProjectMapper |
| Database ORM | SQLAlchemy | ORM layer with Shadow table support |
| Database Migration | Alembic | Schema versioning and migration |
| Database Sessions | oslo.db | Session management with retry logic |
| Database (Primary) | PostgreSQL | Production database |
| Database (Alternative) | MySQL/MariaDB | Alternative production database |
| Database (Test) | SQLite | Test environment fallback |
| RPC Transport | oslo.messaging | Inter-service RPC messaging |
| Message Broker | RabbitMQ | Message queue via Kombu |
| Serialization | Kombu | Message delivery with acknowledgments |
| Caching | Dogpile.cache | Distributed caching layer via oslo.cache |
| Authorization | oslo.policy | Fine-grained RBAC (56 policy modules) |
| Configuration | oslo.config | Modular config with 48 modules |
| Privilege Separation | oslo.privsep | Separated privilege execution |
| Command Whitelist | oslo-rootwrap | Explicit whitelist for host commands |
| Distributed Locking | TooZ | Lock groups for distributed operations |
| State Machine | cursive | Live migration coordination |
| Plugin Loading | Stevedore | Dynamic plugin entry points |
| Virtualization Driver | Libvirt | Default hypervisor driver (KVM/QEMU/LXC/Parallels) |
| Alternative Drivers | VMware | VMware vSphere virtualization |
| Alternative Drivers | ZVM | IBM Z (s390x) virtualization |
| Alternative Drivers | Ironic | Bare metal provisioning |
| Security Secrets | Barbican | Cryptographic key management via castellan |
| Deployment | Ansible | Infrastructure deployment automation |
| Test Deployment | Devstack | Single-node OpenStack deployment for testing |
| CI/CD | Zuul | Integration testing pipeline |
| Containerization | Docker | Containerized CI environments |

### Technology Rationale Highlights

- **Python with Eventlet (DEC-006):** Python for OpenStack ecosystem compatibility; Eventlet provides non-blocking I/O at the application level for thousands of concurrent connections.
- **WSGI and PasteDeploy (DEC-003):** Standard deployment interface compatible with all OpenStack services.
- **SQLAlchemy with Shadow Tables (DEC-002):** ORM layer with Shadow tables for soft deletes and audit trails.
- **PostgreSQL as Primary (DEC-002):** Strong consistency, JSONB support, reliable transactions.
- **RabbitMQ via oslo.messaging (DEC-010):** Persistent message delivery for build/migration operations.
- **oslo.policy with RBAC (DEC-007):** 56 policy modules for fine-grained RBAC across all API endpoints.
- **Libvirt as Default Driver (DEC-004):** Most widely deployed virtualization stack in OpenStack.
- **oslo.privsep with oslo-rootwrap (DEC-009):** Compartmentalized privilege execution limits API compromise damage.
- **Stevedore for Pluggability (DEC-008):** 19 pluggable scheduler filters for heterogeneous scheduling.
- **Cells v2 (DEC-005):** Cell0 metadata + Cell1+ independent deployments for horizontal scaling.

---

## Infrastructure Architecture

Source: `.banneker/documents/INFRASTRUCTURE-ARCHITECTURE.md`

# Infrastructure Architecture — OpenStack Nova

## System Topology

OpenStack Nova follows a distributed multi-process architecture where four service types communicate via RPC over a message broker. The system is organized around cells for horizontal scaling and privilege separation for security.

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
1. Cloud User authenticates with Keystone → submits POST /servers
2. nova-api validates microversion, authenticates token, applies policy rules (DEC-003, DEC-007)
3. nova-api calls ComputeManager.create() → routes to nova-scheduler via RabbitMQ (DEC-010)
4. nova-scheduler applies filter/weight pipeline (DEC-008)
5. nova-scheduler routes to appropriate nova-conductor based on cell mapping (DEC-005)
6. nova-conductor routes to target nova-compute in the selected cell via RabbitMQ (DEC-010)
7. nova-compute: reserves resources in Placement, downloads image from Glance, allocates network via Neutron, spawns VM via Libvirt, updates Instance state to ACTIVE
8. Response flows back: 202 Accepted

### Live Migration Flow
1. Cloud User submits POST /servers/{id}/action with action=migrate
2. nova-scheduler selects destination host (DEC-008)
3. nova-conductor coordinates migration to destination compute node
4. Pre-copy phase: source nova-compute transfers memory pages over network
5. cursive state machine coordinates migration state (DEC-011)
6. TooZ lock groups prevent concurrent operations (DEC-011)
7. Final switch: instance resumed on destination
8. Placement allocations swapped between source and destination (DEC-011)

### Security Boundaries

- **Trust Zones:** Cloud User → nova-api (Untrusted) → nova-conductor (Trusted) → nova-compute (Root)
- **Authentication:** Keystone middleware validates every API request token; oslo.policy enforces RBAC at each endpoint (56 policy modules)
- **Privilege Separation (DEC-009):** nova-compute runs as root; oslo.privsep separates privileged code; oslo-rootwrap whitelists allowed host commands; API-layer code cannot execute privileged operations directly

### Scalability

- **Cells v2 (DEC-005):** Each cell has its own database, conductor, and scheduler
- **Eventlet (DEC-006):** nova-api handles thousands of concurrent connections per process
- **Database:** oslo.db manages connection pools with automatic retries; cell isolation reduces contention

---

## Technical Draft

Source: `.banneker/documents/TECHNICAL-DRAFT.md`

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
| vm_mode | string | Default xml | VM startup mode |
| scheduled_at | datetime | Nullable | Timestamp of scheduler selection |
| created_at | datetime | Required | Record creation timestamp |
| updated_at | datetime | Nullable | Last update timestamp |
| deleted_at | datetime | Nullable | Soft delete timestamp |
| deleted | integer | Default 0 | Soft delete flag |
| locked | boolean | Default False | Instance lock status |
| locked_by | string | Nullable | Lock holder |
| power_state | integer | Default 4 | Power state (NOSTATE=0, RUNNING=1, SHUTDOWN=4) |
| task_state | string | Nullable | Current task state |
| vm_state | string | Default stopped | VM state (stopped, running, paused) |
| availability_zone | string | Nullable | Availability zone for placement |
| host | string | Nullable | Current compute host |
| cell_name | string | Nullable | Cell name for cell-aware routing |

**Relationships:** Belongs to one Flavor, one Project, references one Image (Glance); may have many InstanceActions, VirtualInterfaces, BlockDeviceMapping, one Migration, one ResizeRequest.

#### InstanceAction

Tracks individual operations on an Instance. Contains action, operation, start/end timestamps, state, and expected_event.

#### InstanceActionEvent

Sub-task details within an InstanceAction for granular tracking.

#### RequestSpec

Carries scheduling context: instance UUID, instance type, requested_properties (JSON), requested_capabilities (JSON), instance_group_policy (JSON).

#### CellMapping

Defines cells v2 topology with name, transport URL (RabbitMQ), and database connection.

#### ComputeNode

Tracks resource allocation: vcpus, vcpus_used, memory_bytes, memory_bytes_used, local_gb, local_gb_used, hypervisor_type, hypervisor_version, overcommit ratios, running_vms, current_workload.

#### Migration

Tracks migration operations with instance UUID, source/destination compute, source/destination node, migration type, status (check_cell0, check_source, pre_live_migration, etc.), token, and allocation details.

#### ResizeRequest

Tracks resize operations with instance UUID, old/new instance type, source/destination compute, and status (confirmed, reverted, post-copy-migrate).

#### Flavor

Defines instance resource specifications: id, name, vcpus, memory_mb, disk, ephemeral, swap, rxtx_factor, vcpus_weight, is_public, properties (JSON).

### API Surface

**Core Resources:**
- GET /servers — List all servers (paginated, microversion 2.1+)
- GET /servers/{server_id} — Show server details (2.1+)
- POST /servers — Create a new server (2.1+)
- PUT /servers/{server_id} — Update server (2.2+)
- DELETE /servers/{server_id} — Delete a server (2.1+)

**Server Actions:** reboot, restart, pause, unpause, suspend, resume, stop, start, lock, unlock, migrate, shelve, unshelve, rescue, unrescue, rebuild, resize, confirmResize, revertResize, createBackup

**Console Endpoints:** os-get-vnc-console, os-get-spice-console, os-get-serial-console

**Microversion-Aware Response:** Response format varies by X-OpenStack-Nova-API-Version header (2.1 through 2.104). 390+ microversion changes documented.

### Error Responses

| Status Code | Error Type | Trigger |
|-------------|-----------|---------|
| 400 | BadRequest | Invalid request body, microversion, parameters |
| 401 | Unauthorized | Invalid/expired Keystone token |
| 403 | Forbidden | Policy denial (oslo.policy) |
| 404 | NotFound | Instance, flavor, image, aggregate not found |
| 409 | Conflict | Instance locked, operation in progress |
| 413 | OverLimit | Quota exceeded |
| 500 | ServerError | Internal Nova error |
| 503 | ServiceUnavailable | Compute or scheduler unavailable |

### Testing Strategy

- **Unit tests:** stestr for individual function/class tests with greenlet leak detection
- **Functional tests:** Multi-service workflow tests with mock services for Keystone, Glance, Neutron, Cinder, Placement
- **Integration tests:** End-to-end tests via Zuul with DevStack deployments
- **Key patterns:** Fake driver for testing without hypervisor dependencies, database isolation per test, eventlet-aware tests with greenlet leak detection

---

## Portal Integration

Source: `.banneker/documents/PORTAL-INTEGRATION.md`

# Portal Integration — OpenStack Nova

## Integration Overview

| Integration | Type | Purpose | Direction |
|-------------|------|---------|-----------|
| OpenStack Keystone | Identity service | Authentication and RBAC authorization | Inbound (Nova calls Keystone) |
| OpenStack Glance | Image service | VM disk image serving and metadata | Outbound (Nova queries Glance) |
| OpenStack Neutron | Networking service | Virtual network interface, security groups, port management | Bidirectional |
| OpenStack Cinder | Block storage service | Persistent block volume attachment | Bidirectional |
| OpenStack Placement | Resource tracking | Resource provider allocation tracking | Bidirectional |
| RabbitMQ (oslo.messaging) | Message broker | Inter-service RPC communication | Internal |
| Barbican (castellan) | Secret management | Cryptographic key management | Inbound |
| Dogpile.cache (oslo.cache) | Caching layer | Distributed caching | Internal |

## Integration Details

### Keystone
- **Authentication flow:** Client authenticates with Keystone → token issued → client presents token to Nova → Nova Keystone middleware validates token via `/v3/tokens` → oslo.policy evaluates policy rules → access granted/denied
- **Error handling:** 401 Unauthorized (invalid token), 403 Forbidden (insufficient permissions), 503 Service Unavailable (Keystone unreachable, with retry)

### Glance
- **Data exchanged:** Image ID, metadata (architecture, min disk, min RAM), image properties for scheduler filtering, image data (stream) to compute nodes
- **Caching:** Compute nodes cache downloaded images locally; on cache hit, Glance is not queried
- **Error handling:** 404 Not Found, 403 Forbidden, 503 Service Unavailable, download timeout with exponential backoff retry

### Neutron
- **Data exchanged:** Port creation requests (MAC, IP, device_id), port data (ID, MAC, IP addresses, network ID), security group rules, port updates/deletion on resize/migration/delete
- **Security groups:** Two modes — Linux bridge (legacy iptables) and ML2/OVS (Neutron-managed)

### Cinder
- **Data exchanged:** Volume attachment/detachment requests, volume data (ID, device path, attachment ID), volume metadata, boot-from-volume info
- **Timeout:** Configurable (typically 300 seconds); retries with backoff

### Placement
- **Data exchanged:** Resource allocation (vCPUs, memory, disk, custom resources), allocation swaps (migration), resource release (delete/revert), provider registration, utilization queries
- **Scheduler integration:** Primary source of truth for resource availability — scheduler does not trust database-reported values
- **Timeout:** Very short (5 seconds) for scheduler queries; minimal retries

### RabbitMQ (oslo.messaging)
- **Queues:** scheduler (nova-api → nova-scheduler), scheduler_request_queue (nova-scheduler → nova-conductor), conductor (nova-scheduler/api → nova-conductor), compute.<hostname> (nova-conductor → nova-compute), cell.<cellname> (cross-cell)
- **Error handling:** Auto-reconnect with exponential backoff, message re-delivery on consumer crash, DLQ for exceeded retries

### Barbican (via castellan)
- **Purpose:** Cryptographic key management for instance disk encryption
- **Error handling:** KeyNotFound, 503 Service Unavailable (cached key material fallback), KeyExpired

### Dogpile.cache (via oslo.cache)
- **Cache entries:** Flavor by ID, Aggregate by name, Scheduler filter results (all with configurable TTL)
- **Error handling:** Cache miss falls back to database; cache backend unavailable bypasses cache

---

## Engineering Diagnosis

Source: `.banneker/documents/DIAGNOSIS.md`

# Engineering Diagnosis

## Survey Overview

- **Completion Status:** 90% complete
- **Phases Captured:** Phase 1 (Project), Phase 2 (Actors), Phase 3 (Walkthroughs), Phase 4 (Backend), Phase 5 (Rubric)
- **Total Gaps Identified:** 6 (from rubric_coverage.gaps)
- **Existing Decisions:** 12 (DEC-001 through DEC-012)

## Information Quality Assessment

| Survey Section | Completeness | Confidence Impact |
|----------------|--------------|-------------------|
| Project Context | 100% | None |
| Actors | 100% | None — 8 actors with detailed capabilities |
| Walkthroughs | 95% | Minimal — 5 walkthroughs with 40+ total steps |
| Backend Data Stores | 90% | Minor — version constraints missing |
| Backend Integrations | 95% | Minimal — 8 integrations documented |
| Backend Infrastructure | 85% | Minor — cell RPC details missing |
| Rubric Coverage | 80% | Minor — 12/18 items covered, 6 gaps specific |

**Overall: 90% complete**

## Identified Gaps

1. **exact_oslo_library_versions** (MEDIUM) — Runtime versions use >= lower_bound semantics
2. **metadata_service_detail** (LOW) — nova/api/metadata/ sub-service not examined in depth
3. **optional_driver_complexity** (LOW) — VMware, ZVM, and Ironic drivers have additional complexity
4. **migration_file_count** (LOW) — Full Alembic migration history may span more files
5. **cell_rpc_protocol_details** (MEDIUM) — Exact messaging protocol between cells and conductor not fully traced
6. **performance_characteristics** (MEDIUM) — No benchmark data or performance profiles

## Assessment

**PASS** — Survey provides comprehensive information for engineering recommendations. All required phases complete with substantial depth.

---

## Engineering Recommendations

Source: `.banneker/documents/RECOMMENDATION.md`

# Engineering Recommendations

## Recommendations Summary

| # | Area | Recommendation | Confidence |
|---|------|---------------|------------|
| 1 | Backend Framework | Continue oslo.* library ecosystem | HIGH |
| 2 | Database Architecture | Continue PostgreSQL with Shadow tables | HIGH |
| 3 | Messaging Transport | Continue RabbitMQ via oslo.messaging | HIGH |
| 4 | Distributed Concurrency | Continue eventlet + TooZ + cursive | HIGH |
| 5 | Pluggable Drivers | Continue Stevedore entry points | HIGH |
| 6 | Multi-cell Scaling | Continue cells v2 architecture | MEDIUM |
| 7 | Privilege Separation | Continue oslo.privsep + rootwrap | HIGH |
| 8 | Configuration | Continue oslo.config modular approach | HIGH |
| 9 | Testing Strategy | Continue Zuul + stestr + DevStack | MEDIUM |
| 10 | Observability | Continue nova-status + metrics exposure | MEDIUM |

---

## Engineering Proposals

Source: `.banneker/documents/ENGINEERING-PROPOSAL.md`

# Engineering Proposals

**Status:** All proposals awaiting approval (DEC-013 through DEC-015 NOT yet in architecture-decisions.json)

## DEC-013: Testing Strategy Architecture

**Decision:** Adopt a four-layer testing architecture:
1. **Unit Tests (stestr):** Single-function/class tests with greenlet leak detection. Never use pytest.
2. **Functional Tests (mock services):** Multi-service workflow tests with mocked Keystone, Glance, Neutron, Cinder, Placement.
3. **Integration Tests (Zuul CI/CD):** End-to-end tests via Zuul gate with real DevStack deployments.
4. **Performance Tests (baseline benchmarks):** Benchmark API latency, build throughput, migration speed.

**Confidence:** MEDIUM (60-75%). Testing strategy is a rubric gap — no test design patterns captured in survey.

## DEC-014: Observability Architecture

**Decision:** Adopt a three-layer observability architecture:
1. **Service Health (nova-status):** Extend nova-status for cell-aware health checking.
2. **Metrics Collection (Prometheus):** Expose Prometheus metrics via oslo-middleware and custom exporters (HTTP metrics, queue depth, RPC latency, DB query timing).
3. **Structured Logging (oslo.log):** All services use structured output with correlation IDs for cross-service tracing.

**Confidence:** MEDIUM (60-75%). Only nova-status explicitly mentioned in survey; no metrics framework or alerting strategy captured.

## DEC-015: Metadata Service Architecture

**Decision:** Adopt a local metadata service architecture:
1. **nova-api-metadata daemon:** Runs on each compute host alongside nova-compute.
2. **Local network isolation:** Listens on link-local address (169.254.169.254).
3. **Token-based authentication:** Short-lived tokens issued by nova-api.
4. **Caching:** Locally cached metadata with RPC invalidation from nova-conductor.

**Confidence:** MEDIUM (60-75%). The metadata_service_detail gap means the existing implementation was not examined in depth.

---
