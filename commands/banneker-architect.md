---
name: banneker-architect
description: "Generate project-specific planning documents from survey data. Determines which documents to create based on project type, generates them in dependency order, and validates for zero placeholders and consistent naming. Handles interruption by saving state and offers resume on restart."
---

# banneker-architect

CRITICAL INSTRUCTION: When this command says "spawn" or "use the task tool", you MUST call the `task` tool with `subagent_type` parameter. Do NOT try to read agent .md files, do NOT glob for agent files, do NOT perform the work yourself. The `task` tool handles spawning the correct agent.

You are the architect command orchestrator. Your job is to manage the document generation lifecycle: check prerequisites, detect resume conditions, spawn the architect sub-agent to determine and generate documents, and verify outputs on completion.

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

### Check for architecture-decisions.json

Read `.banneker/architecture-decisions.json`:

```bash
cat .banneker/architecture-decisions.json 2>/dev/null
```

If `.banneker/architecture-decisions.json` does NOT exist:
- Display: "No architecture decisions found at .banneker/architecture-decisions.json"
- Display: "Run /banneker:survey first — the decision gate phase creates this file."
- Abort and exit (do not proceed)

## Step 1: Resume Detection (REQ-CONT-002)

Before starting any work, check for existing state:

### Check for interrupted generation

Read `.banneker/state/architect-state.md` if it exists:

```bash
cat .banneker/state/architect-state.md 2>/dev/null
```

If the file exists:
1. Parse the state to identify which documents are already complete
2. Extract the list of completed documents and remaining documents
3. Auto-resume: Proceed to Step 2 with resume context (pass state file content to architect). Display: "Resuming interrupted generation. Completed: [list]. Remaining: [list]."

### Check for existing documents

Read existing documents if any:

```bash
ls .banneker/documents/*.md 2>/dev/null
```

If documents already exist AND no state file:
1. Auto-overwrite: Proceed to Step 2 as fresh start. Display: "Overwriting existing documents with fresh generation."

If neither state file nor documents exist: Proceed to Step 2 as fresh start.

## Step 2: Ensure Directory Structure

Create the required directories if they don't exist:

```bash
mkdir -p .banneker/documents
mkdir -p .banneker/state
```

This ensures the architect can write documents and state files during generation.

## Step 3: Spawn Architect Sub-Agent

Call the `task` tool (NOT the `skill` tool) with these parameters:

```
task(
  description: "Generate planning documents",
  subagent_type: "banneker-architect",
  prompt: "<context based on resume state>"
)
```

Context to pass:
- **Fresh start**: "Fresh start — no prior state. Begin with Step 1: Load and Parse Inputs."
- **Resuming**: Include content of `.banneker/state/architect-state.md` with: "Resume from the current state. Skip already-completed documents."

IMPORTANT: Use the `task` tool, NOT `skill`.

The architect agent will:
- Load survey.json and architecture-decisions.json
- Determine which documents are applicable based on project type
- Generate documents in dependency-ordered waves
- Validate each document for placeholders and naming consistency
- Write incremental updates to `.banneker/state/architect-state.md` after each document
- Write final outputs to `.banneker/documents/[DOCUMENT-NAME].md`
- Delete the state file on successful completion

Wait for the architect to return.

## Step 4: Verify Completion

After the architect returns, verify that outputs were created successfully:

### Verify required documents

Check that at minimum the 3 always-generated documents exist:

```bash
cat .banneker/documents/TECHNICAL-SUMMARY.md 2>/dev/null
```

```bash
cat .banneker/documents/STACK.md 2>/dev/null
```

```bash
cat .banneker/documents/INFRASTRUCTURE-ARCHITECTURE.md 2>/dev/null
```

1. Verify each required file exists and is non-empty (> 100 bytes)
2. Count total documents generated:
   ```bash
   ls .banneker/documents/*.md 2>/dev/null | wc -l
   ```

### Display Results

**On success:**

Display completion message:
```
✓ Document generation complete!

Generated documents:
  - .banneker/documents/TECHNICAL-SUMMARY.md
  - .banneker/documents/STACK.md
  - .banneker/documents/INFRASTRUCTURE-ARCHITECTURE.md
  [+ any conditional documents listed one per line]

Total: [N] documents generated

Next steps:
  - Review the generated documents in .banneker/documents/
  - Run /banneker:roadmap to generate architecture diagrams
  - Run /banneker:appendix to compile HTML reference
```

**On failure:**

Display error message with details about what's missing:
```
✗ Document generation incomplete

Missing required documents:
  - [list of missing files, one per line]

State file preserved at .banneker/state/architect-state.md for debugging.

To retry: Run /banneker:architect again to resume from where it stopped.
```

Do not delete the state file on failure - it's needed for debugging and resume.

## Important Implementation Notes

- This skill file runs inside an AI runtime (Claude Code, OpenCode, Gemini). All file operations (mkdir, cat, ls, wc) are executed via the runtime's Bash tool.
- The orchestrator is lean - all document selection, generation, and validation logic lives in the `banneker-architect` agent, not here.
- Resume detection (Step 1) is MANDATORY per REQ-CONT-002 - never skip this step.
- The state file is the architect's responsibility to write/update/delete, not the orchestrator's.
- This file is the user-facing entry point for `/banneker:architect` - keep error messages helpful and actionable.

## Requirements Coverage

- **REQ-CONT-001**: State tracking via `.banneker/state/architect-state.md` (architect writes, orchestrator reads)
- **REQ-CONT-002**: Resume detection in Step 1 (checks state file and existing documents before starting)
- **REQ-DOCS-001**: Verification of 3 always-generated documents in Step 4 (TECHNICAL-SUMMARY, STACK, INFRASTRUCTURE-ARCHITECTURE)
- **REQ-DOCS-002**: Conditional documents handled by architect agent (orchestrator verifies all outputs but doesn't know which are conditional)
