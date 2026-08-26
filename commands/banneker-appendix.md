---
name: banneker-appendix
description: "Compile planning documents and architecture diagrams into a self-contained dark-themed HTML appendix. Produces index.html landing page and individual section pages in .banneker/appendix/. Handles missing documents gracefully by generating partial appendix with available content only."
---

# banneker-appendix

CRITICAL INSTRUCTION: When this command says "spawn" or "use the task tool", you MUST call the `task` tool with `subagent_type` parameter. Do NOT try to read agent .md files, do NOT glob for agent files, do NOT perform the work yourself. The `task` tool handles spawning the correct agent.

You are the appendix command orchestrator. Your job is to manage the HTML appendix compilation lifecycle: check prerequisites, detect resume conditions, spawn the publisher sub-agent to compile appendix pages, and verify outputs on completion.

## Step 0: Prerequisite Check (MANDATORY)

Before starting any work, check that required files exist:

### Check for survey.json

Read `.banneker/survey.json`:

```bash
cat .banneker/survey.json 2>/dev/null
```

If `.banneker/survey.json` does NOT exist:
- Display: "No survey data found at .banneker/survey.json"
- Display: "Run /banneker:survey first to conduct a discovery interview."
- Abort and exit (do not proceed)

### Check for architecture-decisions.json

Read `.banneker/architecture-decisions.json`:

```bash
cat .banneker/architecture-decisions.json 2>/dev/null
```

If `.banneker/architecture-decisions.json` does NOT exist:
- Display: "No architecture decisions found at .banneker/architecture-decisions.json"
- Display: "Run /banneker:survey first -- the decision gate phase creates this file."
- Abort and exit (do not proceed)

### Check for shared.css

Verify the design system stylesheet exists:

```bash
test -f .banneker/appendix/shared.css && echo "shared.css: OK"
```

If `.banneker/appendix/shared.css` does NOT exist:
- Display: "No shared.css found at .banneker/appendix/shared.css"
- Display: "The appendix requires shared.css for styling. This file should exist from the package installation."
- Abort and exit (do not proceed)

### Warning for missing source content

Check for planning documents:

```bash
ls .banneker/documents/*.md 2>/dev/null | wc -l
```

If no documents found:
- Display warning: "Warning: No documents found in .banneker/documents/. Run /banneker:architect first for a complete appendix."
- Continue (this is NOT a blocker per REQ-APPENDIX-003)

Check for diagrams:

```bash
ls .banneker/diagrams/*.html 2>/dev/null | wc -l
```

If no diagrams found:
- Display warning: "Warning: No diagrams found in .banneker/diagrams/. Run /banneker:roadmap first for diagram references."
- Continue (this is NOT a blocker per REQ-APPENDIX-003)

## Step 1: Resume Detection (REQ-CONT-002)

Before starting any work, check for existing state:

### Check for interrupted generation

Read `.banneker/state/publisher-state.md` if it exists:

```bash
cat .banneker/state/publisher-state.md 2>/dev/null
```

If the file exists:
1. Parse the state to identify which pages are already complete
2. Extract completed pages list
3. Auto-resume: Proceed to Step 2 with resume context (pass state file content to publisher). Display: "Resuming interrupted appendix. Completed: [list]. Remaining: [list]."

### Check for existing appendix pages

Read existing appendix pages if any:

```bash
ls .banneker/appendix/*.html 2>/dev/null
```

If HTML pages already exist (beyond shared.css) AND no state file:
1. Auto-overwrite: Delete existing HTML pages (keep shared.css), delete state file if exists, proceed to Step 2. Display: "Overwriting existing appendix pages."

If neither state file nor HTML pages exist: Proceed to Step 2 as fresh start.

## Step 2: Create Output Directory

Create the required directories if they don't exist:

```bash
mkdir -p .banneker/appendix
mkdir -p .banneker/state
```

This ensures the publisher can write pages and state files during generation.

## Step 3: Spawn Publisher Sub-Agent

Call the `task` tool (NOT the `skill` tool) with these parameters:

```
task(
  description: "Compile HTML appendix",
  subagent_type: "banneker-publisher",
  prompt: "<context based on resume state>"
)
```

Context to pass:
- **Fresh start**: "Fresh start — no prior state. Begin with Step 0: Check for Resume State."
- **Resuming**: Include content of `.banneker/state/publisher-state.md` with: "Resume from the current state. Skip already-completed pages."
- Also instruct agent to read `.banneker/survey.json`, detect available documents in `.banneker/documents/` and diagrams in `.banneker/diagrams/`, and generate pages to `.banneker/appendix/`.

IMPORTANT: Use the `task` tool, NOT `skill`.
  - Instruct agent to generate only available sections (partial appendix is valid per REQ-APPENDIX-003)

The publisher agent will:
- Load survey.json and architecture-decisions.json
- Detect available documents and diagrams
- Determine which section pages can be generated
- Convert markdown documents to HTML
- Generate section pages (overview, requirements, infrastructure, security-legal, planning-library)
- Generate index.html landing page linking only to available sections
- Write incremental updates to `.banneker/state/publisher-state.md` after each page
- Write final outputs to `.banneker/appendix/[page-name].html`
- Delete state file on successful completion

Wait for the publisher to return.

## Step 4: Verify Outputs

After the publisher returns, verify that outputs were created successfully:

### Verify index.html (must always exist)

Check for index.html:

```bash
test -f .banneker/appendix/index.html && echo "index.html: OK"
```

If index.html does NOT exist:
- Display error: "index.html is missing - appendix generation failed"
- Preserve state file for debugging
- Display: "State file preserved at .banneker/state/publisher-state.md for debugging."
- Display: "To retry: Run /banneker:appendix again to resume from where it stopped."
- Exit with error

### Verify section pages

Check for each expected section page:

```bash
test -f .banneker/appendix/overview.html && echo "overview: OK" || echo "overview: skipped"
test -f .banneker/appendix/requirements.html && echo "requirements: OK" || echo "requirements: skipped"
test -f .banneker/appendix/infrastructure.html && echo "infrastructure: OK" || echo "infrastructure: skipped"
test -f .banneker/appendix/security-legal.html && echo "security-legal: OK" || echo "security-legal: skipped"
test -f .banneker/appendix/planning-library.html && echo "planning-library: OK" || echo "planning-library: skipped"
```

### Count generated pages

Count total HTML pages (excluding shared.css):

```bash
ls .banneker/appendix/*.html 2>/dev/null | wc -l
```

### Display Results

Determine completion status based on generated pages:

**Full appendix (6 HTML pages: index + 5 sections):**

Display completion message:
```
✓ Appendix generation complete!

Generated pages:
  - .banneker/appendix/index.html
  - .banneker/appendix/overview.html
  - .banneker/appendix/requirements.html
  - .banneker/appendix/infrastructure.html
  - .banneker/appendix/security-legal.html
  - .banneker/appendix/planning-library.html

Total: 6 pages generated

All appendix pages use shared.css for consistent dark-theme styling.

Next steps:
  - Open .banneker/appendix/index.html in a browser to view the appendix
  - Run /banneker:feed to export planning artifacts to downstream frameworks
```

**Partial appendix (index + 2-4 sections, minimum viable):**

Display partial completion message:
```
✓ Partial appendix generated!

Generated pages:
  - .banneker/appendix/index.html
  [list generated section pages]

Skipped pages:
  [list skipped pages with reason]

Total: [N] pages generated

This is a partial appendix due to missing source content. The generated pages are fully functional.

Recommendations:
  - Run /banneker:architect to generate missing planning documents
  - Run /banneker:roadmap to generate architecture diagrams
  - Re-run /banneker:appendix after generating missing content for a complete appendix

Next step:
  - Open .banneker/appendix/index.html in a browser to view the appendix
```

**Minimal appendix (index + 1 section only):**

Display minimal completion message:
```
✓ Minimal appendix generated!

Generated pages:
  - .banneker/appendix/index.html
  [list generated section page]

Skipped pages:
  [list skipped pages with reason]

Total: [N] pages generated

This is a minimal appendix. Most sections require planning documents or diagrams.

Recommendations:
  - Run /banneker:architect to generate planning documents
  - Run /banneker:roadmap to generate architecture diagrams
  - Re-run /banneker:appendix after generating content for a complete appendix

Next step:
  - Open .banneker/appendix/index.html in a browser to view the appendix
```

The partial appendix outcome is VALID per REQ-APPENDIX-003 — not an error condition.

## Step 5: Clean Up State (on completion)

If index.html and at least 2 section pages were verified (minimum viable appendix):

```bash
rm -f .banneker/state/publisher-state.md
```

Display final summary with file paths:
```
Appendix files saved to .banneker/appendix/

File paths:
  - .banneker/appendix/index.html
  [list all generated section pages with full paths]

Open index.html in a browser to navigate the appendix.
```

If index.html is missing OR fewer than 2 section pages exist:
- Preserve state file for debugging
- Display error with debugging guidance

## Important Implementation Notes

- This skill file runs inside an AI runtime (Claude Code, OpenCode, Gemini). All file operations (mkdir, cat, ls, wc, rm, test) are executed via the runtime's Bash tool.
- The orchestrator is lean - all HTML generation logic lives in the `banneker-publisher` agent, not here.
- Resume detection (Step 1) is MANDATORY per REQ-CONT-002 - never skip this step.
- Partial appendix is a NORMAL outcome per REQ-APPENDIX-003 when documents or diagrams are missing, not a failure.
- The state file is the publisher's responsibility to write/update/delete, not the orchestrator's.
- This file is the user-facing entry point for `/banneker:appendix` - keep error messages helpful and actionable.

## Requirements Coverage

- **REQ-CONT-001**: State tracking via `.banneker/state/publisher-state.md` (publisher writes, orchestrator reads)
- **REQ-CONT-002**: Resume detection in Step 1 (checks state file and existing pages before starting)
- **REQ-APPENDIX-001**: Verification of index.html and section pages in Step 4
- **REQ-APPENDIX-002**: Dark-theme self-contained pages via shared.css (orchestrator verifies shared.css prerequisite, publisher references it)
- **REQ-APPENDIX-003**: Partial appendix generation handled gracefully with clear user messaging about missing content
