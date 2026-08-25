# Banneker Runner

A reusable wrapper for [Banneker](https://www.npmjs.com/package/banneker) — project planning and documentation pipeline for AI coding assistants.

## Quick Start

```bash
# Clone this repo anywhere
git clone <your-repo-url> ~/my-banneker

# Install Banneker into your project
cd ~/my-banneker
./setup.sh /path/to/your/project

# Run Banneker from your project directory
cd /path/to/your/project
~/my-banneker/banneker-run.sh document
```

## What It Does

Banneker analyzes your codebase and generates:
- **Architecture documentation** — codebase-understanding.md
- **Visual diagrams** — executive roadmap, system architecture, decision maps, wiring diagrams (HTML)
- **HTML appendix** — a browsable website of your project's architecture
- **Exportable artifacts** — markdown and JSON for feeding into other AI tools

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

1. `setup.sh` runs `npx banneker --opencode --local` to install Banneker commands into the target project
2. `banneker-run.sh` invokes opencode with the appropriate Banneker command
3. Banneker agents analyze your code and generate output in `.banneker/`

**Important:** Run `banneker-run.sh` from the target project directory (where Banneker was installed), not from this repo.
