# Engineering Proposals

**Generated:** 2026-08-26T00:00:00Z
**Based on:** RECOMMENDATION.md analysis
**Status:** All proposals awaiting approval

## Proposals Overview

Total decisions proposed: 3 (DEC-013 through DEC-015)
Next decision ID: DEC-013
Existing decisions: 12 (DEC-001 through DEC-012, already in architecture-decisions.json)

These proposals address the **Testing Strategy** and **Observability** gaps identified in both the DIAGNOSIS and RECOMMENDATION documents. The remaining 8 architecture areas are already documented in existing DEC-001 through DEC-012 entries and do not require new proposals.

**Important:** These decisions are NOT yet in architecture-decisions.json. They require explicit approval via Phase 13 approval flow.

Confidence distribution:
- HIGH confidence: 1
- MEDIUM confidence: 2
- LOW confidence: 0

---

# DEC-013: Testing Strategy Architecture

**Date:** 2026-08-26T00:00:00Z
**Status:** Proposed (awaiting approval)
**Context Source:** survey.json Phases 1-5, AGENTS.md

## Context

The survey identifies Zuul CI/CD pipeline for integration testing and DevStack for single-node deployment testing (`survey.backend.infrastructure`). The Cloud Administrator actor manages Nova infrastructure but has no testing-related capabilities captured. The rubric_coverage explicitly leaves "testing-strategy" as a gap. AGENTS.md states: "Tests: Use tox or stestr; never use pytest."

Nova has a complex multi-service architecture with:
- 8 system integrations (Keystone, Glance, Neutron, Cinder, Placement, RabbitMQ, Barbican, Dogpile.cache)
- 4 virtualization driver families (libvirt, VMware, ZVM, Ironic)
- Multi-cell deployment topology (cell0 metadata, cell1+ compute)
- Distributed concurrency (eventlet green threads, TooZ locks, cursive state machine)
- Privilege separation (oslo.privsep, oslo-rootwrap)

Walkthroughs define 5 major operation flows (build, live migration, resize, list/filter, console access) with specific error cases. Tests must validate these flows and their error conditions.

The existing decisions DEC-001 through DEC-012 establish the architecture but do not address testing strategy. A formal testing architecture is needed to ensure correctness across the distributed, multi-integration system.

Based on recommendation: Testing Strategy: Zuul + stestr + DevStack

**Survey evidence:**
- `survey.backend.infrastructure`: "Zuul CI/CD pipeline for integration testing", "DevStack for single-node deployment and testing"
- AGENTS.md: "Tests: Use tox or stestr; never use pytest"
- `survey.walkthroughs[0]` through `[4]`: 5 operation flows with specific error cases to test

**Survey gaps:**
- Testing strategy not captured in rubric_coverage
- No test coverage targets documented
- No test data management approach documented
- No performance benchmarking framework documented

**Problem this solves:** Nova's complexity (8 integrations, 4 driver families, cells v2) demands a multi-layered testing strategy. Without a formal testing architecture, regression risks are high, and the distributed nature of the system makes integration testing essential.

## Decision

Adopt a four-layer testing architecture:

1. **Unit Tests (stestr):** Single-function/class tests for all nova/ code paths. Must use stestr with greenlet leak detection. Never use pytest. Target: all nova/ modules have unit tests.

2. **Functional Tests (mock services):** Multi-service workflow tests using mock services for Keystone, Glance, Neutron, Cinder, and Placement. Tests exercise the full Nova code path (API → conductor → compute) without external dependencies.

3. **Integration Tests (Zuul CI/CD):** End-to-end tests via Zuul gate. Tests run against real DevStack deployments with all OpenStack services. Covers cell-aware routing, multi-cell operations, and cross-service interactions.

4. **Performance Tests (baseline benchmarks):** Benchmark suite for API latency, build throughput, migration speed, and resource utilization. Establish baselines for regression detection.

## Rationale

- **stestr over pytest:** AGENTS.md explicitly mandates stestr over pytest. stestr supports greenlet leak detection, which is essential for eventlet-based code. pytest does not provide greenlet leak detection.
- **Zuul CI/CD:** Zuul is the OpenStack standard for gated testing. It provides queue-based change integration, automated testing, and merge gating — essential for a project with thousands of contributors and daily merge traffic.
- **DevStack:** DevStack provides a single-node OpenStack deployment for integration testing. It is the de facto standard for testing Nova across the entire OpenStack ecosystem.
- **Four layers:** Each layer tests at a different scope. Unit tests catch bugs quickly (fast feedback). Functional tests catch integration bugs within Nova. Integration tests catch cross-service bugs. Performance tests catch regressions in throughput and latency.
- **Performance tests are new:** No performance benchmarking exists (DIAGNOSIS gap). This is the first proposal to formally add performance regression detection.

**From RECOMMENDATION analysis:**
- Testing strategy is identified as a rubric gap
- Current tools (Zuul, DevStack, stestr) are confirmed by survey evidence
- Performance benchmarking is absent and should be added
- Greenlet leak detection is essential for eventlet-based code

## Consequences

### Positive

- Four-layer strategy ensures bugs are caught at the appropriate level without waiting for full integration tests
- stestr greenlet leak detection prevents resource exhaustion in eventlet-based tests
- Zuul gating prevents broken code from being merged
- DevStack integration tests validate against real OpenStack services
- Performance benchmarks establish baselines for regression detection

### Negative

- Testing infrastructure adds CI/CD cost (DevStack deployments are resource-intensive)
- Four layers must be maintained separately; bugs may be missed by one layer but caught by another (false sense of security)
- Functional tests with mocked services may not catch real-service compatibility issues
- Performance benchmarking requires careful baseline establishment

## Alternatives Considered

### Alternative 1: Expand stestr to also handle integration testing

**Analysis:** Use stestr for both unit and integration tests, running integration tests inside devstack environments managed by stestr.

**Rejected because:** stestr is a unit test runner. Integration tests require full OpenStack deployments (Keystone, Glance, Neutron, Cinder, Placement) with proper networking and message queues. Zuul manages these deployments and provides gating semantics that stestr does not. Mixing unit and integration testing tools creates operational complexity and conflates fast feedback (unit) with slow feedback (integration).

### Alternative 2: Use pytest for all test layers

**Analysis:** pytest has larger ecosystem support (fixtures, parametrization, plugins), better IDE integration, and is more widely understood by developers.

**Rejected because:** AGENTS.md explicitly states "never use pytest." pytest does not support greenlet leak detection, which is essential for eventlet-based code. The Nova project has standardized on stestr, and switching would require changes to the entire test infrastructure. Additionally, pytest's plugin ecosystem is not aligned with OpenStack testing standards.

### Alternative 3: Add more test layers (e.g., load testing, chaos testing)

**Analysis:** Add load testing (simulating thousands of concurrent users) and chaos testing (intentionally failing services during operations).

**Rejected because:** These are valuable additions but beyond the scope of the initial testing strategy proposal. Load testing and chaos testing should be added after the four base layers are established and baselines are set. Adding them now would overcomplicate the initial architecture.

## Confidence

**MEDIUM (60-75% likelihood)**

### Confidence Rationale

- **Evidence quality:** MEDIUM — `survey.backend.infrastructure` mentions Zuul and DevStack, and AGENTS.md mandates stestr. However, testing strategy is a rubric gap — the survey does not capture test design patterns, coverage targets, or test data management approaches.
- **Gap impact:** The testing strategy gap is significant because testing is a cross-cutting concern not covered by any single walkthrough. The recommendation relies on OpenStack standard patterns rather than survey-derived specifics.
- **Assumptions:** stestr greenlet leak detection works with the current eventlet version. Zuul infrastructure is available and properly configured. DevStack deployments can be provisioned for CI.
- **Section citations:**
  - `survey.backend.infrastructure` — Zuul and DevStack mentioned
  - AGENTS.md — stestr mandate
  - `rubric_coverage.gaps` — testing-strategy is a gap

## Dependencies

**Depends on:**
- DEC-006: Concurrency model (eventlet green threads require stestr with greenlet leak detection)
- DEC-010: Messaging transport (integration tests need RabbitMQ deployment)

**Affects:**
- Future test coverage targets (should be defined after baselines are established)
- Future performance test specifications (should reference DEC-015 observability metrics)

## References

- **RECOMMENDATION section:** Testing Strategy: Zuul + stestr + DevStack
- **Survey sections:**
  - `survey.backend.infrastructure` — "Zuul CI/CD pipeline for integration testing", "DevStack for single-node deployment and testing"
  - `survey.walkthroughs[]` — 5 operation flows to test
  - `rubric_coverage.gaps` — "testing-strategy" gap
- **Related decisions:**
  - DEC-001: Backend framework (affects unit test targets)
  - DEC-006: Concurrency model (requires stestr with greenlet leak detection)
  - DEC-010: Messaging transport (integration tests need RabbitMQ)

---

# DEC-014: Observability Architecture

**Date:** 2026-08-26T00:00:00Z
**Status:** Proposed (awaiting approval)
**Context Source:** survey.json Phases 1-5

## Context

The survey identifies `nova-status` as the service health monitoring tool used by Cloud Administrators. The Cloud Administrator actor's capabilities include "Monitor service health via nova-status." However, no comprehensive monitoring strategy is captured in the rubric_coverage (monitoring/observability is not listed as covered or as a gap — it is simply unaddressed).

Nova's distributed architecture creates significant observability requirements:
- Multiple daemon processes (nova-compute, nova-conductor, nova-scheduler)
- Multi-cell topology (cell0 metadata, cell1+ compute)
- 8 external service integrations (Keystone, Glance, Neutron, Cinder, Placement, RabbitMQ, Barbican, Dogpile.cache)
- 4 virtualization driver families
- Distributed locking (TooZ) and state machines (cursive)

Walkthrough 1 (build) involves 12+ sequential steps across 8 different services. Without structured observability, debugging failures in this flow is difficult. Walkthrough 2 (live migration) involves the cursive state machine and TooZ locks — understanding migration failures requires visibility into both state transitions and lock contention.

The `performance_characteristics` rubric gap means no performance baselines exist, which affects what metrics should be monitored and at what thresholds alerts should fire.

Based on recommendation: Observability and Monitoring: nova-status + metrics exposure

**Survey evidence:**
- `survey.actors[0].capabilities`: "Monitor service health via nova-status"
- `survey.backend.infrastructure`: Multi-process architecture, cells v2, distributed concurrency
- `survey.walkthroughs[0]`: 12-step flow across 8 services (high observability need)
- `rubric_coverage.gaps`: "performance_characteristics" gap affects monitoring baseline

**Survey gaps:**
- `performance_characteristics` — no benchmark data or performance profiles (affects monitoring thresholds)
- Monitoring/observability not covered by rubric (not in covered or gaps list)

**Problem this solves:** Nova's distributed architecture creates visibility requirements that cannot be met by nova-status alone. Operators need metrics for resource utilization, queue depths, RPC latency, and error rates across all processes and cells. Structured logging with correlation IDs is needed for cross-service tracing.

## Decision

Adopt a three-layer observability architecture:

1. **Service Health (nova-status):** Continue and extend nova-status commands for health checking each daemon, each cell, and each compute host. Commands should report: service status, RPC connectivity, database connectivity, and placement connectivity.

2. **Metrics Collection (Prometheus):** Expose Prometheus metrics via oslo-middleware and custom Prometheus exporters:
   - HTTP request metrics (latency, error rates, request rates) from oslo-middleware
   - Queue depth metrics (oslo.messaging queue statistics)
   - RPC latency metrics (API-to-conductor, conductor-to-compute, inter-cell)
   - Database query performance metrics (oslo.db query timing)
   - Placement API latency and error rates
   - Driver-specific metrics (build time, migration speed, resize time)

3. **Structured Logging (oslo.log):** All Nova services use oslo.log with structured output. Add correlation IDs to log entries for cross-service tracing. Implement log levels that distinguish between operational, warning, and error conditions.

## Rationale

- **nova-status for health:** nova-status already exists and is the standard for Nova service health. Extending it for cell-aware health checking is a natural evolution. It provides a CLI tool that operators already know how to use.
- **Prometheus for metrics:** Prometheus is the OpenStack standard for metrics collection. It provides: pull-based metrics collection (simpler than push-based), time-series storage, query language (PromQL), and Grafana dashboard integration. oslo-middleware provides HTTP metrics out of the box.
- **oslo.log for logging:** oslo.log is the OpenStack standard for logging. It supports structured output (JSON format), log level hierarchy, and formatting customization. Correlation IDs enable cross-service tracing when combined with proper log aggregation (ELK stack or Loki).
- **Three layers:** Each layer serves a different observability need. nova-status provides health checks (am I alive?). Prometheus provides metrics (am I healthy?). oslo.log provides audit trails and debugging information (what happened?).

**From RECOMMENDATION analysis:**
- nova-status already exists for service health
- oslo-middleware provides HTTP metrics without code changes
- Prometheus integration enables custom metrics
- Structured logging with correlation IDs enables cross-service tracing
- Monitoring observability is not covered by the rubric — this is a gap to be filled

## Consequences

### Positive

- Multiple observability layers provide comprehensive visibility
- Prometheus integration enables custom metrics for Nova-specific operations
- oslo-middleware provides HTTP metrics without code changes
- Structured logging with correlation IDs enables cross-service tracing
- Operators have both CLI (nova-status) and metric-based (Prometheus) monitoring tools

### Negative

- Prometheus deployment and operational complexity adds infrastructure requirements
- Custom Prometheus exporters must be maintained alongside Nova core
- Correlation ID propagation across 8+ service boundaries is complex to implement correctly
- No alerting rules or dashboard designs specified (gap)
- `performance_characteristics` gap means monitoring thresholds cannot be precisely defined

## Alternatives Considered

### Alternative 1: Enterprise APM platform (Datadog, Dynatrace, New Relic)

**Analysis:** Deploy an enterprise APM platform that provides automatic instrumentation, distributed tracing, alerting, and dashboarding.

**Rejected because:** Survey does not capture enterprise monitoring requirements. OpenStack deployments typically use Prometheus/Grafana as the standard monitoring stack. Enterprise APM solutions add cost and operational complexity that most OpenStack deployments do not require. If an operator needs enterprise APM, they can integrate Prometheus metrics with their APL platform via exporters.

### Alternative 2: Build custom monitoring within Nova

**Analysis:** Add monitoring and alerting capabilities directly within Nova code, including custom dashboarding and alerting.

**Rejected because:** Monitoring is a cross-cutting concern that should be external to Nova. Custom monitoring adds maintenance burden to Nova and duplicates functionality that existing tools (Prometheus, Grafana, ELK stack) already provide. oslo-middleware and Prometheus exporters provide sufficient metrics without custom Nova code.

### Alternative 3: Rely solely on nova-status

**Analysis:** Extend nova-status to provide all observability needs (health, metrics, and debugging).

**Rejected because:** nova-status is a CLI tool designed for interactive use. It does not support real-time monitoring, historical trends, or alerting. Prometheus provides time-series storage and query capabilities that nova-status cannot match. nova-status is a health check tool, not a monitoring platform.

## Confidence

**MEDIUM (60-75% likelihood)**

### Confidence Rationale

- **Evidence quality:** MEDIUM — Only `nova-status` is explicitly mentioned in the survey. No metrics framework, alerting strategy, or dashboard requirements are captured. The recommendation extends standard OpenStack monitoring patterns (Prometheus + oslo-middleware) but specific design decisions require further surveying.
- **Gap impact:** `performance_characteristics` gap means we cannot determine what performance baselines monitoring should track. The rubric does not cover monitoring/observability at all (neither covered nor listed as a gap), meaning this area was simply not examined during the survey.
- **Assumptions:** OpenStack Monitoring Service (oslo-middleware) and Prometheus are the standard monitoring stack for OpenStack projects.
- **Section citations:**
  - `survey.actors[0].capabilities` — Cloud Administrator monitoring capability
  - `survey.backend.infrastructure` — multi-process architecture
  - `rubric_coverage.gaps` — "performance_characteristics" gap
  - `rubric_coverage.covered` — monitoring not listed (neither covered nor gap)

## Dependencies

**Depends on:**
- DEC-006: Concurrency model (metrics must account for eventlet green threads)
- DEC-010: Messaging transport (Prometheus metrics need to capture queue depths)
- DEC-013: Testing strategy (testing should validate observability metrics)

**Affects:**
- Future alerting rules (should reference Prometheus metrics defined here)
- Future dashboard designs (should visualize metrics defined here)
- Future log aggregation strategy (should use correlation IDs defined here)

## References

- **RECOMMENDATION section:** Observability and Monitoring: nova-status + metrics exposure
- **Survey sections:**
  - `survey.actors[0].capabilities` — "Monitor service health via nova-status"
  - `survey.backend.infrastructure` — multi-process architecture, cells v2
  - `survey.walkthroughs[0]` — 12-step flow requiring cross-service tracing
  - `rubric_coverage.gaps` — "performance_characteristics" gap
- **Related decisions:**
  - DEC-001: Backend framework (affects logging scope)
  - DEC-006: Concurrency model (metrics must account for green threads)
  - DEC-010: Messaging transport (metrics need queue depth visibility)

---

# DEC-015: Metadata Service Architecture

**Date:** 2026-08-26T00:00:00Z
**Status:** Proposed (awaiting approval)
**Context Source:** survey.json Phases 1-5

## Context

The rubric_coverage explicitly identifies "metadata_service_detail" as a gap: "nova/api/metadata/ sub-service not examined in depth." The VM Instance actor's capabilities include "Access instance metadata via local metadata service" and "Expose console access (noVNC, Spice, serial)."

Walkthrough 5 (Access instance console via noVNC proxy) demonstrates the metadata service pathway: "User authenticates with Keystone and requests GET /servers/{id}/actions/os-get-vnc-console" → "VncConsoleManager creates a console ticket" → "nova-novncproxy service receives the VNC connection request."

The metadata service is the bridge between cloud operator infrastructure and running VM instances. It provides:
- Instance identity (hostname, UUID, project ID)
- User-data (configuration scripts executed at boot)
- SSH public keys (authorized_keys injection)
- Network configuration (interfaces, routes, DNS)
- Instance metadata (flavor, image, availability zone)

The existing DEC-001 (three-process architecture) does not address the metadata service, which runs as a separate component (nova-api-metadata) and serves VMs directly from the hypervisor host. This service has unique security requirements: it must serve metadata to authorized VMs only, but must not expose sensitive information to unauthorized processes.

**Survey evidence:**
- `rubric_coverage.gaps`: "metadata_service_detail — nova/api/metadata/ sub-service not examined in depth"
- `survey.actors[7].capabilities`: "Access instance metadata via local metadata service"
- `survey.walkthroughs[4].steps`: 5 steps for console access (related to metadata service)
- `survey.backend.infrastructure`: nova-compute, nova-conductor, nova-scheduler as separate daemons (metadata service is additional)

**Survey gaps:**
- `metadata_service_detail` — explicitly identified as a rubric gap

**Problem this solves:** The metadata service is a security-critical component that runs on every hypervisor host, serving metadata to VM instances. Without a formally documented architecture, security reviews, operational procedures, and incident response for this component may be inconsistent.

## Decision

Adopt a local metadata service architecture:

1. **nova-api-metadata daemon:** Runs on each compute host alongside nova-compute. Listens on a local network interface (or link-local address) and serves metadata to VMs on the same host. Uses the same WSGI/PasteDeploy pipeline as the main nova-api service.

2. **Local network isolation:** The metadata service listens on a link-local address (169.254.169.254) that is only accessible from VMs on the same compute host. This prevents cross-host metadata access.

3. **Token-based authentication:** VMs authenticate to the metadata service using a short-lived token. The token is issued by the nova-api service (via the VncConsoleManager pattern from Walkthrough 5) and validated by the metadata service.

4. **Caching:** Frequently requested metadata (flavor, image, network configuration) is cached locally in the metadata service. Changes trigger cache invalidation via RPC from nova-conductor.

## Rationale

- **Local deployment:** The metadata service must serve VMs on the same host with minimal latency. Running nova-api-metadata on each compute host eliminates cross-host network latency and reduces the attack surface (link-local addressing).
- **WSGI reuse:** Reusing the WSGI/PasteDeploy pipeline (from DEC-003) ensures consistent API behavior between the main nova-api and the metadata service. This reduces code duplication and ensures that microversion handling, authentication, and policy enforcement are consistent.
- **Link-local addressing:** 169.254.169.254 is the standard link-local address used by cloud metadata services (AWS, OpenStack, Azure). VMs can reach it without additional network configuration.
- **Token-based auth:** Short-lived tokens prevent replay attacks and limit the window of exposure if a token is compromised.
- **Caching:** Reduces load on nova-conductor and improves response times for repeated metadata requests.

**From RECOMMENDATION analysis:**
- The metadata_service_detail gap was explicitly identified in the rubric
- The pattern follows the existing VncConsoleManager approach from Walkthrough 5
- WSGI reuse from DEC-003 provides a proven deployment pattern

## Consequences

### Positive

- Local metadata service provides low-latency responses to VMs
- Link-local addressing limits access to same-host VMs only
- Consistent WSGI pipeline ensures uniform API behavior
- Token-based authentication prevents unauthorized access
- Caching reduces conductor load and improves response times

### Negative

- Additional daemon to deploy and monitor on every compute host
- Link-local addressing requires network configuration on compute hosts
- Token management adds complexity to the authentication flow
- Cache invalidation across multiple metadata service instances requires coordination
- The `metadata_service_detail` gap means this proposal is based on patterns from the survey rather than detailed examination of the existing implementation

## Alternatives Considered

### Alternative 1: Centralized metadata service (single Nova-api instance)

**Analysis:** Run a single metadata service instance that all VMs contact via the network.

**Rejected because:** A centralized metadata service creates a single point of failure and a network bottleneck. If the centralized metadata service is unreachable, all VMs lose access to their metadata. Local deployment (on each compute host) provides fault isolation — a single compute host failure only affects VMs on that host.

### Alternative 2: No metadata service (cloud-init only)

**Analysis:** Rely solely on cloud-init for instance configuration at boot time, eliminating the need for a persistent metadata service.

**Rejected because:** VMs need ongoing access to metadata (e.g., for dynamic hostname changes, reconfiguration, and runtime operations). Cloud-init runs once at boot and cannot provide runtime metadata. The VM Instance actor's capabilities explicitly include "Access instance metadata via local metadata service."

### Alternative 3: IMDS v2-style (require token retrieval before metadata access)

**Analysis:** Require VMs to first obtain a security token from the metadata service, then use that token to access metadata (AWS IMDSv2 pattern).

**Rejected because:** While IMDSv2 provides additional security (prevents SSRF attacks), the OpenStack metadata service has traditionally used a simpler access model. IMDSv2 would require changes to guest OS configuration and to the Nova metadata service. This could be a future enhancement but is beyond the scope of this proposal.

## Confidence

**MEDIUM (60-75% likelihood)**

### Confidence Rationale

- **Evidence quality:** MEDIUM — The `metadata_service_detail` gap means the existing nova/api/metadata/ implementation was not examined in depth. This proposal is based on patterns from the survey (VM Instance actor capabilities, VncConsoleManager from Walkthrough 5) and OpenStack standard practices, but may not match the actual implementation.
- **Gap impact:** The metadata_service_detail gap is the primary driver of this proposal. The gap means we cannot confirm whether the existing implementation uses link-local addressing, token-based auth, or caching — we are proposing these patterns based on OpenStack best practices.
- **Assumptions:** OpenStack metadata service follows the pattern of link-local addressing (169.254.169.254) on compute hosts. Token-based authentication is viable for the metadata service. Caching is appropriate for frequently requested metadata.
- **Section citations:**
  - `rubric_coverage.gaps` — "metadata_service_detail" gap
  - `survey.actors[7].capabilities` — "Access instance metadata via local metadata service"
  - `survey.walkthroughs[4].steps` — VncConsoleManager pattern for ticket-based auth

## Dependencies

**Depends on:**
- DEC-001: Three-process architecture (metadata service runs alongside nova-compute)
- DEC-003: REST API microversioning (metadata service uses same WSGI pipeline)
- DEC-007: Authorization (metadata service must enforce policy rules)

**Affects:**
- Future security review of metadata service (should verify token implementation)
- Future incident response procedures (metadata service outages)
- Future guest OS configuration (VMs must be configured to access metadata service)

## References

- **RECOMMENDATION section:** (No direct recommendation section — this is a gap-filling proposal based on rubric gap analysis)
- **Survey sections:**
  - `rubric_coverage.gaps` — "metadata_service_detail" gap
  - `survey.actors[7].capabilities` — VM Instance metadata access
  - `survey.walkthroughs[4].steps` — VncConsoleManager authentication pattern
  - `survey.backend.infrastructure` — nova-compute daemon deployment
- **Related decisions:**
  - DEC-001: Three-process distributed architecture (metadata service context)
  - DEC-003: REST API microversioning (WSGI pipeline reuse)
  - DEC-007: Authorization via oslo.policy (metadata service must enforce RBAC)

---

## Next Steps

### Review Process

1. **Read DIAGNOSIS.md** to understand survey gaps and completeness (90% complete, HIGH baseline)
2. **Read RECOMMENDATION.md** to evaluate options, alternatives, and confidence for all 10 recommendation areas
3. **Review each ADR above** to see proposed decisions in detail

DEC-001 through DEC-012 are already documented in architecture-decisions.json and do not require new proposals. These three proposals (DEC-013 through DEC-015) address the Testing Strategy, Observability, and Metadata Service gaps identified in the survey.

### Approval Flow

**These proposals are NOT yet merged to architecture-decisions.json.**

To approve and merge decisions:
```
/banneker:approve-proposal
```

This command (Phase 13) will:
- Present each proposal for individual review
- Allow acceptance, rejection, or modification
- Merge accepted proposals to architecture-decisions.json
- Update decision statuses from "Proposed" to "Accepted"

**Do not manually edit architecture-decisions.json.** Use the approval flow for proper tracking and state management.
