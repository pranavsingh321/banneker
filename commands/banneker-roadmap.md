---
name: banneker-roadmap
description: "Generate architecture diagrams from survey data. Produces 4 self-contained HTML diagrams: executive roadmap, decision map, system map, and architecture wiring diagram. Supports resume if generation is interrupted."
---

# banneker-roadmap

CRITICAL INSTRUCTION: When this command says "spawn" or "use the task tool", you MUST call the `task` tool with `subagent_type` parameter. Do NOT try to read agent .md files, do NOT glob for agent files, do NOT perform the work yourself. The `task` tool handles spawning the correct agent.

You are the roadmap command orchestrator. Your job is to manage the diagram generation lifecycle: check prerequisites, detect resume conditions, spawn the diagrammer sub-agent to generate HTML diagrams, and verify outputs on completion.

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

### Check for Wave 1 handoff from interrupted Wave 2 generation

Read `.banneker/state/.continue-here.md` if it exists:

```bash
cat .banneker/state/.continue-here.md 2>/dev/null
```

If the file exists:
1. Parse the handoff file to understand what was completed in Wave 1
2. Display to user: "Found handoff from Wave 1. Completed diagrams: executive-roadmap.html, decision-map.html, system-map.html. Remaining: architecture-wiring.html (Wave 2, requires JavaScript)."
3. Prompt user: "Continue to Wave 2? (y/N)"
   - If **yes**: Proceed to Step 2 with Wave 2 context (pass handoff file content to diagrammer)
   - If **no**: Display: "Keeping Wave 1 diagrams. Run /banneker:roadmap again when ready for Wave 2." and exit

### Check for interrupted generation

Read `.banneker/state/diagrammer-state.md` if it exists:

```bash
cat .banneker/state/diagrammer-state.md 2>/dev/null
```

If the file exists:
1. Parse the state to identify which wave and which diagrams are already complete
2. Extract completed diagrams list and current wave number
3. Display to user: "Found interrupted diagram generation. Wave: [N]. Completed: [list]. Remaining: [list]."
4. Prompt user: "Resume generation? (y/N)"
   - If **yes**: Proceed to Step 2 with resume context (pass state file content to diagrammer)
   - If **no**: Prompt: "Start fresh? This will regenerate all diagrams. (y/N)"
     - If **yes**: Delete `.banneker/state/diagrammer-state.md` and `.banneker/state/.continue-here.md` if present, then proceed to Step 2 as fresh start
     - If **no**: Abort and exit (do not proceed)

### Check for existing diagrams

Read existing diagrams if any:

```bash
ls .banneker/diagrams/*.html 2>/dev/null
```

If diagrams already exist AND no state files:
1. Check if all 4 diagrams exist:
   - executive-roadmap.html
   - decision-map.html
   - system-map.html
   - architecture-wiring.html
2. Count existing diagrams:
   ```bash
   ls .banneker/diagrams/*.html 2>/dev/null | wc -l
   ```
3. Display to user: "Found [N] existing diagram(s) at .banneker/diagrams/"
4. List the existing diagrams (one per line)
5. If **all 4 exist**:
   - Display: "All 4 architecture diagrams already exist."
   - Prompt user: "Regenerate from scratch? (y/N)"
     - If **yes**: Proceed to Step 2 as fresh start
     - If **no**: Abort and exit (do not proceed)
6. If **1-3 exist** (partial completion):
   - Display: "Partial diagram set detected. This may indicate Wave 1 completed but Wave 2 is missing."
   - Prompt user: "Complete remaining diagrams? (y/N)"
     - If **yes**: Proceed to Step 2 with partial resume context
     - If **no**: Prompt: "Regenerate all from scratch? (y/N)"
       - If **yes**: Proceed to Step 2 as fresh start
       - If **no**: Abort and exit (do not proceed)

If neither state files nor diagrams exist: Proceed to Step 2 as fresh start.

## Step 2: Create Output Directory

Create the required directories if they don't exist:

```bash
mkdir -p .banneker/diagrams
mkdir -p .banneker/state
```

This ensures the diagrammer can write diagrams and state files during generation.

## Step 3: Spawn Diagrammer Sub-Agent

Call the `task` tool (NOT the `skill` tool) with these parameters:

```
task(
  description: "Generate architecture diagrams",
  subagent_type: "banneker-diagrammer",
  prompt: "<context based on resume state>"
)
```

Context to pass:
- **Fresh start**: "Fresh start — no prior state. Begin with Wave 1 (executive roadmap, decision map, system map), then Wave 2 (architecture wiring diagram)."
- **Resuming from Wave 1 handoff**: Include content of `.banneker/state/.continue-here.md` with: "Resume at Wave 2. Wave 1 diagrams complete. Generate architecture-wiring.html only."
- **Resuming from interrupted generation**: Include content of `.banneker/state/diagrammer-state.md` with: "Resume from the current state. Skip already-completed diagrams."
- **Resuming from partial diagrams**: List existing diagrams with: "Complete missing diagrams. Existing: [list]."

IMPORTANT: Use the `task` tool, NOT `skill`.

The diagrammer agent will:
- Load survey.json and architecture-decisions.json
- Generate diagrams in two waves:
  - Wave 1: CSS-only diagrams (executive-roadmap.html, decision-map.html, system-map.html)
  - Wave 2: JS-enhanced diagram (architecture-wiring.html)
- Write incremental updates to `.banneker/state/diagrammer-state.md` after each diagram
- Write final outputs to `.banneker/diagrams/[diagram-name].html`
- Write `.banneker/state/.continue-here.md` if context budget exhausted between waves
- Delete state files on successful completion of both waves

Wait for the diagrammer to return.

## Step 4: Verify Outputs

After the diagrammer returns, verify that outputs were created successfully:

### Verify diagram outputs

Check for all 4 diagrams:

```bash
cat .banneker/diagrams/executive-roadmap.html 2>/dev/null
```

```bash
cat .banneker/diagrams/decision-map.html 2>/dev/null
```

```bash
cat .banneker/diagrams/system-map.html 2>/dev/null
```

```bash
cat .banneker/diagrams/architecture-wiring.html 2>/dev/null
```

1. Verify each file exists and is non-empty (> 500 bytes, since HTML diagrams should be substantial)
2. Count total diagrams generated:
   ```bash
   ls .banneker/diagrams/*.html 2>/dev/null | wc -l
   ```

### Display Results

**On full completion (4 diagrams):**

Display completion message:
```
✓ Diagram generation complete!

Generated diagrams:
  - .banneker/diagrams/executive-roadmap.html
  - .banneker/diagrams/decision-map.html
  - .banneker/diagrams/system-map.html
  - .banneker/diagrams/architecture-wiring.html

Total: 4 diagrams generated

All diagrams are self-contained HTML files. Open any diagram in your browser to view.

Next steps:
  - Review the generated diagrams in .banneker/diagrams/
  - Run /banneker:appendix to compile HTML reference with embedded diagrams
  - Run /banneker:feed to export planning artifacts to downstream frameworks
```

**On partial completion (Wave 1 only, 3 diagrams):**

Check for handoff file:
```bash
cat .banneker/state/.continue-here.md 2>/dev/null
```

If handoff file exists:
```
✓ Wave 1 complete!

Generated diagrams:
  - .banneker/diagrams/executive-roadmap.html
  - .banneker/diagrams/decision-map.html
  - .banneker/diagrams/system-map.html

Wave 1: 3/3 diagrams complete
Wave 2: Pending (architecture-wiring.html requires JavaScript generation)

The diagrammer reached context budget limits after Wave 1. A handoff file has been saved at .banneker/state/.continue-here.md for Wave 2 resume.

To complete Wave 2:
  - Run /banneker:roadmap again to generate architecture-wiring.html
  - The command will automatically detect the handoff and resume at Wave 2
```

**On failure:**

Display error message with details about what's missing:
```
✗ Diagram generation incomplete

Expected 4 diagrams, found [N]:
  [list of missing diagrams, one per line]

State file preserved at .banneker/state/diagrammer-state.md for debugging.

To retry: Run /banneker:roadmap again to resume from where it stopped.
```

Do not delete the state file on failure - it's needed for debugging and resume.

## Step 5: Clean Up State (on full completion only)

If all 4 diagrams exist, delete the state files:

```bash
rm -f .banneker/state/diagrammer-state.md
rm -f .banneker/state/.continue-here.md
```

This cleanup only happens on full successful completion (all 4 diagrams present). If only Wave 1 completed, preserve the handoff file for Wave 2 resume.

## Important Implementation Notes

- This skill file runs inside an AI runtime (Claude Code, OpenCode, Gemini). All file operations (mkdir, cat, ls, wc, rm) are executed via the runtime's Bash tool.
- The orchestrator is lean - all diagram generation logic lives in the `banneker-diagrammer` agent, not here.
- Resume detection (Step 1) is MANDATORY per REQ-CONT-002 - never skip this step.
- Wave 1/Wave 2 partial completion is a NORMAL outcome if context budget is exhausted, not a failure.
- The state files are the diagrammer's responsibility to write/update/delete, not the orchestrator's.
- This file is the user-facing entry point for `/banneker:roadmap` - keep error messages helpful and actionable.

## Requirements Coverage

- **REQ-CONT-001**: State tracking via `.banneker/state/diagrammer-state.md` (diagrammer writes, orchestrator reads)
- **REQ-CONT-002**: Resume detection in Step 1 (checks state files, handoff file, and existing diagrams before starting)
- **REQ-CONT-003**: Wave 1/Wave 2 handoff via `.banneker/state/.continue-here.md` (context budget management)
- **REQ-DIAG-001**: Verification of all 4 diagram outputs in Step 4
- **REQ-DIAG-002**: Wave 1 (CSS-only) and Wave 2 (JS-enhanced) handled by diagrammer agent
- **REQ-DIAG-003**: Self-contained HTML validation (orchestrator verifies files exist, diagrammer ensures self-containment)
- **REQ-DIAG-004**: Graceful handling of partial completion with clear user messaging
