# Codebase Understanding: OpenStack Nova

Generated: 2026-08-26
Analyzed by: Banneker Cartographer

---

## Project Metadata

**Type:** python
**Primary Language:** Python (3.11, 3.12, 3.13)
**Framework:** OpenStack (oslo libraries, eventlet, WebOb WSGI)
**Version:** Dynamically managed by pbr (pbr>=6.1.1 build-system)
**Monorepo:** No (single project with co-located docs)

**Scale:**
- Files: ~4,837 (Python files excluding tests, dependencies, generated)
- Lines of code: ~608,587 total Python lines (~211,194 production)
- Directories: ~834

**Analyzed:** 2026-08-26

---

## Directory Structure

```
.
├── api-guide/            # API guide documentation (Sphinx)
├── api-ref/              # API reference documentation (Sphinx)
├── devstack/             # DevStack plugin for local deployment
├── doc/                  # Notification sample data, doc config
├── etc/                  # Default config files, rootwrap filters
├── gate/                 # CI gate configuration and READMEs
├── nova/                 # Main package
│   ├── accelerator/      # Cyborg accelerator driver support
│   ├── api/              # REST API layer (OpenStack API v2.1)
│   ├── cmd/              # Service CLI entry points
│   ├── compute/          # Compute manager, API, task states
│   ├── conductor/        # Database-backed service, async tasks
│   ├── conf/             # Configuration definitions
│   ├── console/          # Console proxy support
│   ├── db/               # SQLAlchemy models, Alembic migrations
│   ├── hacking/          # Custom flake8/lint checks (N3xx)
│   ├── image/            # Image/glance integration
│   ├── keymgr/           # Encryption key management
│   ├── limit/            # Resource placement limits
│   ├── network/          # Neutron network integration
│   ├── notifications/    # Event notification objects
│   ├── objects/          # Versioned domain objects (49 files)
│   ├── pci/              # PCI passthrough handling
│   ├── policies/         # oslo.policy rule definitions
│   ├── privsep/          # oslo.privsep helper scripts
│   ├── scheduler/        # Scheduler filters, weights, client
│   ├── servicegroup/     # Service health monitoring drivers
│   ├── share/            # NFS/Share integration
│   ├── storage/          # Storage backends
│   ├── virt/             # Virtualization drivers (libvirt, VMware, ZVM, Ironic)
│   ├── volume/           # Cinder volume integration
│   ├── wsgi/             # WSGI server wrappers
│   ├── *.py              # Core modules (service, rpc, context, utils, etc.)
│   ├── locale/           # i18n translations (12 languages)
│   └── tests/            # Test suites
├── playbooks/            # Zuul playbooks for CI/CD
├── releasenotes/         # Release note documentation
├── roles/                # Ansible roles for testing
├── tools/                # Development scripts and hooks
├── HACKING.rst           # Style guide and lint commandments
├── pyproject.toml        # PEP 621 project metadata + tool configs
├── setup.py              # pbr bootstrap (legacy)
├── setup.cfg             # metadata (name only)
├── requirements.txt      # Production dependencies (64 deps)
├── test-requirements.txt # Test dependencies (16 deps)
├── tox.ini               # Tox environments (436 lines)
├── AGENTS.md             # Agent routing instructions
└── README.rst            # Project overview
```

**Key directories:**
- `nova/` — Main package containing all Nova source code (26 sub-packages + root modules)
- `nova/api/openstack/compute/` — REST API controllers (77 controller files)
- `nova/virt/` — Virtualization driver abstraction (libvirt/KVM primary, VMware, ZVM, Ironic)
- `nova/objects/` — Versioned domain objects (oslo.versionedobjects)
- `nova/scheduler/` — Host scheduler with filters and weights
- `nova/conductor/` — Database access service with async task handling
- `nova/tests/` — Test suites (functional and unit)
- `nova/db/` — SQLAlchemy models and Alembic migration scripts

---

## Technology Stack

### Frontend

| Technology | Version | Purpose |
|------------|---------|---------|
| None detected | — | — |

### Backend

| Technology | Version | Purpose |
|------------|---------|---------|
| Python | 3.11–3.13 | Core language (CPython) |
| WebOb | >=1.8.2 | HTTP request/response handling |
| eventlet | >=0.30.1 | Coroutine-based concurrency (monkey-patching) |
| greenlet | >=0.4.15 | eventlet dependency (coroutines) |
| PasteDeploy | >=1.5.0 | WSGI config loading |
| Paste | >=2.0.2 | WSGI middleware composition |
| Routes | >=2.3.1 | URL routing |
| oslo.service | >=4.5.0 | Service lifecycle management |
| oslo_messaging | >=14.1.0 | RPC transport and notifications (RabbitMQ) |
| keystonemiddleware | >=4.20.0 | Keystone authentication middleware |
| keystoneauth1 | >=3.16.0 | Keystone token validation |
| openstacksdk | >=4.4.0 | OpenStack SDK integration |
| os-service-types | >=1.7.0 | Service type discovery |
| os-brick | >=6.10.0 | Multipath/iSCSI volume access |
| os-vif | >=3.1.0 | Virtual network interface handling |
| os-traits | >=3.8.0 | Compute trait definitions |
| os-resource-classes | >=1.1.0 | Resource class definitions for Placement |
| oslo.cache | >=1.26.0 | Distributed caching |
| oslo.concurrency | >=5.0.1 | Locking and resource coordination |
| oslo.config | >=9.3.0 | Configuration management |
| oslo.context | >=3.4.0 | Request context handling |
| oslo.log | >=4.6.1 | Logging infrastructure |
| oslo.middleware | >=3.31.0 | WSGI middleware collection |
| oslo.policy | >=6.0.0 | RBAC policy enforcement |
| oslo.privsep | >=3.11.0 | Privilege separation helpers |
| oslo.reports | >=1.18.0 | Reporting utilities |
| oslo.serialization | >=4.2.0 | JSON/serialization utilities |
| oslo.upgradecheck | >=1.3.0 | API upgrade compliance |
| oslo_utils | >=8.0.0 | Common utility functions |
| osprofiler | optional | Distributed tracing |

### Database

| Technology | Version | Purpose |
|------------|---------|---------|
| SQLAlchemy | >=1.4.13 | ORM (primary data access layer) |
| Alembic | >=1.5.0 | Database migration tooling |
| psycopg2-binary | >=2.8 | PostgreSQL driver (testing) |
| PyMySQL | >=0.8.0 | MySQL driver (testing) |
| oslo.db | >=10.0.0 | Database session management |
| oslo_versionedobjects | >=1.35.0 | Versioned object model layer |
| cursive | >=0.2.1 | Database query DSL |

### Testing

| Technology | Version | Purpose |
|------------|---------|---------|
| stestr | >=2.0.0 | Test runner (primary) |
| oslotest | >=3.8.0 | OpenStack test fixtures |
| testtools | >=2.5.0 | Extended test assertions |
| testscenarios | >=0.4 | Test matrix generation |
| testresources | >=2.0.0 | Test resource management |
| fixtures | >=3.0.0 | Test fixture library |
| coverage | >=4.4.1 | Code coverage reporting |
| hacking | ==8.0.0 | OpenStack style linting |
| bandit | >=1.1.0 | Security linting |
| ddt | >=1.2.1 | Data-driven tests |
| requests-mock | >=1.2.0 | HTTP mocking |
| wsgi-intercept | >=1.7.0 | WSGI request interception |
| osprofiler | >=1.4.0 | Profiler testing |

### Build & Tooling

| Technology | Version | Purpose |
|------------|---------|---------|
| pbr | >=6.1.1 | Python Build Reasonableness (build system) |
| mypy | (dev dep) | Static type checking |
| autopep8 | (pre-commit) | PEP 8 auto-formatting |
| codespell | (pre-commit) | Spell checking |
| pre-commit | (dev dep) | Git hook management |
| oslo-config-generator | (tooling) | Config option generation |
| oslopolicy-sample-generator | (tooling) | Policy rule generation |
| Sphinx | (doc dep) | Documentation build |
| flake8 | (via pre-commit) | Style linting |
| mypy | (dev dep) | Type checking |

### Infrastructure

| Technology | Version | Purpose |
|------------|---------|---------|
| DevStack | (devstack/) | Local OpenStack deployment |
| Ansible | (roles/) | Test environment provisioning |
| Zuul | (.zuul.d implied) | CI/CD orchestration (OpenStack gate) |

---

## Key Patterns Detected

### Architecture Pattern

**Layered / Multi-service Architecture**

Nova follows a classic OpenStack multi-service architecture where distinct processes handle different concerns, communicating via RPC (oslo.messaging over RabbitMQ) and REST (OpenStack API v2.1).

- **Service layer** (`nova/cmd/`): `nova-compute`, `nova-conductor`, `nova-scheduler`, `nova-novncproxy`, `nova-serialproxy`, `nova-spicehtml5proxy`, `nova-manage`, `nova-status`, `nova-policy`
- **API layer** (`nova/api/`): WSGI-based REST API (67 controllers in `nova/api/openstack/compute/`)
- **Domain model layer** (`nova/objects/`): 49 versioned domain objects (oslo.versionedobjects)
- **Database layer** (`nova/db/`): SQLAlchemy models, alembic migrations (10 migration scripts), migration API (3 files)
- **Virtualization layer** (`nova/virt/`): Driver-based abstraction for KVM/libvirt, VMware, Z/VM, Ironic
- **Scheduler layer** (`nova/scheduler/`): Filter chain (20+ filters) and weight functions (11 weighters)
- **Privilege separation** (`nova/privsep/`): 8 privsep helpers (fs, idmapshift, libvirt, linux_net, path, qemu, utils)

### API Communication

**REST (OpenStack Compute API v2.1) + RPC (oslo.messaging)**

**REST API:**
- WSGI application stack (WebOb, custom nova/wsgi/)
- 67+ controller files under `nova/api/openstack/compute/`
- Each controller follows the `Controller` pattern with `index()`, `show()`, `create()`, `update()`, `delete()` methods
- Microversioned API: v2.0 (DEPRECATED), v2.1 (CURRENT) with version negotiation via `Accept` header
- JSON media types: `application/vnd.openstack.compute+json`
- API version history tracked in `nova/api/openstack/compute/rest_api_version_history.rst`
- Request validation via `nova/api/validation/` (extra_specs validators for accel, hw, pci, etc.)
- Policy enforcement via `nova/policies/` (50+ policy modules)

**RPC Inter-service:**
- oslo.messaging transport (RabbitMQ broker)
- Client-server pattern: `nova/conductor/rpcapi.py`, `nova/compute/rpcapi.py`, `nova/scheduler/rpcapi.py`
- Request serialization via oslo_serialization (jsonutils)
- Distributed tracing via osprofiler

### State Management

**oslo.versionedobjects with SQLAlchemy persistence**

- All domain objects inherit from `oslo_versionedobjects.base.Object` (defined in `nova/objects/base.py`, line 26)
- Field types defined in `nova/objects/fields.py` (custom field types beyond oslo defaults)
- Objects handle their own serialization/deserialization for RPC transport
- Versioned objects carry a schema version for forward/backward compatibility
- No client-side state management — all state is server-side with database persistence

### Routing

**OpenStack API version negotiation + WSGI route mapping**

- Versioned API via `nova/api/openstack/api_version_request.py`
- Main route file: `nova/api/openstack/compute/routes.py`
- WSGI stack: `nova/wsgi/osapi_compute.py` (OSAPI Compute wrapper), `nova/wsgi/metadata.py` (metadata service)
- URL routing via Routes library
- View-layer separation: `nova/api/openstack/compute/views/` for response formatting

### Data Flow

**Hybrid (REST API + RPC + Eventlet concurrency)**

- **API entry**: HTTP request → WSGI middleware chain (keystonemiddleware auth, oslo.middleware) → Controller action
- **Compute operations**: Controller → `nova/compute/api.py` (business logic) → RPC calls to `nova-compute` service → libvirt/virtualization driver
- **Database access**: Controller/Compute → `nova/conductor/manager.py` (async DB operations) → `nova/db/` (SQLAlchemy)
- **Scheduling**: Controller → `nova/scheduler/client/` → RPC to `nova-scheduler` → Filter chain → Weight functions → Host selection
- **Eventlet concurrency**: eventlet.monkey_patch() applied early (`nova/monkey_patch.py`) in "auto" mode, with optional threading backend (`OS_NOVA_DISABLE_EVENTLET_PATCHING=True`)

### Virtualization Drivers

**Pluggable driver architecture (Stevedore entry points):**

- **libvirt** (`nova/virt/libvirt/driver.py`): Primary driver — KVM, QEMU, LXC, Xen
- **VMware** (`nova/virt/vmwareapi/driver.py`): VMware vSphere/ESXi
- **ZVM** (`nova/virt/zvm/driver.py`): IBM Z/VM
- **Ironic** (`nova/virt/ironic/driver.py`): Bare metal via OpenStack Ironic

### Policy Architecture

**Centralized oslo.policy with per-feature modules:**

- 50+ policy modules in `nova/policies/` (admin_actions, aggregates, floating_ips, hypervisors, etc.)
- Entry point registration: `oslo.policy.policies` → `nova.policies:list_rules`
- Policy generation via `oslopolicy-sample-generator` (tox env `genpolicy`)
- Policy enforcement check via `nova/policies/base.py`

---

## Entry Points

**Main entry points (defined in `pyproject.toml` `[project.scripts]`):**

| Entry Point | Module | Purpose |
|-------------|--------|---------|
| `nova-compute` | `nova.cmd.compute:main` | Compute node daemon (manages VM lifecycle) |
| `nova-conductor` | `nova.cmd.conductor:main` | Database intermediary service |
| `nova-scheduler` | `nova.cmd.scheduler:main` | Host selection for instance placement |
| `nova-novncproxy` | `nova.cmd.novncproxy:main` | NoVNC proxy for console access |
| `nova-serialproxy` | `nova.cmd.serialproxy:main` | Serial console proxy |
| `nova-spicehtml5proxy` | `nova.cmd.spicehtml5proxy:main` | SPICE HTML5 proxy |
| `nova-manage` | `nova.cmd.manage:main` | CLI for administration/migrations |
| `nova-status` | `nova.cmd.status:main` | Health check/status commands |
| `nova-policy` | `nova.cmd.policy:main` | Policy generation utility |
| `nova-rootwrap` | `oslo_rootwrap.cmd:main` | Privileged command execution |

---

## Configuration Files

| File | Purpose |
|------|---------|
| `pyproject.toml` | PEP 621 project metadata, build-system (pbr), tool configs (mypy, coverage, codespell, autopep8), script/entry points |
| `setup.py` | pbr bootstrap (legacy, calls `setuptools.setup(pbr=True)`) |
| `setup.cfg` | Legacy metadata (name only: `nova`) |
| `requirements.txt` | 64 production dependency lower bounds |
| `test-requirements.txt` | 16 test dependency lower bounds |
| `tox.ini` | 436-line tox configuration with 30+ test environments (unit, functional, pep8, mypy, cover, docs, etc.) |
| `.pre-commit-config.yaml` | Git hooks: trailing-whitespace, autopep8, hacking, codespell, sphinx-lint |
| `HACKING.rst` | Nova-specific style commandments (N3xx lint rules) |
| `.banneker/` | Banneker tool state (gitignored per AGENTS.md convention — ephemeral `.tmp/` used for planning) |

**Additional config files installed with Nova:**
| File | Purpose |
|------|---------|
| `etc/nova/api-paste.ini` | WSGI middleware pipeline configuration |
| `etc/nova/rootwrap.conf` | oslo-rootwrap configuration |
| `etc/nova/rootwrap.d/*` | Privileged command filter lists |
| `nova/db/main/alembic.ini` | Main database migration config |
| `nova/db/api/alembic.ini` | API/database migration config |

---

## Notable Patterns

**Custom abstractions:**
- `nova/manager.py` — `BaseContextManager` base class for service managers with periodic task support
- `nova/baserpc.py` — Custom RPC client wrapper on top of oslo.messaging
- `nova/profiler.py` — Integration with osprofiler for distributed tracing
- `nova/context.py` — Request context with tenant, user, and auth info
- `nova/quota.py` — Quota management with per-tenant enforcement
- `nova/weights.py` — Scheduler weight function system
- `nova/cache_utils.py` — Distributed cache helper with key namespace management
- `nova/filters.py` — Generic filter pattern with `filter_type` attribute

**Virtualization driver interface:**
- `nova/virt/driver.py` — Abstract `FakeVirtAPI` and `ComputeDriver` base class defining the interface all virt drivers must implement
- Stevedore-based driver loading for pluggable backends

**Privilege separation:**
- `nova/privsep/` — oslo.privsep helper scripts that run with elevated privileges (kernel operations, libvirt interaction, mount, qemu management)
- Separates unprivileged API/conductor code from privileged operations

**Scheduler architecture:**
- Two-phase scheduling: Filter chain (exclude unsuitable hosts) → Weight functions (rank remaining hosts)
- 20+ filter plugins in `nova/scheduler/filters/`
- 11 weight functions in `nova/scheduler/weights/`
- Cross-cell scheduling support in `nova/scheduler/client/`

**Concurrent execution:**
- Default: eventlet green threads with monkey patching (applied in `nova/monkey_patch.py`)
- Alternative: native Python threading (`OS_NOVA_DISABLE_EVENTLET_PATCHING=True`)
- Per-service threading environments defined in `tox.ini` (`py313-threading`, `functional-py313-threading`)
- Concurrency safety tested via `NOVA_RAISE_ON_GREENLET_LEAK=True`

**i18n:**
- 12 translated locales: cs, de, es, fr, it, ja, ko_KR, pt_BR, ru, tr_TR, zh_CN, zh_TW
- Translations stored in `nova/locale/*/LC_MESSAGES/nova.po`
- Translation wrapper: `nova.i18n._()` (imported via `hacking` import_exceptions)

**Code organization:**
- No barrel exports (`__init__.py` files are minimal/empty)
- Explicit imports preferred over wildcard imports
- Custom flake8 extension plugin (`nova/hacking/`) with 60+ N3xx checks
- mypy targeted at specific high-risk files listed in `pyproject.toml` (compute/manager.py, virt/libvirt/driver.py, etc.)

**Test structure:**
- Two test suites: `nova/tests/functional/` (integration tests requiring real services) and `nova/tests/unit/` (mocked unit tests)
- 59 unit test files in root-level `nova/tests/unit/`
- API sample tests in `nova/tests/functional/api_sample_tests/`
- Fixture library in `nova/tests/fixtures/`
- Test runner: stestr (never pytest)
- Coverage: `tox -e cover` generates HTML + XML reports

---

## Dependencies Summary

**Key production dependencies (64 total):**
- `pbr` — Build system (setuptools extension)
- `SQLAlchemy` — ORM / database layer
- `eventlet` — Coroutine concurrency
- `oslo_messaging` — RPC transport (RabbitMQ)
- `oslo.config` — Configuration management
- `oslo.log` — Logging
- `oslo_policy` — RBAC policy enforcement
- `oslo_db` — Database session management
- `oslo_versionedobjects` — Versioned domain objects
- `oslo_service` — Service lifecycle
- `oslo_cache` — Distributed caching
- `oslo_concurrency` — Locking coordination
- `oslo_privsep` — Privilege separation
- `keystonemiddleware` — Keystone auth middleware
- `keystoneauth1` — Token validation
- `WebOb` — HTTP framework
- `Routes` — URL routing
- `lxml` — XML parsing
- `cryptography` — Encryption
- `alembic` — Database migrations
- `os-brick` — Volume access
- `os-vif` — Virtual network interfaces
- `python-glanceclient` — Image service client
- `python-neutronclient` — Network service client
- `python-cinderclient` — Block storage client
- `openstacksdk` — OpenStack SDK
- `oslo.rootwrap` — Privileged command execution
- `paramiko` — SSH client (for remote operations)
- `os-resource-classes` — Resource tracking for Placement
- `os-traits` — Compute trait definitions

**Key development dependencies (16 total):**
- `stestr` — Test runner
- `oslotest` — Test fixtures
- `hacking` — OpenStack linting (==8.0.0)
- `coverage` — Code coverage
- `mypy` — Type checking
- `pre-commit` — Git hook management
- `bandit` — Security linting
- `ddt` — Data-driven testing
- `fixtures` — Test fixtures
- `testscenarios` — Test matrix generation
- `testtools` — Extended assertions
- `requests-mock` — HTTP mocking
- `wsgi-intercept` — WSGI interception
- `psycopg2-binary` — PostgreSQL driver
- `PyMySQL` — MySQL driver

---

## Analysis Notes

**Confidence:** High

Project structure is clear and well-documented. Nova is a mature, well-organized OpenStack service with:
- Clear multi-service architecture with documented entry points
- Established coding conventions (HACKING.rst, pre-commit hooks, 60+ custom lint checks)
- Consistent layering (API → domain objects → database)
- Comprehensive test coverage with two test suites (unit + functional)
- Extensive documentation (api-guide, api-ref, releasenotes)
- 12 i18n translations

**Potential gaps:**
- No version tag or VERSION.txt found — actual version is resolved at build time by pbr
- `.zuul.d/` directory not present — CI config may be in a separate opendev repository (standard OpenStack practice)
- Docker/Kubernetes configurations not present — Nova is typically deployed via devstack, Ansible, or Helm charts in separate repositories

**Next steps for onboarding:**
1. Read [HACKING.rst](HACKING.rst) for coding conventions and lint rules
2. Read `doc/source/contributor/repo-overview.rst` for repo layout documentation
3. Review `nova/virt/libvirt/driver.py` (~60KB) to understand the primary virtualization driver
4. Run `tox -e pep8` to verify linting passes
5. Run `tox -e unit` to execute unit test suite
6. Check `etc/nova/api-paste.ini` for WSGI middleware pipeline
7. Review `nova/api/openstack/compute/servers.py` for the main server lifecycle API

---

*Generated by Banneker Cartographer. For questions about this analysis, review the scan logs or re-run `/banneker:document`.*
