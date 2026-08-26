# Banneker Runner

Reusable scripts for [Banneker](https://www.npmjs.com/package/banneker) — analyze any codebase and generate architecture docs, diagrams, and planning artifacts.

## Requirements

- Node.js >= 18
- `opencode` installed (`npm install -g opencode`)
- API key configured (`opencode auth login` or env vars)

## Scripts

| Script | Purpose |
|--------|---------|
| `banneker-pipeline.sh` | Automated analysis — run steps, save results locally |
| `banneker-run.sh` | Interactive CLI — run individual commands manually |

## Pipeline

Runs against any repo and saves results to `banneker-output/<target-name>/`.

```bash
# Basic
TARGET_DIR=~/repos/nova ./banneker-pipeline.sh

# Full analysis
TARGET_DIR=~/repos/nova BANNEKER_STEPS=document,architect,roadmap,appendix ./banneker-pipeline.sh

# Custom output location
TARGET_DIR=~/repos/nova OUTPUT_DIR=~/reports/nova ./banneker-pipeline.sh
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TARGET_DIR` | *(required)* | Repository to analyze |
| `OUTPUT_DIR` | `./banneker-output/<target-name>` | Where to save results |
| `BANNEKER_STEPS` | `document,architect` | Steps to run (comma-separated) |
| `OPENCODE_BIN` | `opencode` | Path to opencode binary |

### Available Steps

| Step | Description | Prerequisites |
|------|-------------|---------------|
| `document` | Analyze codebase, produce `codebase-understanding.md` | None |
| `survey` | Interactive discovery interview, produce `survey.json` | None |
| `architect` | Generate planning documents | Auto-generates `survey.json` if missing |
| `roadmap` | Generate architecture diagrams (HTML) | `survey.json` |
| `appendix` | Compile HTML reference site | Documents + diagrams |
| `feed` | Export to downstream frameworks | `survey.json` |
| `audit` | Evaluate plans against completeness rubric | Planning documents |

## CLI (Interactive)

```bash
./banneker-run.sh --target /path/to/project document
./banneker-run.sh --target /path/to/project all
```

## Output

```
banneker-output/<target-name>/
├── codebase-understanding.md
├── survey.json
├── architecture-decisions.json
├── documents/
│   ├── TECHNICAL-SUMMARY.md
│   ├── STACK.md
│   └── INFRASTRUCTURE-ARCHITECTURE.md
├── diagrams/
│   ├── executive-roadmap.html
│   ├── decision-map.html
│   ├── system-map.html
│   └── architecture-wiring.html
└── appendix/
    ├── index.html
    └── *.html
```

## Bundled Files

`commands/` and `agents/` contain fixed Banneker command/agent definitions that get overlaid onto the target repo during pipeline runs. These fix path issues and remove interactive prompts for CI/CD use.
