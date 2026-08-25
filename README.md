# Banneker Runner

A reusable wrapper for [Banneker](https://www.npmjs.com/package/banneker) — project planning and documentation pipeline for AI coding assistants.

## Quick Start

```bash
# Clone this repo anywhere
git clone <your-repo-url> ~/my-banneker
cd ~/my-banneker

# Run against the current project
./banneker-run.sh document

# Or run against any local directory
./banneker-run.sh --target /path/to/project all
```

## What It Does

Banneker analyzes your codebase and generates:
- **Architecture documentation** — codebase-understanding.md
- **Planning documents** — technical summary, stack analysis, infrastructure architecture
- **Visual diagrams** — executive roadmap, system architecture, decision maps, wiring diagrams (HTML)
- **HTML appendix** — a browsable website of your project's architecture
- **Exportable artifacts** — markdown and JSON for feeding into other AI tools

## Scripts

| Script | Purpose |
|--------|---------|
| `banneker-run.sh` | Interactive CLI wrapper — run individual commands manually |
| `banneker-pipeline.sh` | CI/CD automation — runs steps and commits results back |

## Flags

| Flag | Description |
|------|-------------|
| `--target <path>` | Run against a specific local directory |

## Commands

| Command | Description | Prerequisites |
|---------|-------------|---------------|
| `document` | Analyze existing codebase, produce `codebase-understanding.md` | None |
| `survey` | Interactive discovery interview, produce `survey.json` | None (interactive) |
| `architect` | Generate planning documents from survey data | `survey.json` (auto-generated if missing) |
| `roadmap` | Generate architecture diagrams (HTML) | `survey.json` |
| `appendix` | Compile HTML reference site | Documents + diagrams |
| `feed` | Export to downstream frameworks (GSD, prompts, etc.) | `survey.json` |
| `audit` | Evaluate planning documents against completeness rubric | Planning documents |
| `all` | Run document → roadmap → appendix | None (fast path) |

### Recommended sequences

```bash
# Full analysis (new project)
./banneker-run.sh --target /path/to/project document
./banneker-run.sh --target /path/to/project survey     # interactive
./banneker-run.sh --target /path/to/project architect
./banneker-run.sh --target /path/to/project roadmap
./banneker-run.sh --target /path/to/project appendix

# Quick analysis (existing project, skip survey)
./banneker-run.sh --target /path/to/project all

# Pipeline mode (automated, no interactive steps)
./banneker-pipeline.sh   # see Pipeline section below
```

## Pipeline (CI/CD Automation)

`banneker-pipeline.sh` is a platform-agnostic script for running Banneker in any CI/CD system.

### Usage

```bash
# Basic: analyze a repo and commit results
TARGET_DIR=/path/to/repo ./banneker-pipeline.sh

# Custom branch and steps
TARGET_DIR=/path/to/repo BRANCH=docs/auto BANNEKER_STEPS=document,architect ./banneker-pipeline.sh

# Dry run (no commit)
TARGET_DIR=/path/to/repo SKIP_COMMIT=true ./banneker-pipeline.sh
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TARGET_DIR` | *(required)* | Path to the repository to analyze |
| `BRANCH` | `banneker/auto-docs` | Branch to commit results back to |
| `BANNEKER_STEPS` | `document,architect` | Comma-separated steps: `document`, `survey`, `architect`, `roadmap`, `appendix`, `feed`, `audit` |
| `SKIP_COMMIT` | `false` | Set to `true` to skip git commit/push |
| `OPENCODE_BIN` | `opencode` | Path to opencode binary |
| `GIT_USER_EMAIL` | `banneker-bot[bot]@users.noreply.github.com` | Git commit author email |
| `GIT_USER_NAME` | `banneker-bot` | Git commit author name |

### How it works

1. **Installs Banneker** in the target repo (if `.opencode/commands/` doesn't exist)
2. **Runs each step** sequentially via `opencode run --command`
3. **Auto-generates `survey.json`** from codebase analysis if missing (enables `architect` without interactive interview)
4. **Commits results** to a dedicated branch (`banneker/auto-docs` by default)

### GitHub Actions

A reference workflow is provided at `.github/workflows/banneker.yml`:

```yaml
# Trigger manually with target repo input
# Or push to this repo to auto-analyze a default target
```

To use it in your repo:

1. Copy `.github/workflows/banneker.yml` to your repo
2. Set the `OPENCODE_MODEL` env var (or configure your provider)
3. Add your API key as a repository secret (e.g., `ANTHROPIC_API_KEY`)
4. Trigger via Actions → Banneker Analysis → Run workflow

### Other CI systems

The script works with any CI. Examples:

**GitLab CI:**
```yaml
banneker:
  image: node:20
  script:
    - npm install -g opencode
    - git clone --depth 1 "$TARGET_REPO" /tmp/target
    - TARGET_DIR=/tmp/target ./banneker-pipeline.sh
  artifacts:
    paths:
      - /tmp/target/.banneker/
```

**Jenkins:**
```groovy
stage('Banneker') {
  sh 'npm install -g opencode'
  sh 'git clone --depth 1 ${TARGET_REPO} /tmp/target'
  sh 'TARGET_DIR=/tmp/target ./banneker-pipeline.sh'
  archiveArtifacts artifacts: '/tmp/target/.banneker/**'
}
```

## Output Structure

After running, Banneker generates output in `.banneker/`:

```
.banneker/
├── codebase-understanding.md      # Documented codebase analysis
├── survey.json                    # Structured project data
├── architecture-decisions.json    # Key architectural decisions
├── documents/
│   ├── TECHNICAL-SUMMARY.md       # High-level technical overview
│   ├── STACK.md                   # Technology stack analysis
│   └── INFRASTRUCTURE-ARCHITECTURE.md  # Infrastructure design
├── diagrams/
│   ├── executive-roadmap.html     # Visual project roadmap
│   ├── decision-map.html          # Architecture decision tree
│   ├── system-map.html            # System component map
│   └── architecture-wiring.html   # Integration wiring diagram
├── appendix/
│   ├── index.html                 # Landing page
│   └── *.html                     # Section pages
└── state/                         # Resume state (cleaned up on completion)
```

## View Output

```bash
# Open the HTML appendix
xdg-open .banneker/appendix/index.html

# Open individual diagrams
xdg-open .banneker/diagrams/executive-roadmap.html
xdg-open .banneker/diagrams/system-map.html
```

## Requirements

- Node.js >= 18.0.0
- opencode installed and configured (`npm install -g opencode`)
- API key for your model provider (set via `opencode auth login` or env vars)

## How It Works

1. **Local mode:** Run from a project directory where Banneker is installed
2. **Target mode:** Use `--target <path>` to run against any local directory
3. **Pipeline mode:** Use `banneker-pipeline.sh` for CI/CD automation
4. Banneker agents analyze your code and generate output in `.banneker/`
5. In pipeline mode, results are committed back to a dedicated branch
