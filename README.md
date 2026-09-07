# Banneker Runner

Reusable scripts for [Banneker](https://www.npmjs.com/package/banneker) — analyze any codebase and generate architecture docs, diagrams, and planning artifacts.

Optimized for large repositories and resource-constrained machines: the cartographer uses tiered/sampled analysis, the architect passes sliced context to writers instead of raw files, and artifacts can be exported as an OKF knowledge bundle for progressive disclosure (agents load only the concepts they need, keeping context small).

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
| `feed` | Export to downstream frameworks (incl. OKF bundle) | `survey.json` |
| `okf` | Generate standalone OKF knowledge bundle | `survey.json` |
| `audit` | Evaluate plans against completeness rubric | Planning documents |

## CLI (Interactive)

```bash
./banneker-run.sh --target /path/to/project document
./banneker-run.sh --target /path/to/project all
```

## OKF (Open Knowledge Format) Integration

Banneker can export all planning artifacts as an **OKF knowledge bundle** (`.banneker/knowledge/`), a version-controllable directory of concept files with YAML frontmatter. This gives downstream agents **progressive disclosure**: they browse the index (`okf_list`) and read only the concepts they need (`okf_read`/`okf_search`) instead of loading the whole corpus, then unload them later — ideal for limited-context models.

- **OKF command**: `/banneker:okf` generates a standalone OKF bundle from survey data (no architect step required). Ideal for context-efficient agent consumption.
- **Feed step**: `/banneker:feed` generates the OKF bundle alongside GSD/prompt/summary/context-bundle exports.
- **Plugin**: an `opencode-okf-context` plugin config ships in `opencode.json` + `.opencode/okf.jsonc` (tuned with sensible unload/nudge defaults for constrained machines).
- **Skill**: `.opencode/skills/okf/` contains a SKILL.md that teaches agents how to author and consume OKF bundles, with `reference/` docs and helper scripts.

```bash
# Consume the bundle with the okf CLI
npx -p opencode-okf-context okf list --root .banneker/knowledge
npx -p opencode-okf-context okf search architecture --root .banneker/knowledge
npx -p opencode-okf-context okf read documents/stack --root .banneker/knowledge
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

`.opencode/` contains the OKF integration (skill + plugin config), which the pipeline also overlays onto targets so installed Banneker instances support progressive-disclosure knowledge bundles.
