---
name: banneker-plat
description: "Generate sitemap and route architecture documentation from survey walkthrough data. Extracts routes, endpoints, and navigation flows grouped by actor and feature area."
---

# banneker-plat

CRITICAL INSTRUCTION: When this command says "spawn" or "use the task tool", you MUST call the `task` tool with `subagent_type` parameter. Do NOT try to read agent .md files, do NOT glob for agent files, do NOT perform the work yourself. The `task` tool handles spawning the correct agent.

You are the plat command orchestrator. Your job is to manage the route architecture generation lifecycle: check prerequisites, detect resume conditions, spawn the plat-generator sub-agent to extract routes and generate documentation, and verify outputs on completion.

## Step 0: Prerequisite Check (MANDATORY)

Before starting any work, check that survey data exists:

### Check for survey.json

Read `.banneker/survey.json`:

```bash
cat .banneker/survey.json 2>/dev/null
```

If `.banneker/survey.json` does NOT exist:
- Display: "No survey data found at .banneker/survey.json"
- Display: "Run /banneker:survey first to conduct a discovery interview."
- Abort and exit (do not proceed)

## Step 1: Resume Detection (REQ-CONT-002)

Before starting any work, check for existing state:

### Check for interrupted generation

Read `.banneker/state/plat-state.md` if it exists:

```bash
cat .banneker/state/plat-state.md 2>/dev/null
```

If the file exists:
1. Parse the state to identify which documents are already complete
2. Extract the list of completed documents and remaining documents
3. Auto-resume: Proceed to Step 2 with resume context (pass state file content to plat-generator). Display: "Resuming interrupted route architecture generation. Completed: [list]. Remaining: [list]."

### Check for existing route documentation

Read existing documents if any:

```bash
cat .banneker/documents/sitemap.md 2>/dev/null
cat .banneker/documents/route-architecture.md 2>/dev/null
```

If both documents already exist AND no state file:
1. Auto-overwrite: Proceed to Step 2 as fresh start. Display: "Existing route documentation found. Regenerating from scratch."

If only one document exists (partial completion):
1. Auto-complete: Proceed to Step 2 with partial resume context. Display: "Partial route documentation found. Completing remaining documents."

If neither state file nor documents exist: Proceed to Step 2 as fresh start.

## Step 2: Ensure Directory Structure

Create the required directories if they don't exist:

```bash
mkdir -p .banneker/documents
mkdir -p .banneker/state
```

This ensures the plat-generator can write documents and state files during generation.

## Step 3: Spawn Plat Generator Sub-Agent

Call the `task` tool (NOT the `skill` tool) with these parameters:

```
task(
  description: "Generate platform architecture docs",
  subagent_type: "banneker-plat-generator",
  prompt: "<context based on resume state>"
)
```

Context to pass:
- **Fresh start**: "Fresh start — no prior state. Begin with Step 1: Load and Parse Survey Data."
- **Resuming**: Include content of `.banneker/state/plat-state.md` with: "Resume from the current state. Skip already-completed documents."
- **Partial resume**: List existing documents with: "Complete missing documents. Existing: [list]."

IMPORTANT: Use the `task` tool, NOT `skill`.

The plat-generator agent will:
- Load survey.json (and optionally architecture-decisions.json for enrichment)
- Extract routes from walkthrough steps (action and system_response fields)
- Group routes by actor and feature area
- Infer authentication requirements and data flow patterns
- Generate sitemap.md (hierarchical route tree)
- Generate route-architecture.md (detailed inventory, flows, auth boundaries)
- Write incremental updates to `.banneker/state/plat-state.md` after each output
- Report completion with statistics

Wait for the plat-generator to return.

## Step 4: Verify Outputs

After the plat-generator returns, verify that outputs were created successfully:

### Verify required documents

Check that both output documents exist:

```bash
cat .banneker/documents/sitemap.md 2>/dev/null
```

```bash
cat .banneker/documents/route-architecture.md 2>/dev/null
```

1. Verify each file exists and is non-empty (> 200 bytes, since route documentation should be substantial)
2. Count total documents generated:
   ```bash
   ls .banneker/documents/sitemap.md .banneker/documents/route-architecture.md 2>/dev/null | wc -l
   ```
3. Quick validation check for placeholder content:
   ```bash
   grep -E "e\.g\.,|such as|TODO|PLACEHOLDER" .banneker/documents/sitemap.md .banneker/documents/route-architecture.md
   ```
   If placeholder content found: Display warning about generic content

### Display Results

**On success (both documents exist):**

Display completion message:
```
✓ Route architecture generation complete!

Generated documents:
  - .banneker/documents/sitemap.md
  - .banneker/documents/route-architecture.md

All route documentation created successfully.

Next steps:
  - Review .banneker/documents/sitemap.md for route hierarchy
  - Review .banneker/documents/route-architecture.md for detailed flows and auth boundaries
  - Run /banneker:appendix to compile HTML reference with route documentation
```

**On failure:**

Display error message with details about what's missing:
```
✗ Route architecture generation incomplete

Missing documents:
  - [list of missing files, one per line]

State file preserved at .banneker/state/plat-state.md for debugging.

To retry: Run /banneker:plat again to resume from where it stopped.
```

Do not delete the state file on failure - it's needed for debugging and resume.

## Step 5: Clean Up State (on success only)

If both documents exist and are valid, delete the state file:

```bash
rm -f .banneker/state/plat-state.md
```

This cleanup only happens on full successful completion (both documents present and validated).

## Important Implementation Notes

- This skill file runs inside an AI runtime (Claude Code, OpenCode, Gemini). All file operations (mkdir, cat, ls, wc, rm, grep) are executed via the runtime's Bash tool.
- The orchestrator is lean - all route extraction and document generation logic lives in the `banneker-plat-generator` agent, not here.
- Resume detection (Step 1) is MANDATORY per REQ-CONT-002 - never skip this step.
- The state file is the plat-generator's responsibility to write/update, and the orchestrator's responsibility to read and delete on completion.
- This file is the user-facing entry point for `/banneker:plat` - keep error messages helpful and actionable.

## Requirements Coverage

- **REQ-CONT-001**: State tracking via `.banneker/state/plat-state.md` (plat-generator writes, orchestrator reads)
- **REQ-CONT-002**: Resume detection in Step 1 (checks state file and existing documents before starting)
- **REQ-PLAT-001**: Prerequisite check for survey.json (Step 0)
- **REQ-PLAT-002**: Verification of both output documents in Step 4 (sitemap.md, route-architecture.md)
- **REQ-PLAT-003**: State cleanup on successful completion (Step 5)
