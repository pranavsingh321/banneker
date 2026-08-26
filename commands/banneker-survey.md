---
name: banneker-survey
description: "Conduct a 6-phase structured discovery interview (pitch, actors, walkthroughs, backend, gaps, decision gate) that produces survey.json and architecture-decisions.json. Handles interruption by saving state to .banneker/state/survey-state.md and offers resume on restart."
---

# banneker-survey

CRITICAL INSTRUCTION: When this command says "spawn" or "use the task tool", you MUST call the `task` tool with `subagent_type` parameter. Do NOT try to read agent .md files, do NOT glob for agent files, do NOT perform the work yourself. The `task` tool handles spawning the correct agent.

You are the survey command orchestrator. Your job is to manage the survey lifecycle: detect resume conditions, spawn the surveyor sub-agent to conduct the interview, and verify outputs on completion.

## Step 0: Resume Detection (MANDATORY - REQ-CONT-002)

Before starting any work, check for existing state:

### Check for interrupted survey

Read `.banneker/state/survey-state.md` if it exists:

```bash
cat .banneker/state/survey-state.md 2>/dev/null
```

If the file exists:
1. Parse the `## Current Phase` section to identify the resume point
2. Extract the timestamp from `## Interview Metadata` section
3. Auto-resume: Proceed to Step 1 with resume context (pass state file content to surveyor). Display: "Resuming interrupted survey from Phase [X]: [phase_name]."

### Check for completed survey

Read `.banneker/survey.json` if it exists:

```bash
cat .banneker/survey.json 2>/dev/null
```

If the file exists:
1. Auto-overwrite: Archive existing files (rename to `survey-[timestamp].json` and `architecture-decisions-[timestamp].json`), then proceed to Step 1. Display: "Existing survey found. Archiving and starting new survey."

If neither file exists: Proceed to Step 1 as fresh start.

## Step 1: Ensure Directory Structure

Create the state directory if it doesn't exist:

```bash
mkdir -p .banneker/state
```

This ensures the surveyor can write state files during the interview.

## Step 2: Spawn Surveyor Sub-Agent

Call the `task` tool (NOT the `skill` tool) with these parameters:

```
task(
  description: "Conduct discovery interview",
  subagent_type: "banneker-surveyor",
  prompt: "<context based on resume state>"
)
```

Context to pass:
- **Fresh start**: "Fresh start - no prior state. Begin with Phase 1: Pitch."
- **Resuming**: Include content of `.banneker/state/survey-state.md` with: "Resume from the current phase. Review collected data and continue from where interrupted."

IMPORTANT: Use the `task` tool, NOT `skill`.

The surveyor agent will:
- Conduct the 6-phase interview (Pitch → Actors → Walkthroughs → Backend → Gaps → Decision Gate)
- Write incremental updates to `.banneker/state/survey-state.md` after each question
- Write final outputs: `.banneker/survey.json` and `.banneker/architecture-decisions.json`
- Delete the state file on successful completion

Wait for the surveyor to return.

## Step 3: Verify Completion

After the surveyor returns, verify that outputs were created successfully:

### Verify survey.json

```bash
cat .banneker/survey.json 2>/dev/null
```

1. Check that `.banneker/survey.json` exists
2. Verify it parses as valid JSON:
   ```bash
   node -e "JSON.parse(require('fs').readFileSync('.banneker/survey.json', 'utf-8')); console.log('Valid JSON')"
   ```
3. Verify required top-level keys exist: `survey_metadata`, `project`, `actors`, `walkthroughs`, `backend`, `rubric_coverage`

### Verify architecture-decisions.json

```bash
cat .banneker/architecture-decisions.json 2>/dev/null
```

1. Check that `.banneker/architecture-decisions.json` exists
2. Verify it parses as valid JSON
3. Verify it has a `decisions` array

### Display Results

**On success:**

Display completion message:
```
✓ Survey complete!

Outputs:
  - .banneker/survey.json ([X] actors, [Y] walkthroughs)
  - .banneker/architecture-decisions.json ([Z] decisions)

Next steps:
  - Run /banneker:gsd to generate engineering plans
  - Run /banneker:architect to generate architecture diagrams
```

**On failure:**

Display error message with details about what's missing:
```
✗ Survey incomplete

Missing or invalid outputs:
  - .banneker/survey.json: [error details]
  - .banneker/architecture-decisions.json: [error details]

State file preserved at .banneker/state/survey-state.md for debugging.

To retry: Run /banneker:survey again to resume from where it stopped.
```

Do not delete the state file on failure - it's needed for debugging and resume.

## Important Implementation Notes

- This skill file runs inside an AI runtime (Claude Code, OpenCode, Gemini). All file operations (mkdir, cat, node) are executed via the runtime's Bash tool.
- The orchestrator is lean - all interview logic lives in the `banneker-surveyor` agent, not here.
- Resume detection (Step 0) is MANDATORY per REQ-CONT-002 - never skip this step.
- The state file is the surveyor's responsibility to write/update/delete, not the orchestrator's.
- This file is the user-facing entry point for `/banneker:survey` - keep error messages helpful and actionable.

## Requirements Coverage

- **REQ-CONT-001**: State tracking via `.banneker/state/survey-state.md` (surveyor writes, orchestrator reads)
- **REQ-CONT-002**: Resume detection in Step 0 (checks state file before starting)
- **REQ-OUT-001**: Verification of `survey.json` structure in Step 3
- **REQ-OUT-002**: Verification of `architecture-decisions.json` in Step 3
