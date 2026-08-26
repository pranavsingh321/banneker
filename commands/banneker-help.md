---
name: banneker-help
description: "Display Banneker command reference with all available commands, categories, and usage examples"
---

# banneker-help

You are the help command for Banneker. Your job is to display a comprehensive command reference that helps users discover and understand all available Banneker commands.

## Step 1: Dynamic Command Discovery

Attempt to dynamically discover installed commands:

```bash
ls ~/.claude/commands/banneker-*.md 2>/dev/null
```

If commands are found, extract command information from each file:

```bash
for cmd in ~/.claude/commands/banneker-*.md; do
  echo "=== $(basename "$cmd") ==="
  head -20 "$cmd" | grep -A 1 "^name:" | head -2
  head -20 "$cmd" | grep -A 1 "^description:" | head -2
  echo ""
done
```

Parse the frontmatter to extract `name` and `description` fields from each discovered command.

## Step 2: Display Categorized Command Reference

Display the Banneker command reference organized by category. If dynamic discovery failed or yielded no results, fall back to the hardcoded reference below:

```
# Banneker Command Reference

Banneker transforms structured discovery interviews into engineering plans, architecture diagrams, and agent-ready documentation.

## Available Commands

### Discovery
- **/banneker:survey** — Conduct 6-phase structured discovery interview
  - Collects project pitch, actors, walkthroughs, backend details, gaps, and architecture decisions
  - Outputs: survey.json, architecture-decisions.json
  - Supports resume on interruption

### Planning
- **/banneker:architect** — Generate planning documents from survey data
  - Creates 3-10 documents based on project type (always: TECHNICAL-SUMMARY, STACK, INFRASTRUCTURE-ARCHITECTURE)
  - Validates for zero placeholders and consistent naming
  - Supports resume on interruption

- **/banneker:document** — Analyze existing codebase (brownfield projects)
  - Progressive scanning: metadata → structure → technology → architecture
  - Generates technical summary without requiring prior survey
  - Supports resume on large codebases

- **/banneker:audit** — Evaluate planning documents against completeness rubric
  - 10-category evaluation: roles, data model, API surface, auth, infrastructure, errors, testing, security, performance, deployment
  - Fuzzy matching with 2+ detection terms per criterion
  - Dual output: audit-report.json + audit-report.md

### Visualization
- **/banneker:roadmap** — Generate HTML architecture diagrams
  - Creates 3-4 self-contained HTML diagrams: System Architecture, Data Flow, API Surface, Tech Stack
  - CSS Grid layouts with inlined styles, no external dependencies
  - Supports wave-based generation (Wave 1: CSS-only, Wave 2: interactive JS)

- **/banneker:appendix** — Compile HTML reference from documents and diagrams
  - Generates navigable appendix with index + 6 section pages
  - Accordion UI for collapsible content
  - Supports partial generation (warns on missing content, continues with available)

### Export
- **/banneker:feed** — Export to downstream frameworks
  - 4 export formats: GSD (Get Shit Done), Platform Prompt, Generic Summary, Context Bundle
  - Framework-specific adapters for each format
  - All exports generated in single pass

### Utilities
- **/banneker:help** — Display this command reference
  - Dynamically discovers installed commands
  - Categorized listing with usage examples
  - Quick start workflow

- **/banneker:progress** — Show current workflow state
  - Reads state files from .banneker/state/
  - Displays in-progress commands, pending handoffs, completed outputs
  - Recommends next steps based on project state

- **/banneker:plat** — Generate sitemap and route architecture
  - Analyzes project structure to identify routes and pages
  - Creates hierarchical sitemap visualization
  - Useful for frontend-heavy applications
```

If dynamic discovery yielded no results, append this note:

```
Note: Command list is from built-in reference. Run from an environment with Banneker installed for dynamic discovery.
```

## Step 3: Display Quick Start Workflow

Show the recommended workflow sequence for new users:

```
## Quick Start Workflow

For new projects (greenfield):

1. **/banneker:survey** — Conduct discovery interview
   - Answer questions about your project vision, actors, and key flows
   - Results: survey.json, architecture-decisions.json

2. **/banneker:architect** — Generate planning documents
   - Automatically determines which documents to create based on project type
   - Results: 3-10 markdown documents in .banneker/documents/

3. **/banneker:roadmap** — Create architecture diagrams
   - Generates self-contained HTML diagrams from planning documents
   - Results: 3-4 diagrams in .banneker/diagrams/

4. **/banneker:appendix** — Compile HTML reference
   - Creates navigable appendix combining documents and diagrams
   - Results: index.html + section pages in .banneker/appendix/

5. **/banneker:feed** — Export to downstream frameworks
   - Generates framework-specific exports (GSD, platform prompts, etc.)
   - Results: 4 export formats in .banneker/exports/

6. **/banneker:progress** — Check workflow status anytime
   - Shows what's complete, what's in progress, what's next

For existing codebases (brownfield):

1. **/banneker:document** — Analyze existing codebase
   - Scans codebase to generate technical summary and architecture overview
   - Alternative to survey for brownfield projects

2. Follow steps 3-6 above (roadmap → appendix → feed → progress)

For plan evaluation:

- **/banneker:audit** — Evaluate existing planning documents
  - Works with GSD, Banneker, or standalone plan files
  - Identifies gaps and provides actionable recommendations
```

## Step 4: Display Version Information

Read and display the Banneker version:

```bash
cat ~/.claude/banneker/VERSION 2>/dev/null || echo "0.2.0 (development)"
```

Display version information:

```
## Version

Banneker v[VERSION]

For updates and documentation:
- GitHub: [repository URL if available]
- npm: banneker
```

## Step 5: Exit

Display a friendly closing message:

```
---

Need help with a specific command? Each command supports resume on interruption and provides detailed progress feedback.

Run /banneker:survey to get started!
```

Exit successfully.

## Important Implementation Notes

- This is a stateless, read-only command — no state tracking or resume detection needed
- Dynamic discovery is best-effort — always fall back to hardcoded reference if filesystem access fails
- All file operations (ls, cat, grep, head) are executed via the runtime's Bash tool
- Keep the output concise but comprehensive — users should understand all available commands at a glance
- The categorized structure (Discovery → Planning → Visualization → Export → Utilities) helps users understand the workflow progression
