---
name: banneker-feed
description: "Export Banneker planning artifacts into downstream framework formats. Produces GSD planning files (.planning/), platform prompt, generic summary, and context bundle. Run after /banneker:architect to transform documents into consumable exports."
---

# banneker-feed

CRITICAL INSTRUCTION: When this command says "spawn" or "use the task tool", you MUST call the `task` tool with `subagent_type` parameter. Do NOT try to read agent .md files, do NOT glob for agent files, do NOT perform the work yourself. The `task` tool handles spawning the correct agent.

You are the feed command orchestrator. Your job is to manage the export lifecycle: check prerequisites, detect resume conditions, spawn the exporter sub-agent to generate export files, and verify outputs on completion.

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
- Display: "Run /banneker:survey first — the decision gate phase creates this file."
- Abort and exit (do not proceed)

### Warning for missing documents

Check for planning documents:

```bash
ls .banneker/documents/*.md 2>/dev/null | wc -l
```

If no documents found:
- Display warning: "Warning: No documents found in .banneker/documents/. Run /banneker:architect first for complete exports."
- Display: "The GSD format can still be generated from survey data alone, but other formats will be limited."
- Continue (this is NOT a blocker — GSD format works without documents)

## Step 1: Resume Detection (REQ-CONT-002)

Before starting any work, check for existing state:

### Check for interrupted export

Read `.banneker/state/export-state.md` if it exists:

```bash
cat .banneker/state/export-state.md 2>/dev/null
```

If the file exists:
1. Parse the state to identify which formats are already complete
2. Extract completed formats list and remaining formats list
3. Auto-resume: Proceed to Step 2 with resume context (pass state file content to exporter). Display: "Resuming interrupted export. Completed: [list]. Remaining: [list]."

### Check for existing export outputs

Check for existing GSD format outputs:

```bash
test -f .planning/PROJECT.md && echo "PROJECT.md: exists"
test -f .planning/REQUIREMENTS.md && echo "REQUIREMENTS.md: exists"
test -f .planning/ROADMAP.md && echo "ROADMAP.md: exists"
```

Check for other format outputs:

```bash
test -f .banneker/exports/platform-prompt.md && echo "platform-prompt.md: exists"
test -f .banneker/exports/summary.md && echo "summary.md: exists"
test -f .banneker/exports/context-bundle.md && echo "context-bundle.md: exists"
```

If ALL 4 formats exist (GSD = 3 files, platform prompt = 1 file, summary = 1 file, context bundle = 1 file):
1. Auto-overwrite: Delete existing exports (keep directories), delete state file if exists, proceed to Step 2. Display: "All export formats already generated. Overwriting."

If SOME formats exist (but not all):
1. Auto-complete: Proceed to Step 2 with partial resume context (pass list of missing formats to exporter). Display: "Partial exports found. Completing remaining formats."

If NO exports exist AND no state file: Proceed to Step 2 as fresh start.

## Step 2: Ensure Directory Structure

Create the required directories if they don't exist:

```bash
mkdir -p .planning
mkdir -p .banneker/exports
mkdir -p .banneker/state
```

This ensures the exporter can write export files and state files during generation.

### Write initial state file

Create `.banneker/state/export-state.md`:

```markdown
# Export State

status: in_progress
started: [ISO date from `date -u +"%Y-%m-%dT%H:%M:%SZ"`]
formats_requested: [gsd, platform_prompt, generic_summary, context_bundle]
formats_completed: []
```

## Step 3: Spawn Exporter Sub-Agent

Call the `task` tool (NOT the `skill` tool) with these parameters:

```
task(
  description: "Export planning artifacts",
  subagent_type: "banneker-exporter",
  prompt: "<context based on resume state>"
)
```

Context to pass:
- **Fresh start**: "Fresh start — no prior state. Generate all 4 formats: GSD, platform prompt, generic summary, context bundle."
- **Resuming**: Include content of `.banneker/state/export-state.md` with: "Resume from the current state. Skip already-completed formats."
- Also instruct agent to read `.banneker/survey.json`, detect available documents in `.banneker/documents/`, and reference `@config/framework-adapters.md`.

IMPORTANT: Use the `task` tool, NOT `skill`.
  - Instruct agent to write outputs to `.planning/` (GSD) and `.banneker/exports/` (others)
  - Instruct agent to update `.banneker/state/export-state.md` after each format completes

The exporter agent will:
- Load survey.json and architecture-decisions.json
- Detect available documents and diagrams
- Generate GSD format (PROJECT.md, REQUIREMENTS.md, ROADMAP.md) to `.planning/`
- Generate platform prompt to `.banneker/exports/platform-prompt.md`
- Generate generic summary to `.banneker/exports/summary.md`
- Generate context bundle to `.banneker/exports/context-bundle.md`
- Write incremental updates to `.banneker/state/export-state.md` after each format
- Delete state file on successful completion

Wait for the exporter to return.

## Step 4: Verify Outputs

After the exporter returns, verify that outputs were created successfully:

### Verify GSD format outputs (always required)

Check for PROJECT.md:

```bash
test -f .planning/PROJECT.md && echo "PROJECT.md: OK" || echo "PROJECT.md: MISSING"
```

Verify PROJECT.md contains project name from survey:

```bash
grep -i "project" .planning/PROJECT.md | head -5
```

Check for REQUIREMENTS.md:

```bash
test -f .planning/REQUIREMENTS.md && echo "REQUIREMENTS.md: OK" || echo "REQUIREMENTS.md: MISSING"
```

Verify REQUIREMENTS.md contains REQ- prefixed requirements:

```bash
grep -c "REQ-" .planning/REQUIREMENTS.md
```

Check for ROADMAP.md:

```bash
test -f .planning/ROADMAP.md && echo "ROADMAP.md: OK" || echo "ROADMAP.md: MISSING"
```

Verify ROADMAP.md contains milestone structure:

```bash
grep -i "milestone\|phase" .planning/ROADMAP.md | head -5
```

### Verify Platform Prompt output

Check for platform-prompt.md:

```bash
test -f .banneker/exports/platform-prompt.md && echo "platform-prompt.md: OK" || echo "platform-prompt.md: MISSING"
```

Verify word count is under 4,000:

```bash
wc -w .banneker/exports/platform-prompt.md
```

### Verify Generic Summary output

Check for summary.md:

```bash
test -f .banneker/exports/summary.md && echo "summary.md: OK" || echo "summary.md: MISSING"
```

Verify summary.md contains source comments (proving concatenation happened):

```bash
grep -c "<!-- Source:" .banneker/exports/summary.md
```

### Verify Context Bundle output

Check for context-bundle.md:

```bash
test -f .banneker/exports/context-bundle.md && echo "context-bundle.md: OK" || echo "context-bundle.md: MISSING"
```

Verify context-bundle.md contains survey data:

```bash
grep -i "survey" .banneker/exports/context-bundle.md | head -5
```

### Display Results

Determine completion status based on verified outputs:

**Full export (all 4 formats complete):**

Display completion message:
```
✓ Export complete!

Generated formats:

GSD Format (.planning/):
  - PROJECT.md ([size])
  - REQUIREMENTS.md ([size] — [N] requirements)
  - ROADMAP.md ([size] — [N] milestones)

Platform Prompt (.banneker/exports/):
  - platform-prompt.md ([size] — [N] words)

Generic Summary (.banneker/exports/):
  - summary.md ([size])

Context Bundle (.banneker/exports/):
  - context-bundle.md ([size])

All export formats generated successfully.

Next steps:
  - Review GSD files in .planning/ for project planning
  - Use platform-prompt.md for AI platform context
  - Use context-bundle.md for LLM agent context
```

**Partial export (some formats failed):**

Display partial completion message:
```
⚠ Partial export complete

Generated formats:
  [list successful formats with file paths and sizes]

Failed formats:
  [list failed formats with reason]

State file preserved at .banneker/state/export-state.md for debugging.

To retry: Run /banneker:feed again to complete remaining formats.
```

**Minimal export (GSD only, requires documents for other formats):**

Display minimal completion message:
```
✓ Minimal export complete

Generated formats:

GSD Format (.planning/):
  - PROJECT.md ([size])
  - REQUIREMENTS.md ([size] — [N] requirements)
  - ROADMAP.md ([size] — [N] milestones)

Skipped formats:
  - Platform Prompt (requires documents)
  - Generic Summary (requires documents)
  - Context Bundle (limited without documents)

The GSD format was successfully generated from survey data.

Recommendations:
  - Run /banneker:architect to generate planning documents
  - Re-run /banneker:feed after generating documents for complete exports

Next step:
  - Review GSD files in .planning/ for project planning
```

## Step 5: Clean Up State (on completion)

If all 4 formats were verified successfully:

```bash
rm -f .banneker/state/export-state.md
```

Display final summary with file paths and sizes:
```
Export files saved to .planning/ and .banneker/exports/

GSD Format:
  - .planning/PROJECT.md
  - .planning/REQUIREMENTS.md
  - .planning/ROADMAP.md

Other Formats:
  - .banneker/exports/platform-prompt.md
  - .banneker/exports/summary.md
  - .banneker/exports/context-bundle.md

Use these exports to feed downstream planning frameworks and AI platforms.
```

If any format failed:
- Preserve state file for debugging
- Display error with debugging guidance
- Suggest running /banneker:architect to generate missing documents if that's the blocker

## Important Implementation Notes

- This skill file runs inside an AI runtime (Claude Code, OpenCode, Gemini). All file operations (mkdir, cat, ls, wc, rm, test, grep) are executed via the runtime's Bash tool.
- The orchestrator is lean - all export generation logic lives in the `banneker-exporter` agent, not here.
- Resume detection (Step 1) is MANDATORY per REQ-CONT-002 - never skip this step.
- GSD format is always generated (only requires survey.json), but other formats benefit from documents.
- Minimal export (GSD only) is a NORMAL outcome when documents are missing, not a failure.
- The state file is the exporter's responsibility to write/update/delete, not the orchestrator's.
- This file is the user-facing entry point for `/banneker:feed` - keep error messages helpful and actionable.

## Requirements Coverage

- **REQ-CONT-001**: State tracking via `.banneker/state/export-state.md` (exporter writes, orchestrator reads)
- **REQ-CONT-002**: Resume detection in Step 1 (checks state file and existing exports before starting)
- **REQ-EXPORT-001**: GSD format verification (PROJECT.md, REQUIREMENTS.md, ROADMAP.md with REQ-ID format)
- **REQ-EXPORT-002**: Platform prompt verification (under 4,000 words)
- **REQ-EXPORT-003**: Generic summary verification (source comments proving concatenation)
- **REQ-EXPORT-004**: Context bundle verification (survey data inclusion)
