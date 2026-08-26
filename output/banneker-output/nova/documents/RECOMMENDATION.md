# Engineering Recommendations

**Generated:** 2026-08-26T00:00:00Z
**Based on:** DIAGNOSIS.md analysis
**Confidence Baseline:** HIGH

## Recommendations Overview

This project is a mature production system (OpenStack Nova) with 12 existing architectural decisions already documented in architecture-decisions.json. These recommendations validate and document the existing architecture, identify areas where additional decisions may be needed, and provide structured analysis for each major architecture area.

Total recommendations: 10
Architecture areas addressed: Backend Framework, Database Architecture, Messaging Transport, Distributed Concurrency, Pluggable Driver Architecture, Multi-cell Scaling, Privilege Separation, Configuration Management, Testing Strategy, Observability

Confidence distribution:
- HIGH confidence: 6
- MEDIUM confidence: 4
- LOW confidence: 0

---

## Backend Framework: oslo.* Libraries

### Analysis

Nova uses the OpenStack `oslo.*` library ecosystem as its foundational framework. The survey identifies oslo.policy (authorization), oslo.db (database sessions), oslo.config (configuration), oslo.messaging (RPC transport), oslo.cache (caching), oslo.privsep (privilege separation), and oslo.versionedobjects (data model versioning). The `project.type` is "backend-service" and the walkthroughs demonstrate complex multi-service coordination requiring these libraries.

Walkthrough 1 (Create and boot) demonstrates oslo.policy enforcement, oslo.db session management, and oslo.messaging RPC coordination. Walkthrough 2 (Live migration) demonstrates oslo.versionedobjects state management and oslo.messaging inter-service coordination. Walkthrough 3 (Resize) demonstrates oslo.db transaction management across resource changes.

**Survey evidence:**
- `survey.backend.integrations` lists oslo.messaging (RabbitMQ), oslo.cache (Dogpile), oslo.policy, oslo.db, oslo.privsep, oslo.versionedobjects
- `survey.walkthroughs[].steps` reference oslo.middleware, oslo.policy, oslo.privsep, oslo.versionedobjects, oslo.db
- `survey.backend.infrastructure` references PasteDeploy WSGI pipeline (api-paste.ini)

**Survey gaps (from DIAGNOSIS):**
- `exact_oslo_library_versions` — runtime versions use >= lower_bound semantics from requirements.txt (affects feature availability assessment)

### Recommendation

**Continue using oslo.* library ecosystem as the core framework.** The existing decisions (DEC-001, DEC-006, DEC-007, DEC-010, DEC-012) document the specific libraries and their roles. This ecosystem is the OpenStack standard and is deeply integrated into Nova's architecture.

### Alternatives Considered

#### Alternative 1: Migrate to asyncio-based framework

- **Pros:** Modern Python concurrency model with native async/await support; better performance for I/O-bound workloads
- **Cons:** Would require rewriting the entire oslo.* dependency chain; OpenStack ecosystem is built on eventlet; breaking changes to all inter-service communication
- **Why not chosen:** The oslo.* ecosystem is eventlet-based by design. Migration would require rewriting oslo.messaging, oslo.db, oslo.middleware, and all Nova code that depends on them. No OpenStack project has completed such a migration as of the survey date.

#### Alternative 2: Replace oslo.* with lightweight independent libraries

- **Pros:** Reduced coupling; potentially smaller deployment footprint; more flexible version pinning
- **Cons:** Would lose OpenStack ecosystem compatibility; lose cross-project consistency; require building or selecting replacements for each oslo.* library
- **Why not chosen:** OpenStack services interoperate through the oslo.* ecosystem (e.g., oslo.policy, oslo.versionedobjects). Replacing these would create compatibility risks with Glance, Neutron, Cinder, Keystone, and Placement integrations.

### Trade-offs

**What you gain:**
- Full OpenStack ecosystem compatibility (Keystone auth, oslo.policy RBAC, oslo.versionedobjects compatibility)
- Mature, tested codebases with decades of combined production use across thousands of OpenStack deployments
- Standard tooling: oslopolicy-sample-generator, oslo-config-generator, oslo-db-manage

**What you give up:**
- Modern Python features (asyncio, typing improvements) not available in eventlet-based oslo libraries
- Potentially higher memory footprint compared to asyncio alternatives (green threads vs native async)

### Confidence

**HIGH (85-90% likelihood)**

### Confidence Rationale

- **Evidence quality:** HIGH — `survey.backend.integrations` explicitly lists 7 oslo.* libraries with specific roles. Survey walkthroughs demonstrate these libraries in action across all major operation flows. `survey.backend.infrastructure` confirms PasteDeploy WSGI integration.
- **Gap impact:** `exact_oslo_library_versions` gap means we cannot confirm which specific feature versions are available, but the >= lower_bound semantics in requirements.txt means any compatible version satisfies the architecture.
- **Assumptions:** OpenStack ecosystem remains eventlet-based for the foreseeable future (no major migration to asyncio observed).
- **Section citations:** `survey.backend.integrations`, `survey.walkthroughs[0].steps`, `survey.walkthroughs[1].steps`, `survey.backend.infrastructure`

---

## Database Architecture: PostgreSQL with Shadow Tables

### Analysis

The survey identifies PostgreSQL as the primary production database, with MySQL/MariaDB as an alternative and SQLite for tests. The existing DEC-002 decision documents the two-layer data model: SQLAlchemy ORM models in `nova/db/` with Shadow tables for soft deletes, wrapped by oslo.versionedobjects in `nova/objects/`. The walkthroughs demonstrate extensive database interactions: instance creation (build request → ACTIVE), live migration (compute_host/host field updates, resource allocation transfers), resize (ResizeRequest creation, flavor changes, resource adjustments), and console access (ticket logging).

Data changes from walkthroughs demonstrate complex transactional requirements: Instance rows, InstanceAction records, Shadow instance rows, Migration rows, ResizeRequest records, Placement resource allocations, Neutron port entries, and Console ticket entries — all requiring ACID guarantees.

**Survey evidence:**
- `survey.backend.data_stores` explicitly lists PostgreSQL (primary), MySQL/MariaDB (alternative), SQLite (test fallback), Alembic, oslo.db
- `survey.walkthroughs[0].data_changes` lists 5 types of data modifications in a single build flow
- `survey.walkthroughs[2].data_changes` lists 4 types of modifications in a single resize flow
- DEC-002 documents Shadow tables and versioned objects pattern

**Survey gaps (from DIAGNOSIS):**
- `migration_file_count` — full Alembic migration history may span more files (affects documentation completeness only)

### Recommendation

**Continue PostgreSQL with Alembic migrations and Shadow table soft deletes.** DEC-002 already establishes this architecture. The Shadow table pattern is critical for Nova's audit requirements — the `survey.walkthroughs[0].data_changes` explicitly mentions "Shadow instance row created for historical tracking."

### Alternatives Considered

#### Alternative 1: Switch to MySQL/MariaDB

- **Pros:** MySQL has wider deployment familiarity in some organizations; MariaDB offers some performance advantages
- **Cons:** PostgreSQL is already the primary (DEC-002); switching would require migration of existing deployments; PostgreSQL JSON support is needed for flexible metadata storage
- **Why not chosen:** DEC-002 already selected PostgreSQL as primary. The survey does not indicate a reason to change, and PostgreSQL's JSONB support is valuable for Nova's flexible instance metadata requirements.

#### Alternative 2: Move to NoSQL (Cassandra or DynamoDB)

- **Pros:** Better horizontal scaling; no schema migration required
- **Cons:** OpenStack services expect relational data with strong consistency (DEC-002); event-driven workloads (build requests, migrations) require ACID transactions; NoSQL would break compatibility with existing OpenStack tooling that expects relational schemas
- **Why not chosen:** DEC-002 already rejected NoSQL because OpenStack ecosystem requires relational data with strong consistency. The survey's data model (instances, flavors, images, migrations, resize requests, resource allocations) has clear entity relationships that map naturally to relational storage.

### Trade-offs

**What you gain:**
- ACID transaction guarantees for multi-step operations (build, migrate, resize)
- Shadow tables provide audit trails without complex SQL logic (DEC-002 rationale)
- Alembic provides versioned migrations, enabling backward-compatible schema evolution
- PostgreSQL JSONB support handles flexible instance metadata

**What you give up:**
- PostgreSQL is heavier than NoSQL alternatives for write-heavy workloads
- Schema migrations require care to avoid downtime (Mitigations: Alembic offline mode, dual-write patterns)

### Confidence

**HIGH (85-90% likelihood)**

### Confidence Rationale

- **Evidence quality:** HIGH — `survey.backend.data_stores` identifies PostgreSQL as primary with explicit reasoning. DEC-002 documents the two-layer model with Shadow tables and versioned objects. Walkthroughs demonstrate complex transactional flows requiring ACID guarantees.
- **Gap impact:** `migration_file_count` gap is documentation-only and does not affect the architecture decision.
- **Assumptions:** PostgreSQL performance is sufficient for Nova's target scale (thousands of compute hosts per cell).
- **Section citations:** `survey.backend.data_stores`, `survey.walkthroughs[0].data_changes`, `survey.walkthroughs[2].data_changes`, `DEC-002`

---

## Messaging Transport: RabbitMQ via oslo.messaging

### Analysis

The survey identifies RabbitMQ via oslo.messaging as the inter-service RPC messaging transport. DEC-010 already documents this decision. Walkthrough 1 (build) and Walkthrough 2 (live migration) both require reliable message delivery for build requests and migration coordination. The survey's `survey.backend.integrations` lists "RabbitMQ via oslo.messaging — inter-service RPC messaging."

Walkthrough 2 (live migration) specifically mentions "Conductor unreachable: build request cannot be dispatched" as an error case, demonstrating the need for message persistence and delivery guarantees. DEC-010 explicitly rejected ZeroMQ (no message persistence) and direct TCP connections (tight coupling).

**Survey evidence:**
- `survey.backend.integrations` lists RabbitMQ via oslo.messaging
- `survey.walkthroughs[2].error_cases` includes "Conductor service unavailable: resize request cannot proceed"
- DEC-010 documents the decision with ZeroMQ and TCP alternatives rejected

**Survey gaps (from DIAGNOSIS):**
- `cell_rpc_protocol_details` — exact messaging protocol between cells and conductor not fully traced (affects fault-tolerance pattern selection)

### Recommendation

**Continue RabbitMQ via oslo.messaging as the messaging transport.** DEC-010 already established this. The `cell_rpc_protocol_details` gap means the exact protocol between cells and conductor should be traced and documented in a future engineering analysis.

### Alternatives Considered

#### Alternative 1: Switch to ZeroMQ

- **Pros:** Lower latency; no broker infrastructure required
- **Cons:** No message persistence (DEC-010); lost messages during broker restart would cause data inconsistency
- **Why not chosen:** DEC-010 already rejected ZeroMQ because build requests and migration coordination require message persistence. RabbitMQ's persistent queues guarantee delivery even during broker restarts.

#### Alternative 2: Use gRPC for service-to-service communication

- **Pros:** Type-safe contracts; HTTP/2 multiplexing; cross-language support
- **Cons:** Breaks compatibility with existing OpenStack service communication; oslo.messaging is the OpenStack standard; gRPC does not provide the same queue-based messaging semantics
- **Why not chosen:** OpenStack ecosystem standardizes on oslo.messaging for RPC. Switching would break inter-service compatibility with Keystone, Glance, Neutron, Cinder, and Placement, none of which speak gRPC.

### Trade-offs

**What you gain:**
- Reliable message delivery with persistent queues (critical for build and migration operations)
- Message acknowledgment semantics (DEC-010 rationale)
- Transport abstraction via oslo.messaging allows switching to ZeroMQ or in-memory later if needed
- Standard OpenStack interoperability

**What you give up:**
- RabbitMQ deployment and operational complexity
- Type safety and IDE support that gRPC would provide

### Confidence

**HIGH (85-90% likelihood)**

### Confidence Rationale

- **Evidence quality:** HIGH — DEC-010 already established RabbitMQ with detailed rationale. `survey.backend.integrations` confirms the choice. `survey.walkthroughs[2].error_cases` demonstrates the need for message persistence.
- **Gap impact:** `cell_rpc_protocol_details` gap means the exact protocol between cells v2 is not fully documented, but this does not change the transport layer choice (RabbitMQ is used for both intra-cell and cross-cell communication).
- **Assumptions:** RabbitMQ cluster deployment follows OpenStack best practices (mirrored queues, ha-mode-all).
- **Section citations:** `survey.backend.integrations`, `survey.walkthroughs[2].error_cases`, `DEC-010`

---

## Distributed Concurrency: Eventlet Green Threads with TooZ Locks

### Analysis

The survey identifies eventlet green threads with native threading fallback as the concurrency model. DEC-006 already documents this decision. Walkthrough 2 (live migration) explicitly mentions "cursive distributed state machine coordinates the live migration state machine" and "TooZ lock groups prevent concurrent operations on the same instance."

The concurrency model must handle thousands of concurrent connections (API requests, compute operations, migration flows) while maintaining data consistency across distributed processes (nova-compute, nova-conductor, nova-scheduler). The `survey.backend.infrastructure` confirms "Eventlet green threads with native threading fallback."

**Survey evidence:**
- `survey.backend.infrastructure` lists "Eventlet green threads with native threading fallback"
- `survey.walkthroughs[1].steps` references TooZ lock groups for distributed locking
- DEC-006 documents the eventlet vs asyncio decision
- DEC-011 documents the cursive state machine for migration coordination

**Survey gaps (from DIAGNOSIS):**
- None directly affecting this area

### Recommendation

**Continue eventlet green threads with native threading fallback, TooZ distributed locks, and cursive state machine.** DEC-006 and DEC-011 already established these patterns. The survey does not indicate any issues with the current concurrency model.

### Alternatives Considered

#### Alternative 1: Migrate to asyncio

- **Pros:** Modern Python concurrency with native async/await; better performance for I/O-bound workloads; growing ecosystem support
- **Cons:** oslo.* library ecosystem is built on eventlet (DEC-006); migration would require rewriting oslo.messaging, oslo.db, oslo.middleware, and all Nova async call sites
- **Why not chosen:** DEC-006 already evaluated asyncio and rejected it because the oslo.* ecosystem is eventlet-based. A migration would be a multi-year effort across the entire OpenStack ecosystem, not just Nova.

#### Alternative 2: Replace green threads with native threads

- **Pros:** Simpler debugging; better profiler compatibility; compatible with some glibc versions
- **Cons:** More memory per concurrent connection (DEC-006); would require more compute nodes for the same load
- **Why not chosen:** The native threading fallback already exists for environments where eventlet is incompatible. The default eventlet path remains more resource-efficient for Nova's concurrent connection requirements.

### Trade-offs

**What you gain:**
- Efficient handling of thousands of concurrent connections with green threads
- Native threading fallback for edge cases (profiler incompatibility, glibc issues)
- TooZ lock groups prevent concurrent operations on the same instance across processes
- Cursive state machine formalizes live migration state transitions

**What you give up:**
- Modern asyncio patterns not available (async/await, asyncio.gather)
- Debugging green threads can be challenging (greenlet leak detection required)

### Confidence

**HIGH (85-90% likelihood)**

### Confidence Rationale

- **Evidence quality:** HIGH — DEC-006 documents the concurrency decision with full alternatives analysis. `survey.backend.infrastructure` confirms the pattern. `survey.walkthroughs[1].steps` demonstrates TooZ lock usage.
- **Gap impact:** No gaps from DIAGNOSIS affect this recommendation.
- **Assumptions:** OpenStack project maintains eventlet compatibility as the default path.
- **Section citations:** `survey.backend.infrastructure`, `survey.walkthroughs[1].steps`, `DEC-006`, `DEC-011`

---

## Pluggable Driver Architecture: Stevedore Entry Points

### Analysis

The survey identifies pluggable virtualization drivers via Stevedore entry points (libvirt, VMware, ZVM, Ironic) and pluggable scheduler filters and weights. DEC-004 (default libvirt driver) and DEC-008 (scheduler filter plugins) already document these decisions. Walkthrough 1 demonstrates virt driver usage ("Compute node spawns the VM via the virt driver (libvirt/KVM by default)").

The survey explicitly acknowledges optional driver complexity as a rubric gap. With four distinct driver families (KVM, VMware, IBM Z, bare metal via Ironic), each with different capabilities and failure modes, the pluggable architecture is essential to keep core Nova manageable.

**Survey evidence:**
- `survey.backend.infrastructure` lists "Pluggable virtualization drivers via Stevedore entry points (libvirt, VMware, ZVM, Ironic)"
- `survey.backend.infrastructure` lists "Pluggable scheduler filters and weights via Stevedore entry points"
- DEC-004 documents libvirt as default with optional drivers
- DEC-008 documents scheduler filter plugins (19 filters)

**Survey gaps (from DIAGNOSIS):**
- `optional_driver_complexity` — VMware, ZVM, and Ironic drivers have additional complexity not fully explored

### Recommendation

**Continue Stevedore-based plugin architecture for drivers, filters, and weights.** DEC-004 and DEC-008 already established this. The `optional_driver_complexity` gap suggests that the VMware, ZVM, and Ironic drivers should be documented in a future engineering analysis to ensure the core architecture remains maintainable despite the complexity of optional drivers.

### Alternatives Considered

#### Alternative 1: Embed all drivers in core Nova

- **Pros:** Simpler deployment (no entry point resolution); full visibility into all code paths
- **Cons:** Would bloat the core codebase (DEC-004); driver-specific code would need to be maintained by all operators, even those using only libvirt
- **Why not chosen:** DEC-004 already rejected this because only a fraction of Nova deployments use VMware, ZVM, or Ironic. Embedding all drivers would increase the codebase and testing burden for all operators.

#### Alternative 2: External driver microservices

- **Pros:** Complete isolation; independent deployment and scaling per driver type
- **Cons:** Adds network latency to driver calls; breaks the synchronous RPC model used for build and migration; would require redesigning the virt driver interface
- **Why not chosen:** Virt driver calls are latency-sensitive and often synchronous (e.g., during build operations). A remote driver service would add network roundtrips to every VM operation, significantly impacting performance.

### Trade-offs

**What you gain:**
- Operators can enable only the drivers and filters they need
- Core Nova codebase remains focused on libvirt/KVM functionality
- Driver-specific bugs are isolated from the core
- Scheduler filter diversity supports heterogeneous deployments

**What you give up:**
- Driver compatibility testing must be performed per-driver independently
- Cross-driver feature parity is harder to ensure
- `optional_driver_complexity` gap means some drivers are less well-understood than libvirt

### Confidence

**HIGH (85-90% likelihood)**

### Confidence Rationale

- **Evidence quality:** HIGH — DEC-004 and DEC-008 already established the Stevedore pattern with full alternatives analysis. `survey.backend.infrastructure` explicitly lists pluggable architecture. 19 scheduler filters are already documented.
- **Gap impact:** `optional_driver_complexity` gap means VMware, ZVM, and Ironic are less well-understood, but this does not change the architecture decision — the pluggable pattern is correct regardless of individual driver complexity.
- **Assumptions:** Stevedore remains actively maintained and compatible with the Python version used by Nova.
- **Section citations:** `survey.backend.infrastructure`, `DEC-004`, `DEC-008`

---

## Multi-cell Scaling: Cells v2 Architecture

### Analysis

The survey identifies multi-cell deployment support with cells v2 architecture (cell0 for metadata, cell1+ for compute hosts). DEC-005 already documents this decision. Walkthrough 1 demonstrates the full cell-aware flow: "Scheduler routes the build request to the appropriate conductor service (cell-aware)" and "Conductor dispatches the build request to the target nova-compute node via RPC."

The architecture must support thousands of compute hosts across multiple cells, each with independent database, conductor, and compute infrastructure. Cell0 serves as a metadata-only database that stores global instance records (not compute-specific data).

**Survey evidence:**
- `survey.backend.infrastructure` lists "Multi-cell deployment support (cells v2) with cell0 (metadata) and cell1+ (compute hosts)"
- `survey.walkthroughs[0].steps` demonstrates cell-aware routing: "Scheduler routes the build request to the appropriate conductor service (cell-aware)"
- DEC-005 documents the cells v2 architecture with alternatives analysis

**Survey gaps (from DIAGNOSIS):**
- `cell_rpc_protocol_details` — exact messaging protocol between cells and conductor not fully traced

### Recommendation

**Continue cells v2 architecture with cell0 metadata database and cell1+ compute isolation.** DEC-005 already established this. The `cell_rpc_protocol_details` gap means the exact RPC protocol between cells should be traced in a future engineering analysis, but the architecture decision itself is sound and well-documented.

### Alternatives Considered

#### Alternative 1: Single-database Nova deployment

- **Pros:** Simpler deployment; no cross-cell routing required; fewer moving parts
- **Cons:** Database connection pool and lock contention limits scalability to a few thousand hosts (DEC-005); single point of failure for the conductor
- **Why not chosen:** DEC-005 already rejected single-database because Nova targets thousands of compute hosts. The cells v2 architecture is essential for cloud-scale deployments.

#### Alternative 2: Fully distributed peer-to-peer compute

- **Pros:** No central coordination required
- **Cons:** No centralized resource tracking or scheduling coordination (DEC-005); would require redesigning Placement integration
- **Why not chosen:** DEC-005 already rejected peer-to-peer because Nova requires centralized resource tracking via Placement and coordinated scheduling. Without a conductor/routing layer, there is no way to track allocations across compute hosts.

### Trade-offs

**What you gain:**
- Each cell scales independently with its own compute, conductor, and database
- Cell isolation limits blast radius of failures
- Horizontal scaling to tens of thousands of compute hosts
- Cell0 metadata database decouples global instance state from compute operations

**What you give up:**
- Operational complexity of managing multiple cells
- Cross-cell operations (e.g., live migration between cells) require additional coordination
- `cell_rpc_protocol_details` gap means the exact inter-cell protocol is not fully documented

### Confidence

**MEDIUM (65-75% likelihood)**

### Confidence Rationale

- **Evidence quality:** HIGH — DEC-005 documents the cells v2 architecture with full alternatives. `survey.backend.infrastructure` confirms multi-cell support. `survey.walkthroughs[0].steps` demonstrates cell-aware flow.
- **Gap impact:** `cell_rpc_protocol_details` gap affects confidence because the exact messaging protocol between cells and conductor is not fully traced. This gap means we cannot precisely evaluate fault-tolerance patterns for cross-cell operations (e.g., what happens if the cell0 database is unreachable during a cross-cell migration).
- **Assumptions:** Cell RPC uses oslo.messaging with RabbitMQ (same transport as intra-cell communication). Cell0 database is PostgreSQL.
- **Section citations:** `survey.backend.infrastructure`, `survey.walkthroughs[0].steps`, `DEC-005`

---

## Privilege Separation: oslo.privsep and oslo-rootwrap

### Analysis

The survey identifies privilege separation via oslo.privsep with privilege separation helpers in `nova/privsep/`. DEC-009 already documents this decision. The security model requires that nova-compute runs as root (necessary for hypervisor operations) but should not trust input from the API layer. oslo.privsep compartmentalizes privileged operations, and oslo-rootwrap whitelists allowed host commands.

Security model is one of the 12 covered rubric items, and the survey's security-related gap areas (metadata_service_detail, optional_driver_complexity) do not directly affect the privilege separation architecture.

**Survey evidence:**
- DEC-009 documents the privilege separation architecture with alternatives
- `survey.project.problem` references "fine-grained RBAC"
- Walkthroughs demonstrate the need for privilege separation (build requests flow from API through multiple layers to compute)

**Survey gaps (from DIAGNOSIS):**
- None directly affecting this area

### Recommendation

**Continue oslo.privsep with oslo-rootwrap for privilege separation.** DEC-009 already established this architecture. The security model is well-covered by the rubric and no gaps affect this recommendation.

### Alternatives Considered

#### Alternative 1: Run nova-compute as unprivileged user

- **Pros:** Reduced attack surface
- **Cons:** Many hypervisor operations require root (DEC-009)
- **Why not chosen:** DEC-009 already rejected this because KVM, network bridging, and block device attachment require root privileges. Running unprivileged would disable most functionality.

#### Alternative 2: Use sudo-based privilege escalation

- **Pros:** Simple to implement; well-understood
- **Cons:** oslo.privsep is more secure (compartmentalized privilege, no shared credentials) and more efficient (DEC-009)
- **Why not chosen:** DEC-009 already rejected sudo because oslo.privsep provides compartmentalized privilege execution in separate processes, eliminating the risk of credential sharing.

### Trade-offs

**What you gain:**
- Compartmentalized privilege execution prevents API compromise from leading to host compromise
- Rootwrap provides explicit command whitelisting
- Separate privilege separation process limits blast radius

**What you give up:**
- Additional complexity in maintaining privilege separation helpers
- Developers must explicitly mark privileged functions with decorators

### Confidence

**HIGH (85-90% likelihood)**

### Confidence Rationale

- **Evidence quality:** HIGH — DEC-009 documents the decision with full alternatives analysis. Security model is explicitly covered by the rubric.
- **Gap impact:** No gaps from DIAGNOSIS affect this recommendation.
- **Assumptions:** oslo.privsep and oslo-rootwrap remain the security standard for OpenStack.
- **Section citations:** `DEC-009`, `rubric_coverage.covered` (security_model)

---

## Configuration Management: oslo.config Modular Approach

### Analysis

The survey identifies modular configuration options in `nova/conf/` (48 config modules) aggregated via oslo.config entry point. DEC-012 already documents this decision. The 48 config modules correspond to Nova's subsystem architecture, each with OPT objects containing section names, types, help text, and default values.

The `survey.backend.infrastructure` lists "Ansible roles and playbooks for deployment" and "DevStack for single-node deployment and testing," indicating that configuration management must support both Ansible-driven deployments and DevStack-based development/testing.

**Survey evidence:**
- DEC-012 documents the modular config approach with alternatives
- `survey.backend.infrastructure` lists Ansible and DevStack deployment tools
- `project.problem` references configuration management as a rubric coverage item (covered)

**Survey gaps (from DIAGNOSIS):**
- None directly affecting this area

### Recommendation

**Continue oslo.config with modular config modules.** DEC-012 already established this. The 48 config modules mirror Nova's subsystem architecture and enable per-subsystem documentation, validation, and generation of sample configuration files.

### Alternatives Considered

#### Alternative 1: Single monolithic config file

- **Pros:** Simpler to navigate for simple deployments
- **Cons:** With 48+ subsystems, a single config file would be unwieldy (DEC-012)
- **Why not chosen:** DEC-012 already rejected this because modular approach enables per-subsystem documentation and validation.

#### Alternative 2: YAML/JSON config format

- **Pros:** More readable than INI-style config
- **Cons:** oslo.config supports existing OpenStack deployment tooling (DEC-012); YAML/JSON would break compatibility with oslo-config-generator, Devstack, and Ansible
- **Why not chosen:** DEC-012 already rejected YAML/JSON because the oslo.* ecosystem standardizes on oslo.config INI-style configuration.

### Trade-offs

**What you gain:**
- Per-subsystem configuration modules (48 total) with documentation
- Unified CLI interface via oslo.config
- Runtime config reloading support
- Compatibility with oslo-config-generator, DevStack, and Ansible

**What you give up:**
- INI-style config is less readable than YAML/JSON for complex nested configurations
- No built-in config validation beyond oslo.config's own mechanisms

### Confidence

**HIGH (85-90% likelihood)**

### Confidence Rationale

- **Evidence quality:** HIGH — DEC-012 documents the modular config approach with full alternatives. `survey.backend.infrastructure` confirms deployment tools. Configuration management is explicitly covered by the rubric.
- **Gap impact:** No gaps from DIAGNOSIS affect this recommendation.
- **Assumptions:** oslo.config remains maintained and compatible with the Python version used by Nova.
- **Section citations:** `DEC-012`, `survey.backend.infrastructure`, `rubric_coverage.covered` (configuration_management)

---

## Testing Strategy: Zuul CI/CD with DevStack

### Analysis

The survey identifies Zuul CI/CD pipeline for integration testing and DevStack for single-node deployment and testing in `survey.backend.infrastructure`. This is the first major recommendation area where the rubric explicitly identifies a gap — the survey does not capture comprehensive testing strategy details beyond CI/CD pipeline tools.

The test strategy must cover: unit tests for individual functions and classes, functional tests for multi-service workflows, integration tests across Nova components, and system tests via DevStack deployments.

**Survey evidence:**
- `survey.backend.infrastructure` lists "Zuul CI/CD pipeline for integration testing" and "DevStack for single-node deployment and testing"
- AGENTS.md notes "Tests: Use tox or stestr; never use pytest"
- Walkthroughs define expected behaviors that tests should validate (build, migrate, resize, list, console)
- Error cases in walkthroughs define failure scenarios that tests should cover

**Survey gaps (from DIAGNOSIS):**
- Testing strategy is the primary gap in survey coverage — no test design patterns, test coverage targets, or test data management approaches captured

### Recommendation

**Continue Zuul CI/CD with tox/stestr as the test execution framework, augmented with DevStack system tests.** The survey gap indicates that a formal testing strategy document should be produced as a follow-up engineering artifact. Key test layers:

1. **Unit tests:** Individual function/class tests for nova/ code paths, using stestr with greenlet leak detection (per AGENTS.md)
2. **Functional tests:** Multi-service workflow tests using mock services for Keystone, Glance, Neutron, Cinder, and Placement
3. **Integration tests:** End-to-end tests via Zuul with DevStack deployments
4. **Performance tests:** Baseline benchmarks for API latency, build throughput, and migration speed (currently missing — `performance_characteristics` gap)

### Alternatives Considered

#### Alternative 1: Add full system-level test matrix for every Nova version

- **Pros:** Maximum test coverage
- **Cons:** Massive CI resource requirements; long test execution times; diminishing returns after a certain coverage threshold
- **Why not chosen:** Zuul CI/CD is designed for OpenStack's scale. The existing pipeline already runs comprehensive integration tests. Additional layers would add CI cost without proportional value.

#### Alternative 2: Replace stestr with pytest

- **Pros:** pytest has larger ecosystem and plugin support
- **Cons:** AGENTS.md explicitly states "never use pytest"; tox/stestr is the Nova standard; stestr has greenlet leak detection which pytest lacks
- **Why not chosen:** The Nova project has standardised on stestr. pytest adoption would require changes to the entire test infrastructure and would lose greenlet leak detection.

### Trade-offs

**What you gain:**
- Multi-layered testing strategy covering unit, functional, integration, and system tests
- Greenlet leak detection prevents resource exhaustion in CI
- DevStack provides realistic deployment testing
- Zuul enables gated testing before merge

**What you give up:**
- No performance benchmarking framework documented (gap)
- No explicit test coverage targets (gap)
- No test data management strategy (gap)

### Confidence

**MEDIUM (60-75% likelihood)**

### Confidence Rationale

- **Evidence quality:** MEDIUM — `survey.backend.infrastructure` mentions Zuul and DevStack but does not capture test design patterns, coverage targets, or test data management. The gap is significant because testing strategy is a cross-cutting concern not covered by any single walkthrough.
- **Gap impact:** Testing strategy is identified as a rubric gap. The recommendation is based on standard OpenStack patterns and the tools mentioned in the survey, but specific test architecture decisions (e.g., test fixtures, mock strategies, performance benchmarking) require further surveying.
- **Assumptions:** Standard OpenStack testing patterns (mock services, devstack gate) apply. stestr greenlet leak detection remains functional.
- **Section citations:** `survey.backend.infrastructure`, AGENTS.md, `rubric_coverage.gaps` (testing strategy)

---

## Observability and Monitoring: nova-status and Service Health

### Analysis

The survey identifies `nova-status` as the service health monitoring tool used by Cloud Administrators. The Cloud Administrator actor's capabilities include "Monitor service health via nova-status." However, no comprehensive monitoring strategy is captured in the survey. No specific metrics, alerting, or dashboard requirements are documented.

The distributed multi-process architecture (nova-compute, nova-conductor, nova-scheduler) and cells v2 topology create visibility requirements: operators need to know the health of each daemon, each cell, and each compute host.

**Survey evidence:**
- Cloud Administrator capability: "Monitor service health via nova-status"
- `survey.project.problem` references "scalable" deployment
- Multi-process architecture and cells v2 create inherent observability requirements

**Survey gaps (from DIAGNOSIS):**
- `performance_characteristics` gap — no benchmark data or performance profiles (affects monitoring baseline)
- Monitoring observability not covered by rubric (not in covered or gaps list)

### Recommendation

**Continue nova-status for service health reporting, supplemented by OpenStack Monitoring Service (oslo-middleware) metrics and Prometheus metrics exposure.** The survey gap indicates that a formal observability architecture should be defined as a follow-up engineering artifact.

Key observability layers:
1. **nova-status:** Service health commands (already present)
2. **oslo-middleware:** HTTP request metrics, latency, error rates
3. **Prometheus metrics:** Resource utilization, queue depths, RPC latency
4. **Logging:** structured logging with correlation IDs for cross-service tracing

### Alternatives Considered

#### Alternative 1: Adopt a full observability platform (Datadog, Dynatrace)

- **Pros:** Enterprise-grade monitoring with dashboards, alerting, and APM
- **Cons:** Additional cost and operational complexity; OpenStack deployments typically use Prometheus/Grafana; survey does not specify enterprise monitoring requirements
- **Why not chosen:** Survey does not capture enterprise monitoring requirements. Standard OpenStack practice is Prometheus/Grafana, which is sufficient for most deployments.

#### Alternative 2: Build custom monitoring within Nova

- **Pros:** Tight integration with Nova internals
- **Cons:** Monitoring is a cross-cutting concern; custom monitoring adds maintenance burden to Nova
- **Why not chosen:** Monitoring should be external to Nova. Prometheus exporters and oslo-middleware provide sufficient metrics without custom code.

### Trade-offs

**What you gain:**
- nova-status provides service health commands (already present)
- oslo-middleware provides HTTP metrics without code changes
- Prometheus integration enables custom metrics (queue depths, RPC latency)
- Structured logging with correlation IDs enables cross-service tracing

**What you give up:**
- No enterprise APM integration documented
- No alerting rules defined (gap)
- No dashboard requirements captured (gap)

### Confidence

**MEDIUM (60-75% likelihood)**

### Confidence Rationale

- **Evidence quality:** MEDIUM — Only `nova-status` is explicitly mentioned as a monitoring tool. No metrics framework, alerting strategy, or dashboard requirements are captured. The recommendation extends standard OpenStack monitoring patterns but specific design decisions require further surveying.
- **Gap impact:** `performance_characteristics` gap means we cannot determine what performance baselines monitoring should track. The rubric does not cover monitoring/observability.
- **Assumptions:** OpenStack Monitoring Service (oslo-middleware) and Prometheus are the standard monitoring stack.
- **Section citations:** `survey.actors[0].capabilities` (Cloud Administrator monitoring), `rubric_coverage` (monitoring not covered)

---

## Complexity Assessment

**Extracted Constraints:**
- **Team Size:** Large (OpenStack is a multi-contributor project with thousands of contributors; AGENTS.md references Gerrit review workflow)
- **Budget:** Not specified (OpenStack is open-source; infrastructure provided by cloud operators)
- **Timeline:** Not specified (ongoing maintenance and feature development)
- **Experience:** High (large-scale distributed systems expertise required)

**Complexity Ceiling:** STANDARD

No recommendations flagged for review. All recommendations are appropriate for a large-scale distributed compute service.

---

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
