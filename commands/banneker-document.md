---
name: banneker-document
description: "Analyze an existing codebase to produce structured understanding. Scans file trees, identifies technologies, patterns, and architecture. Produces .banneker/codebase-understanding.md for brownfield project onboarding."
---

# banneker-document

You are the document command orchestrator. Your job is to manage the codebase analysis lifecycle: check prerequisites, detect resume conditions, spawn the cartographer sub-agent to scan and analyze the codebase, and verify outputs on completion.

CRITICAL INSTRUCTION: When this command says "spawn" or "use the task tool", you MUST call the `task` tool with `subagent_type` parameter. Do NOT try to read agent .md files, do NOT glob for agent files, do NOT perform the analysis yourself. The `task` tool will handle spawning the correct agent. Example:
```
task(description="Analyze codebase", subagent_type="banneker-cartographer", prompt="...")
```

## Step 0: Prerequisite Check (MANDATORY)

Before starting any work, check that current directory contains a project:

### Check for project indicators

Check for common project files:

```bash
test -f package.json || test -f Cargo.toml || test -f pyproject.toml || test -f go.mod || test -f Makefile || test -f pom.xml || test -f build.gradle || test -f *.sln || test -d src
```

If NO project indicators found:
- Display: "No project detected in current directory. Run this command from a project root."
- Display: "Looking for: package.json, Cargo.toml, pyproject.toml, go.mod, Makefile, pom.xml, build.gradle, *.sln, or src/ directory"
- Abort and exit (do not proceed)

## Step 1: Resume Detection (REQ-CONT-002)

Before starting any work, check for existing state:

### Check for interrupted scan

Read `.banneker/state/document-state.md` if it exists:

```bash
cat .banneker/state/document-state.md 2>/dev/null
```

If the file exists:
1. Parse the state to identify the resume point (which phase was in progress)
2. Extract the timestamp from the state file
3. Auto-resume: Proceed to Step 2 with resume context (pass state file content to cartographer). Display: "Resuming interrupted analysis from [timestamp]."

### Check for existing analysis

Read existing codebase understanding if it exists:

```bash
ls -lh .banneker/codebase-understanding.md 2>/dev/null
```

If codebase-understanding.md exists AND no state file:
1. Auto-overwrite: Proceed to Step 2 as fresh start. Display: "Existing analysis found. Overwriting with fresh analysis."

If neither state file nor codebase-understanding.md exists: Proceed to Step 2 as fresh start.

## Step 2: Ensure Directory Structure

Create the required directories if they don't exist:

```bash
mkdir -p .banneker/state
```

This ensures the cartographer can write state files during scanning.

## Step 3: Spawn Cartographer Sub-Agent

Call the `task` tool (NOT the `skill` tool) with these exact parameters:

```
task(
  description: "Analyze codebase",
  subagent_type: "banneker-cartographer",
  prompt: "Working directory: <cwd>. Fresh start — no prior state. Begin with Phase 1: Metadata Collection."
)
```

If resuming, include the content of `.banneker/state/document-state.md` in the prompt with: "Resume from the current phase indicated in this state file."

IMPORTANT: Use the `task` tool, NOT `skill`. The `skill` tool is for loading opencode skills (like customize-opencode), not for spawning sub-agents.

The cartographer agent will:
- Scan file tree structure
- Identify technologies, dependencies, and patterns
- Analyze architecture and component relationships
- Write incremental updates to `.banneker/state/document-state.md` after each phase
- Write final output to `.banneker/codebase-understanding.md`
- Delete the state file on successful completion

Wait for the cartographer to return.

## Step 4: Completion Verification

After the cartographer returns, verify that outputs were created successfully:

### Verify codebase-understanding.md

```bash
cat .banneker/codebase-understanding.md 2>/dev/null
```

1. Check that `.banneker/codebase-understanding.md` exists
2. Verify it has content (> 100 bytes):
   ```bash
   wc -c .banneker/codebase-understanding.md
   ```

### Check for state file cleanup

```bash
test -f .banneker/state/document-state.md && echo "state-exists" || echo "state-cleaned"
```

### Display Results

**Full completion (output exists, no state file):**

Display completion message:
```
✓ Codebase analysis complete!

Output:
  - .banneker/codebase-understanding.md ([size])

This document provides:
  - File structure and organization
  - Technologies and dependencies identified
  - Architecture patterns and components
  - Entry points and configuration

Next steps:
  - Review .banneker/codebase-understanding.md
  - Use findings to inform planning with /banneker:survey
  - Run /banneker:audit to evaluate existing plans
```

**Partial completion (output exists, state file also exists):**

Display partial completion message:
```
⚠ Codebase analysis partially complete

Output:
  - .banneker/codebase-understanding.md ([size])

The analysis was interrupted (likely due to context budget exhaustion).
State file preserved at .banneker/state/document-state.md

To complete: Run /banneker:document again to resume from where it stopped.
```

**Failure (no output):**

Display error message:
```
✗ Codebase analysis failed

No output file created at .banneker/codebase-understanding.md

State file preserved at .banneker/state/document-state.md for debugging.

To retry: Run /banneker:document again to resume.
```

Do not delete the state file on failure - it's needed for debugging and resume.

## Important Implementation Notes

- This skill file runs inside an AI runtime (Claude Code, OpenCode, Gemini). All file operations (mkdir, cat, ls, wc, test) are executed via the runtime's Bash tool.
- Unlike survey/architect/feed commands, this command does NOT require survey.json or architecture-decisions.json
- The document command is designed for brownfield projects with no prior Banneker state
- The orchestrator is lean - all scanning and analysis logic lives in the `banneker-cartographer` agent, not here.
- Resume detection (Step 1) is MANDATORY per REQ-CONT-002 - never skip this step.
- The state file is the cartographer's responsibility to write/update/delete, not the orchestrator's.
- This file is the user-facing entry point for `/banneker:document` - keep error messages helpful and actionable.

## Requirements Coverage

- **REQ-CONT-001**: State tracking via `.banneker/state/document-state.md` (cartographer writes, orchestrator reads)
- **REQ-CONT-002**: Resume detection in Step 1 (checks state file and existing output before starting)
- **REQ-BROWNFIELD-001**: Works on raw codebases without requiring survey.json (prerequisite check only looks for project files)
