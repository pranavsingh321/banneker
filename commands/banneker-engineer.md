---
name: banneker-engineer
description: "Synthesize survey data into engineering documents with explicit confidence levels. Generates DIAGNOSIS.md (what is known/unknown), RECOMMENDATION.md (options analysis), and ENGINEERING-PROPOSAL.md (DEC-XXX decisions for approval)."
---

# banneker-engineer

CRITICAL INSTRUCTION: When this command says "spawn" or "use the task tool", you MUST call the `task` tool with `subagent_type` parameter. Do NOT try to read agent .md files, do NOT glob for agent files, do NOT perform the work yourself. The `task` tool handles spawning the correct agent.

You are the engineer command orchestrator. Your job is to manage the engineering document generation lifecycle: check prerequisites, detect resume conditions, spawn the engineer sub-agent to synthesize documents, and verify outputs on completion.

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
- Display: "Note: /banneker:engineer works with partial survey data if you've completed at least Phases 1-3 (pitch, actors, walkthroughs)."
- Abort and exit (do not proceed)

### Check survey minimum viability

Parse survey.json and check for minimum required sections:

**Required for viable engineering analysis:**
- `project` object exists with `name`, `one_liner`, and `problem_statement` fields
- `actors` array exists and has length > 0
- `walkthroughs` array exists and has length > 0

If any of these are missing:
- Display: "Survey data incomplete. Minimum required: project details, actors, and at least one walkthrough."
- Display: "Continue /banneker:survey to complete Phases 1-3 before running engineer."
- Abort and exit (do not proceed)

## Step 1: Resume Detection (REQ-CONT-002 / ENGINT-05)

Before starting any work, check for existing state:

### Check for interrupted generation

Read `.banneker/state/engineer-state.md` if it exists:

```bash
cat .banneker/state/engineer-state.md 2>/dev/null
```

If the file exists:
1. Parse the state to identify which documents are already complete
2. Extract the list of completed documents and remaining documents
3. Display to user: "Found interrupted engineering session. Completed: [list]. Remaining: [list]."
4. Prompt user: "Resume generation? (y/N)"
   - If **yes**: Proceed to Step 2 with resume context (pass state file content to engineer)
   - If **no**: Prompt: "Start fresh? This will regenerate all documents. (y/N)"
     - If **yes**: Delete `.banneker/state/engineer-state.md` and proceed to Step 2 as fresh start
     - If **no**: Abort and exit (do not proceed)

### Check for existing documents

Read existing documents if any:

```bash
ls .banneker/documents/DIAGNOSIS.md .banneker/documents/RECOMMENDATION.md .banneker/documents/ENGINEERING-PROPOSAL.md 2>/dev/null
```

If documents already exist AND no state file:
1. Display to user: "Existing engineering documents found."
2. List the existing documents with file sizes:
   ```bash
   ls -lh .banneker/documents/DIAGNOSIS.md .banneker/documents/RECOMMENDATION.md .banneker/documents/ENGINEERING-PROPOSAL.md 2>/dev/null | awk '{print $9 " (" $5 ")"}'
   ```
3. Prompt user: "Overwrite with fresh generation? (y/N)"
   - If **yes**: Proceed to Step 2 as fresh start
   - If **no**: Abort and exit (do not proceed)

If neither state file nor documents exist: Proceed to Step 2 as fresh start.

## Step 2: Ensure Directory Structure

Create the required directories if they don't exist:

```bash
mkdir -p .banneker/documents
mkdir -p .banneker/state
```

This ensures the engineer can write documents and state files during generation.

## Step 3: Spawn Engineer Sub-Agent

Call the `task` tool (NOT the `skill` tool) with these parameters:

```
task(
  description: "Synthesize engineering documents",
  subagent_type: "banneker-engineer",
  prompt: "<context based on resume state>"
)
```

Context to pass:
- **Fresh start**: "Fresh start - no prior state. Begin with Step 1: Load and Parse Inputs."
- **Resuming**: Include content of `.banneker/state/engineer-state.md` with: "Resume from current state. Skip completed documents."

IMPORTANT: Use the `task` tool, NOT `skill`.

The engineer agent will:
- Load survey.json (handles partial data gracefully)
- Analyze survey completeness and establish confidence baseline
- Generate DIAGNOSIS.md, RECOMMENDATION.md, ENGINEERING-PROPOSAL.md sequentially
- Apply confidence markers with detailed rationale
- Write incremental updates to `.banneker/state/engineer-state.md` after each document
- Write final outputs to `.banneker/documents/[DOCUMENT-NAME].md`
- Delete the state file on successful completion

Wait for the engineer to return.

## Step 4: Verify Completion

After the engineer returns, verify that outputs were created successfully:

### Verify documents generated

Check that all three required documents exist:

```bash
cat .banneker/documents/DIAGNOSIS.md 2>/dev/null
```

```bash
cat .banneker/documents/RECOMMENDATION.md 2>/dev/null
```

```bash
cat .banneker/documents/ENGINEERING-PROPOSAL.md 2>/dev/null
```

1. Verify each file exists and is non-empty (> 100 bytes)
2. Count file sizes:
   ```bash
   ls -lh .banneker/documents/DIAGNOSIS.md .banneker/documents/RECOMMENDATION.md .banneker/documents/ENGINEERING-PROPOSAL.md 2>/dev/null | awk '{print $9 ": " $5}'
   ```

### Display Results

**On success:**

Display completion message:
```
Engineering document generation complete!

Generated documents:
  - .banneker/documents/DIAGNOSIS.md ([X] KB)
  - .banneker/documents/RECOMMENDATION.md ([Y] KB)
  - .banneker/documents/ENGINEERING-PROPOSAL.md ([Z] KB)

IMPORTANT: Proposals in ENGINEERING-PROPOSAL.md are NOT yet approved.

Next steps:
  - Review DIAGNOSIS.md to understand survey coverage and gaps
  - Review RECOMMENDATION.md to understand options analysis
  - Review ENGINEERING-PROPOSAL.md for proposed decisions
  - Run /banneker:approve-proposal to review and approve individual decisions (Phase 13)
```

**On failure:**

Display error message with details about what's missing:
```
Engineering document generation incomplete

Missing documents:
  - [list missing files]

State file preserved at .banneker/state/engineer-state.md

To retry: Run /banneker:engineer again to resume
```

Do not delete the state file on failure - it's needed for debugging and resume.

## Important Implementation Notes

- This skill file runs inside an AI runtime (Claude Code, OpenCode, Gemini). All file operations (mkdir, cat, ls, awk) are executed via the runtime's Bash tool.
- The orchestrator is lean - all document synthesis logic lives in the `banneker-engineer` agent, not here.
- Resume detection (Step 1) is MANDATORY per REQ-CONT-002 and ENGINT-05 - never skip this step.
- The state file is the engineer's responsibility to write/update/delete, not the orchestrator's.
- This file is the user-facing entry point for `/banneker:engineer` - keep error messages helpful and actionable.
- CRITICAL: Do NOT merge proposals to architecture-decisions.json - this requires user approval via Phase 13 approval flow.

## Requirements Coverage

- **ENGINT-01**: Standalone /banneker:engineer command (this file is the entry point)
- **ENGINT-02**: Partial survey support (minimum viability check, engineer handles graceful degradation)
- **ENGINT-05**: State tracking via `.banneker/state/engineer-state.md` (resume detection in Step 1)
- **REQ-CONT-002**: Resume detection before starting any work (Step 1 checks state file and existing documents)

## Related Commands

- `/banneker:survey` - Run discovery interview to create survey.json (prerequisite)
- `/banneker:architect` - Generate planning documents from survey (alternative path)
- `/banneker:approve-proposal` - Review and approve proposed decisions (Phase 13 - coming in v0.3.0)
