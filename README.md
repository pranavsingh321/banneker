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
- **Visual diagrams** — executive roadmap, system architecture, decision maps, wiring diagrams (HTML)
- **HTML appendix** — a browsable website of your project's architecture
- **Exportable artifacts** — markdown and JSON for feeding into other AI tools

## Flags

| Flag | Description |
|------|-------------|
| `--target <path>` | Run against a specific local directory |

## Commands

| Command | Description |
|---------|-------------|
| `./banneker-run.sh document` | Analyze existing codebase |
| `./banneker-run.sh survey` | Discovery interview (new projects) |
| `./banneker-run.sh architect` | Generate planning documents |
| `./banneker-run.sh roadmap` | Generate architecture diagrams |
| `./banneker-run.sh appendix` | Compile HTML reference |
| `./banneker-run.sh feed` | Export to downstream frameworks |
| `./banneker-run.sh audit` | Evaluate planning documents |
| `./banneker-run.sh all` | Run document → roadmap → appendix (default) |

## View Output

After running, open the generated diagrams:
```bash
xdg-open .banneker/diagrams/executive-roadmap.html
xdg-open .banneker/diagrams/decision-map.html
xdg-open .banneker/diagrams/system-map.html
xdg-open .banneker/diagrams/architecture-wiring.html
```

## Requirements

- Node.js >= 18.0.0
- opencode installed and configured

## How It Works

1. **Local mode:** Run from a project directory where Banneker is installed
2. **Target mode:** Use `--target <path>` to run against any local directory
3. Banneker agents analyze your code and generate output in `.banneker/`
