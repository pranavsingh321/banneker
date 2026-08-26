# Codebase Understanding: OpenStack Nova

Generated: 2026-08-26
Analyzed by: Banneker Cartographer

---

## Project Metadata

**Type:** python
**Primary Language:** Python 3.11/3.12/3.13
**Framework:** OpenStack Compute Service (custom WSGI, oslo.* suite)
**Version:** 33.0.0 (H branch, development — `33.0.0-395-gca11258683`)
**Monorepo:** No

**Scale:**
- Files: ~4,829 (excluding dependencies, test samples, locale)
- Lines of code: ~608,587 (Python only)
- Directories: ~857 total

**Analyzed:** 2026-08-26T00:00:00Z

---

## Directory Structure

```
nova/
├── .banneker/           — State/output directory for analysis tools
├── api-guide/           — API guide documentation (Sphinx)
├── api-ref/             — API reference documentation (Sphinx)
├── devstack/            — Devstack integration scripts & lib
├── doc/                 — Internal docs: API samples, schemas, notifications, source
├── etc/
│   └── nova/            — Config file templates (api-paste.ini, rootwrap.conf, etc.)
├── gate/                — CI gate scripts
├── playbooks/           — Zuul playbooks for integration test setup/teardown
├── releasenotes/        — Release note source (Sphinx)
├── roles/               — Ansible roles (likely for deployment)
├── tools/               — Utility scripts (check-cherry-picks, flake8wrap, etc.)
├── nova/                — Main Python source package
│   ├── api/             — REST API layer (OpenStack compute REST API)
│   │   ├── metadata/    — Instance metadata service
│   │   ├── openstack/   — OpenStack API (compute controllers, routing, WSGI)
│   │   └── validation/  — Request validation (extra_specs schemas)
│   ├── cmd/             — CLI entry points (nova-compute, nova-conductor, etc.)
│   ├── compute/         — Compute manager: instance lifecycle, build, resize, migrate
│   ├── conductor/       — Conductor service: DB-heavy tasks, remote builds
│   ├── conf/            — Configuration option definitions (48 config modules)
│   ├── console/         — Console proxy code (VNC, Spice, serial)
│   ├── db/              — Database layer (SQLAlchemy models, migrations, API)
│   ├── hacking/         — Custom flake8/lint rules (N3xx checks)
│   ├── image/           — Image handling (Glance integration)
│   ├── network/         — Networking abstractions (Neutron integration)
│   ├── notifications/   — Notification message definitions
│   ├── objects/         — Versioned objects (65 model classes, oslo.versionedobjects)
│   ├── policies/        — Policy rule definitions (56 policy modules)
│   ├── privsep/         — Privilege separation helpers (oslo.privsep)
│   ├── scheduler/       — Scheduler (filters, weights, host selection)
│   ├── servicegroup/    — Service heartbeat monitoring
│   ├── share/           — FileShare support (Manila integration)
│   ├── storage/         — Storage backend abstractions
│   ├── tests/           — Test suite (unit, functional, fixtures)
│   ├── virt/            — Virtualization drivers (libvirt, vmware, ironic, zvm)
│   ├── volume/          — Volume integration (os-brick, Cinder)
│   ├── api/openstack/compute/ — 77 REST API controller modules
│   ├── db/main/migrations/ — Alembic migration scripts
│   └── locale/          — Translations (11 locales: cs, de, es, fr, it, ja, ko, pt_BR, ru, tr, zh)
└── (top-level files: setup.py, pyproject.toml, tox.ini, requirements.txt, etc.)
```

**Key directories:**
- `nova/api/openstack/compute/` — REST API controllers (77 modules, all OpenStack Compute API endpoints)
- `nova/compute/` — Core compute logic: instance creation, live migration, resize, power management
- `nova/virt/libvirt/` — Primary virtualization driver (KVM, LXC, QEMU, Parallels)
- `nova/objects/` — 65 versioned object models (oslo.versionedobjects-based ORM-like layer)
- `nova/policies/` — 56 authorization policy rule files (oslo.policy)
- `nova/conf/` — 48 configuration option modules (oslo.config)
- `nova/scheduler/filters/` — 19 host selection filters (affinity, NUMA, PCI, aggregate, etc.)
- `nova/tests/` — Test suite split into `unit/` and `functional/`
- `doc/api_samples/` — API sample test fixtures (organized by API version)
- `doc/notification_samples/` — Notification message sample data

---

## Technology Stack

### Frontend

None detected — Nova is a backend-only cloud service.

### Backend

| Technology | Version | Purpose |
|------------|---------|---------|
| Python | 3.11/3.12/3.13 | Primary language (3.10 deprecated/removed) |
| pBR (Python Build Registry) | >=6.1.1 | Build system, version management, package metadata |
| WebOb | >=1.8.2 | HTTP request/response handling |
| Routes | >=2.3.1 | URL routing / URL mapper |
| PasteDeploy | >=1.5.0 | WSGI pipeline configuration |
| Paste | >=2.0.2 | WSGI middleware |
| oslo.service | >=4.5.0 | Service lifecycle, RPC server, periodic tasks |
| oslo.middleware | >=3.31.0 | WSGI middleware stack |
| keystonemiddleware | >=4.20.0 | Keystone authentication/authorization middleware |
| keystoneauth1 | >=3.16.0 | Keystone authentication plugin |
| openstacksdk | >=4.4.0 | OpenStack SDK (Glance, Cinder, etc. client) |
| microversion-parse | >=0.2.1 | API microversion parsing |
| rfc3986 | >=1.2.0 | URI parsing/validation |
| jsonschema | >=4.0.0 | Request body validation |
| TooZ | >=1.58.0 | Distributed coordination (lock groups, leader election) |
| castellan | >=0.16.0 | Cryptographic key management (Barbican integration) |
| futurist | >=3.2.1 | Futures, workqueues, retry patterns |
| cursive | >=0.2.1 | Distributed state machine (live migration coordination) |
| retrying | >=1.3.3 | Retry decorator |
| openstack-service-types | >=1.7.0 | OpenStack service type lookup |
| python-dateutil | >=2.7.0 | Date/time manipulation |
| PyYAML | >=5.1 | YAML parsing |
| PrettyTable | >=0.7.1 | CLI table formatting (nova-manage) |

### Database

| Technology | Version | Purpose |
|------------|---------|---------|
| SQLAlchemy | >=1.4.13 | ORM, database abstraction |
| Alembic | >=1.5.0 | Database migrations (Migrate → Alembic transition completed) |
| psycopg2-binary | >=2.8 | PostgreSQL adapter (test) |
| PyMySQL | >=0.8.0 | MySQL/MariaDB adapter (test) |
| SQLite | stdlib | SQLite adapter (test fallback) |
| oslo.db | >=10.0.0 | Database session management, migrations, retry |

### Testing

| Technology | Version | Purpose |
|------------|---------|---------|
| stestr | >=2.0.0 | Test runner (primary) |
| testtools | >=2.5.0 | Test framework extensions |
| fixtures | >=3.0.0 | Test fixture framework |
| oslotest | >=3.8.0 | OpenStack test base classes |
| ddt | >=1.2.1 | Data-driven tests |
| testscenarios | >=0.4 | Scenario-based test parameterization |
| testresources | >=2.0.0 | Shared test resources |
| requests-mock | >=1.2.0 | HTTP request mocking |
| wsgi-intercept | >=1.7.0 | WSGI-level request interception |
| coverage | >=4.4.1 | Code coverage |
| hacking | 8.0.0 | OpenStack linting rules (N3xx custom checks) |
| bandit | >=1.1.0 | Security linting |
| osprofiler | >=1.4.0 | Request tracing/profiling |
| tempest | (external) | Integration tests (run via devstack) |
| mypy | (dev) | Type checking (selected critical files) |

### Build & Tooling

| Technology | Version | Purpose |
|------------|---------|---------|
| pre-commit | — | Git pre-commit hooks (autopep8, hacking, codespell, sphinx-lint) |
| autopep8 | — | Python code formatting |
| codespell | >=2.4.1 | Spelling checker |
| sphinx | (doc deps) | Documentation build (Sphinx/RST) |
| oslo-config-generator | — | Sample config file generator |
| oslopolicy-sample-generator | — | Policy rule sample generator |
| mypy | — | Type checker (incremental, skip imports) |

### Infrastructure

| Technology | Version | Purpose |
|------------|---------|---------|
| Docker | — | Containerized CI environments (implicit in devstack) |
| Zuul (OpenDev) | — | CI/CD pipeline (.zuul.yaml) |
| Devstack | — | Single-node OpenStack deployment for testing |
| Ansible | — | Role definitions for deployment (`roles/`) |
| Gerrit | — | Code review (Gerrit workflow per AGENTS.md) |

---

## Key Patterns Detected

### Architecture Pattern

**Layered / Service-oriented Monolith**

Nova follows a layered service architecture with a clear separation of concerns:

1. **API Layer** (`nova/api/`) — REST API controllers handling HTTP requests, validation, microversion negotiation. Each endpoint has its own module in `nova/api/openstack/compute/`.
2. **Service Layer** (`nova/compute/`, `nova/conductor/`, `nova/scheduler/`, `nova/cmd/`) — Core service managers with RPC endpoints. The three primary services (nova-compute, nova-conductor, nova-scheduler) each have their own process.
3. **Driver Layer** (`nova/virt/`) — Pluggable virtualization drivers. Libvirt is the default; VMware, ZVM, and Ironic are optional drivers loaded via Stevedore entry points.
4. **Data Layer** (`nova/objects/`, `nova/db/`) — Versioned object model (oslo.versionedobjects) on top of SQLAlchemy models. Shadow tables for soft deletes.
5. **Configuration Layer** (`nova/conf/`) — Modular config options organized by subsystem (48 config modules).
6. **Policy Layer** (`nova/policies/`) — Authorization rules (oslo.policy) defined per API module (56 policy files).

The codebase follows the OpenStack pattern of "Smart Managers and Dumb Data" — managers encapsulate business logic while data objects (versioned objects) carry only data and serialization.

### API Communication

**REST API with Microversions**

- Base API version: **v2.1** (current, stable)
- Legacy v2.0 marked as **DEPRECATED**
- Microversions range from **2.1 to 2.104** (390+ microversion changes documented)
- Content-type: `application/json`
- Media type: `application/vnd.openstack.compute+json;version=2.1`
- URL routing via custom `ProjectMapper` based on the Routes library
- Request/response via WebOb (Werkzeug-like)

**Sample endpoints (ROUTE_LIST from `nova/api/openstack/compute/routes.py`):**

| Method | Path | Controller | Description |
|--------|------|------------|-------------|
| GET | `/servers` | `servers.ServersController.index` | List all servers |
| POST | `/servers` | `servers.ServersController.create` | Create a server |
| GET | `/servers/{id}` | `servers.ServersController.show` | Show server details |
| PUT | `/servers/{id}` | `servers.ServersController.update` | Update server |
| DELETE | `/servers/{id}` | `servers.ServersController.delete` | Delete a server |
| POST | `/servers/{id}/action` | `servers.ServersController.action` | Server action (reboot, resize, etc.) |
| GET | `/servers/{id}/migrations` | `server_migrations` | List migrations for a server |
| POST | `/os-aggregates` | `aggregates` | Create host aggregate |
| GET | `/os-hypervisors` | `hypervisors` | List hypervisors (compute nodes) |
| GET | `/flavors` | `flavors.FlavorsController.index` | List flavors |
| POST | `/images` | `images.ImagesController.index` | List images (proxied to Glance) |
| GET | `/os-services` | `services.ServiceController.index` | List agent services |

### State Management

**oslo.versionedobjects with explicit versioning**

Nova's data layer uses the OpenStack versioned object system (`oslo_versionedobjects`). Key characteristics:

- 65 object classes defined in `nova/objects/` (instance, compute_node, flavor, aggregate, migration, etc.)
- Each object has a `VERSION` attribute (e.g., `Instance.VERSION = '1.13'`)
- Objects are auto-registered and accessible as `nova.objects.Instance`
- Shadow tables used for soft deletes (prefixed `shadow_`)
- Custom `NovaObjectRegistry` extends `VersionedObjectRegistry` to manage highest-version aliases
- Custom field types in `nova/objects/fields.py` (UUID, InstanceList, JSON, etc.)

### Routing

**Custom REST API routing via Routes + WebOb WSGI**

- URL routing defined in `nova/api/openstack/compute/routes.py` via `ROUTE_LIST` tuple
- Custom `APIRouterV21` class builds the URL map from `ROUTE_LIST`
- Controllers are simple Python classes with methods matching HTTP actions (e.g., `index`, `show`, `create`, `delete`, `action`)
- Sub-controllers registered via `_create_controller()` helper with `register_subcontroller_actions()`
- API version negotiation via `nova.api.openstack.wsgi` and `api_version_request` module
- Microversions communicated via `X-OpenStack-Nova-API-Version` HTTP header
- Metadata service at `nova/api/metadata/` (separate mount point, no microversioning)
- Request ID header: `X-OpenStack-Request-ID`

### Data Flow

**Hybrid: RPC-driven with REST API surface**

1. **REST API → Manager → RPC → Service**
   - Client hits OpenStack Compute API (e.g., `POST /servers`)
   - Controller method calls into `nova.compute.manager.ComputeManager`
   - Manager methods execute locally or dispatch via RPC to compute/conductor services
   - RPC uses `oslo.messaging` (default transport: RabbitMQ via Kombu)

2. **Scheduler Flow**
   - Build request → Scheduler (RPC) → Filters/Weights → Host selection → RPC to conductor → RPC to compute

3. **Compute Manager Flow**
   - `ComputeManager` orchestrates instance lifecycle: build, start, stop, live-migrate, resize, evacuate
   - Heavy use of `oslo.service.periodic_task` for background tasks (host aggregation, resource tracking)
   - Virtualization operations delegated to `nova.virt.libvirt.driver.LibvirtDriver` (or other drivers)

4. **Conductor Service**
   - `ConductorManager` handles DB-heavy operations that compute nodes should not perform directly
   - Manages build requests, migration data, instance actions, task logs
   - Cell-based delegation: conductor routes requests to appropriate cell

5. **Cell Architecture**
   - Nova supports multi-cell deployments (cells v2)
   - Cell mappings managed via `nova.objects.CellMapping`
   - Cell0: metadata database (no compute)
   - Cell1+: actual compute hosts

---

## Entry Points

**Main entry points (from `pyproject.toml` `[project.scripts]`):**

| Entry Point | Module | Purpose |
|-------------|--------|---------|
| `nova-compute` | `nova.cmd.compute:main` | Compute daemon — manages instances on a host |
| `nova-conductor` | `nova.cmd.conductor:main` | Conductor daemon — DB operations, build coordination |
| `nova-scheduler` | `nova.cmd.scheduler:main` | Scheduler daemon — selects hosts for instances |
| `nova-manage` | `nova.cmd.manage:main` | CLI management tool |
| `nova-novncproxy` | `nova.cmd.novncproxy:main` | noVNC console proxy |
| `nova-serialproxy` | `nova.cmd.serialproxy:main` | Serial console proxy |
| `nova-spicehtml5proxy` | `nova.cmd.spicehtml5proxy:main` | SPICE HTML5 proxy |
| `nova-policy` | `nova.cmd.policy:main` | Policy rule management tool |
| `nova-status` | `nova.cmd.status:main` | Health check/status CLI |
| `nova-rootwrap` | `oslo_rootwrap.cmd:main` | Privilege separation wrapper |

**Base service infrastructure** (`nova/service.py`):
- `SERVICE_MANAGERS` maps service name to manager class:
  - `nova-compute` → `nova.compute.manager.ComputeManager`
  - `nova-conductor` → `nova.conductor.manager.ConductorManager`
  - `nova-scheduler` → `nova.scheduler.manager.SchedulerManager`
- `Service` class wraps managers in a service wrapper with heartbeat, RPC server, and periodic task support
- Concurrency: **eventlet** (green threads) by default, with native threading option (`concurrency_backend: threading`)

**Scripts (from `tox.ini`):**

| Script | Command | Purpose |
|--------|---------|---------|
| `unit` / `py3` | `stestr run {posargs}` | Run unit tests |
| `functional` | `stestr --test-path=./nova/tests/functional run` | Run functional tests |
| `pep8` | `pre-commit run --all-files` | Style checks + mypy |
| `cover` | coverage + stestr | Run with code coverage |
| `api-samples` | `stestr --test-path=... run` | Generate API samples |
| `docs` | `sphinx-build -b html` | Build documentation |
| `api-guide` | `sphinx-build -b html api-guide/` | Build API guide |
| `api-ref` | `sphinx-build -b html api-ref/` | Build API reference |
| `releasenotes` | `sphinx-build -b html releasenotes/` | Build release notes |
| `bandit` | `bandit -r nova -x tests` | Security audit |

---

## Configuration Files

| File | Purpose |
|------|---------|
| `pyproject.toml` | Build system (pBR), project metadata, entry points, optional deps, tool configs (mypy, coverage, codespell, autopep8) |
| `setup.py` | Legacy setup shim — `pbr=True` |
| `setup.cfg` | Minimal: just `name = nova` |
| `tox.ini` | Test environments (unit, functional, pep8, mypy, cover, docs, bandit, api-samples), pre-commit hooks |
| `.pre-commit-config.yaml` | Hooks: trailing-whitespace, mixed-line-ending, autopep8, hacking, codespell, sphinx-lint |
| `.zuul.yaml` | CI/CD pipeline definitions (Zuul v3) — 40+ jobs including tempest integration, live migration, multi-cell, emulation |
| `.stestr.conf` | Stestr test runner configuration |
| `requirements.txt` | Runtime dependencies with lower bounds |
| `test-requirements.txt` | Test dependencies (hacking, stestr, coverage, etc.) |
| `bindep.txt` | System/package dependencies for Debian/RPM |
| `.gitreview` | Gerrit code review integration |
| `nova/conf/opts.py` | Centralized config option aggregation (imports all 48 config modules) |
| `etc/nova/nova-config-generator.conf` | oslo-config-generator config for `nova.conf` generation |
| `etc/nova/nova-policy-generator.conf` | oslopolicy-sample-generator for policy samples |
| `etc/nova/api-paste.ini` | WSGI pipeline configuration (paste.deploy) |
| `etc/nova/rootwrap.conf` | oslo-rootwrap configuration |
| `etc/nova/rootwrap.d/` | Rootwrap filter files |
| `playbooks/` | Ansible playbooks for Zuul CI (nova-next, nova-live-migration, nova-multi-cell, etc.) |
| `devstack/` | Devstack integration scripts (lib/ directory) |

---

## Notable Patterns

### Custom Abstractions

**1. Virt Driver Plugin System**
- Pluggable virtualization drivers via Stevedore entry points
- Default driver: `nova.virt.libvirt.driver.LibvirtDriver` (13,990 lines)
- Optional drivers: `nova.virt.vmwareapi.VMwareDriver`, `nova.virt.zvm.driver.ZVMDriver`, `nova.virt.ironic.driver.IronicDriver`
- Shared via `nova.virt.driver.ComputeDriver` abstract base

**2. Versioned Object System**
- Custom subclass of `oslo_versionedobjects.VersionedObject` with Nova-specific behavior
- Shadow table support for soft deletes
- Field types: `UUID`, `ImageMeta`, `InstanceList`, `VirtCPUTopology`, `PCIDevicePool`, etc.
- Versioned compatibility via `obj_make_compatible()` method on each object

**3. Policy Rule System**
- 56 policy files defining fine-grained RBAC rules via `oslo.policy`
- Each policy file corresponds to an API module (e.g., `servers.py`, `aggregates.py`, `hypervisors.py`)
- Custom policy enforcer entry point at `nova.policy:get_enforcer`
- Policy registration entry point at `nova.policies:list_rules`

**4. Extra Spec Validators**
- 12 validators for flavor extra specs loaded via Stevedore entry points (`nova.api.extra_spec_validators`)
- Covers: accel, capabilities, hw_rng, hw_video, hw, json, pci_passthrough, quota, resources, traits, vmware, null

**5. Scheduler Filter/Weight System**
- 19 filter plugins (affinity, aggregate, NUMA, PCI, image properties, etc.)
- Weight plugins for host scoring
- Both loaded via Stevedore entry points
- Custom `RequestFilter` base class with `get_filters()` and `get_weights()` pattern

**6. Config-Driven Subsystem Modules**
- `nova/conf/` contains 48 modular config files, each defining options for a subsystem
- All aggregated via `nova.conf.opts:list_opts()`
- Entry point registration: `[project.entry-points."oslo.config.opts"]` → `"nova.conf" = "nova.conf.opts:list_opts"`

**7. Microversion Decorator Pattern**
- API methods decorated with `@validation.validated` and version decorators
- API version header `X-OpenStack-Nova-API-Version` parsed by `api_version_request`
- 390+ documented microversion changes (2.1 through 2.104)

**8. Eventlet with Native Threading Fallback**
- Default concurrency: eventlet green threads via `eventlet.monkey_patch()`
- Alternative: native Python threading (`concurrency_backend: threading`)
- Test infrastructure enforces greenlet leak detection (`NOVA_RAISE_ON_GREENLET_LEAK`)
- Dual test suites: unit (eventlet) + threading-specific tests (native threading)

**9. Cell-Based Architecture (Cells v2)**
- Multi-cell deployment support with `nova.objects.CellMapping`
- Cell0: metadata database only
- Cell1+: actual compute hosts with conductor
- Conductor routes requests between cells via RPC

**10. Privilege Separation**
- `nova/privsep/` directory with oslo.privsep decorators
- Separates privileged operations (host commands, block device operations) from unprivileged code
- Used by libvirt driver and block device modules

### Code Organization

- **Barrel exports**: `nova/__init__.py` re-exports from `nova.version` and `nova.objects`
- **Index imports**: `nova/objects/__init__.py` imports all 65 object classes for direct access
- **Policy imports**: `nova/policies/__init__.py` aggregates all 56 policy rule lists
- **Module-local controllers**: Each API endpoint lives in its own module in `nova/api/openstack/compute/`
- **Schema/validation files**: `nova/api/openstack/compute/schemas/` for JSON schema definitions
- **View modules**: `nova/api/openstack/compute/views/` for response serialization

### Build Process

1. **Build**: `pbr` handles package building, version detection (git tags), and metadata generation
2. **Install**: `pip install -e .` (editable mode) installs the package with entry points
3. **Lint**: pre-commit hooks run autopep8, hacking (flake8 custom rules), codespell, sphinx-lint
4. **Type check**: mypy runs on a curated set of critical files (compute manager, PCI, libvirt driver, utils, etc.)
5. **Unit test**: `stestr` runs tests from `nova/tests/unit/`
6. **Functional test**: `stestr` runs tests from `nova/tests/functional/` (requires OpenStack Placement service)
7. **Integration test**: Tempest runs against a devstack-deployed OpenStack cluster via Zuul jobs
8. **Documentation**: Sphinx builds from `doc/source/`, `api-guide/source/`, `api-ref/source/`, `releasenotes/source/`

---

## Dependencies Summary

**Key production dependencies (64 total):**

- `pbr` — Build system, version management
- `SQLAlchemy` — ORM / database layer
- `eventlet` — Green thread concurrency
- `oslo.*` suite (15+ packages) — Core OpenStack library framework (config, messaging, service, logging, concurrency, policy, privsep, versionedobjects, cache, etc.)
- `keystonemiddleware` — Keystone auth middleware
- `keystoneauth1` — Keystone auth plugin
- `Routes` / `WebOb` / `PasteDeploy` / `Paste` — WSGI HTTP stack
- `os-brick` — iSCSI/FC volume attachment
- `os-vif` — Virtual interface management
- `oslo.db` — Database session management
- `oslo.messaging` — Messaging (RabbitMQ/Kombu transport)
- `oslo.policy` — Authorization policy engine
- `oslo.versionedobjects` — Versioned object serialization
- `oslo.cache` — Caching layer (dogpile.cache)
- `oslo.concurrency` — Distributed lock utilities
- `oslo.service` — Service lifecycle, RPC server, periodic tasks
- `alembic` — Database migrations
- `os-resource-classes` — Resource provider allocation
- `os-traits` — Hardware trait definitions
- `python-cinderclient` — Cinder volume client
- `python-neutronclient` — Neutron networking client
- `python-glanceclient` — Glance image client
- `cryptography` — TLS/certificate handling
- `lxml` — XML parsing (libvirt domain definitions)
- `Jinja2` — Template engine (libvirt XML generation)
- `paramiko` — SSH operations
- `netaddr` — IP address manipulation
- `openstacksdk` — OpenStack SDK client
- `tooZ` — Distributed coordination
- `cursive` — Distributed state machine
- `castellan` — Key management (Barbican)
- `oslo.rootwrap` — Privilege separation
- `oslo.i18n` — Internationalization
- `oslo.reports` — Report generation
- `oslo.upgradecheck` — Upgrade validation
- `oslo.limit` — Rate limiting
- `oslo.context` — Request context propagation
- `oslo.utils` — Utility functions
- `oslo.log` — Logging infrastructure
- `requests` — HTTP client (fallback)
- `stevedore` — Plugin loading (entry points)
- `lsscsi`, `os-resource-classes`, `os-traits` — Hardware discovery

**Key development dependencies (16 total):**

- `hacking==8.0.0` — OpenStack linting rules (N3xx custom checks)
- `stestr>=2.0.0` — Test runner
- `coverage>=4.4.1` — Code coverage
- `oslotest>=3.8.0` — OpenStack test base
- `ddt>=1.2.1` — Data-driven tests
- `fixtures>=3.0.0` — Test fixtures
- `testtools>=2.5.0` — Test framework
- `testscenarios>=0.4` — Scenario parameterization
- `testresources>=2.0.0` — Shared test resources
- `requests-mock>=1.2.0` — HTTP mocking
- `wsgi-intercept>=1.7.0` — WSGI interception
- `bandit>=1.1.0` — Security linting
- `osprofiler>=1.4.0` — Distributed tracing
- `pre-commit` — Git hooks
- `mypy` — Type checking
- `sphinx` — Documentation build

**Total dependencies:** 64 production, 16 development

---

## Analysis Notes

**Confidence:** High

Project structure is clear and well-documented. Nova is one of the most studied OpenStack services with extensive documentation, a mature codebase (10+ years of development), and clearly defined architectural patterns. All key technologies, frameworks, and dependencies were identified from source code, manifests, and CI configuration.

**Potential gaps:**
- Specific version numbers for many `oslo.*` libraries are ">= lower_bound" from `requirements.txt` — exact runtime versions depend on the installed environment
- The exact number of Alembic migration files is limited (only 10 shown in directory listing) — the migration history may span more files not visible in the current scan depth
- The metadata service (`nova/api/metadata/`) was not examined in detail
- Some optional driver modules (vmware, zvm, ironic) may have additional complexity not fully explored

**Next steps for onboarding:**
1. Read [`doc/source/contributor/repo-overview.rst`](doc/source/contributor/repo-overview.rst) for the official contributor layout guide
2. Read [`HACKING.rst`](HACKING.rst) for code style rules and custom lint checks
3. Read [`doc/source/contributor/testing.rst`](doc/source/contributor/testing.rst) for test conventions
4. Run `tox -e pep8` to verify the development environment is set up correctly
5. Run `tox -e unit` to verify unit tests pass
6. Review `nova/cmd/*.py` files to understand service startup flow
7. Read `nova/service.py` to understand the service lifecycle and RPC setup
8. Consult the [OpenStack Nova Developer Guide](https://docs.openstack.org/nova/latest/contributor/) for architectural deep-dives

---

*Generated by Banneker Cartographer. For questions about this analysis, review the scan logs or re-run `/banneker:document`.*
