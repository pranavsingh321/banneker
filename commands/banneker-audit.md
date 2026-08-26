---
name: banneker-audit
description: "Evaluate engineering plans against the completeness rubric. Reads plan files, scores 10 categories, identifies gaps, and produces coverage reports. Run on any project with .planning/ directory or plan files."
---

# banneker-audit

CRITICAL INSTRUCTION: When this command says "spawn" or "use the task tool", you MUST call the `task` tool with `subagent_type` parameter. Do NOT try to read agent .md files, do NOT glob for agent files, do NOT perform the work yourself. The `task` tool handles spawning the correct agent.

You are the audit command orchestrator. Your job is to manage the plan evaluation lifecycle: check prerequisites, detect resume conditions, spawn the auditor sub-agent to evaluate plans against the completeness rubric, and verify outputs on completion.

## Step 0: Prerequisite Check (MANDATORY)

Before starting any work, check that plan files exist to audit:

### Discover plan files

Check for plan files in multiple locations:

**1. GSD-style projects:**
```bash
find .planning/phases -name "*PLAN.md" 2>/dev/null
```

**2. Banneker projects:**
```bash
ls .banneker/*.md 2>/dev/null
```

**3. Loose plan files in current directory:**
```bash
ls *[Pp][Ll][Aa][Nn]*.md 2>/dev/null
```

Combine results to build a list of plan files to audit.

If NO plan files found in any location:
- Display: "No plan files found. This command evaluates engineering plans against a completeness rubric."
- Display: "Looking for: .planning/phases/*PLAN.md, .banneker/*.md, or *plan*.md files"
- Display: "Provide a project with .planning/ or plan files."
- Abort and exit (do not proceed)

If plan files ARE found:
- Count total plan files discovered
- Display to user: "Found [N] plan files to audit:"
- List plan file paths (one per line)

## Step 1: Resume Detection (REQ-CONT-002)

Before starting any work, check for existing audit state:

### Check for existing audit report

Read existing audit reports if they exist:

```bash
ls -lh .banneker/audit-report.json 2>/dev/null
ls -lh .banneker/audit-report.md 2>/dev/null
```

If `.banneker/audit-report.json` exists:
1. Auto-re-run: Delete existing reports and proceed to Step 2 as fresh audit. Display: "Existing audit found. Re-running with current plans."

If no existing report: Proceed to Step 2 as fresh audit.

## Step 2: Ensure Directory Structure

Create the required directories if they don't exist:

```bash
mkdir -p .banneker
```

This ensures the auditor can write report files.

## Step 3: Spawn Auditor Sub-Agent

Call the `task` tool (NOT the `skill` tool) with these parameters:

```
task(
  description: "Evaluate plans against rubric",
  subagent_type: "banneker-auditor",
  prompt: "Evaluate each plan file against the 10-category rubric. Score each category, identify gaps, generate recommendations. Plan files: [list from Step 0]. Rubric: @config/completeness-rubric.md"
)
```

If ROADMAP.md exists, include its path `.planning/ROADMAP.md` in the prompt for dependency-aware scoring.

IMPORTANT: Use the `task` tool, NOT `skill`.

The auditor agent will:
- Load the completeness rubric from config
- Load ROADMAP.md if available (for phase context)
- Read and parse each plan file
- Score each plan against 10 rubric categories
- Identify coverage gaps and generate actionable recommendations
- Write outputs:
  - `.banneker/audit-report.json` (structured data with scores)
  - `.banneker/audit-report.md` (human-readable report)

Wait for the auditor to return.

## Step 4: Completion Verification

After the auditor returns, verify that outputs were created successfully:

### Verify audit-report.json

```bash
cat .banneker/audit-report.json 2>/dev/null
```

1. Check that `.banneker/audit-report.json` exists
2. Verify it parses as valid JSON:
   ```bash
   node -e "JSON.parse(require('fs').readFileSync('.banneker/audit-report.json', 'utf-8')); console.log('Valid JSON')"
   ```
3. Extract overall grade from JSON:
   ```bash
   node -e "const r = JSON.parse(require('fs').readFileSync('.banneker/audit-report.json', 'utf-8')); console.log(r.overall_grade + ' ' + r.overall_percentage + '%')"
   ```

### Verify audit-report.md

```bash
cat .banneker/audit-report.md 2>/dev/null
```

1. Check that `.banneker/audit-report.md` exists
2. Verify it has content (> 100 bytes):
   ```bash
   wc -c .banneker/audit-report.md
   ```

### Display Results

**Full completion (both reports exist and valid):**

Display completion message with grade:
```
✓ Audit complete!

Grade: [grade] ([percentage]%)

Reports:
  - .banneker/audit-report.json (structured data)
  - .banneker/audit-report.md (human-readable)

Plan files audited: [N]

[If grade is C or below:]
⚠ [N] gaps identified. See .banneker/audit-report.md for recommendations.

[If grade is B or above:]
✓ Plans are well-formed. See .banneker/audit-report.md for details.

Next steps:
  - Review .banneker/audit-report.md for detailed findings
  - Address any identified gaps in your plan files
  - Re-run /banneker:audit to verify improvements
```

**Partial completion (only one report exists):**

Display partial completion message:
```
⚠ Audit partially complete

Available reports:
  [list which file(s) exist: audit-report.json or audit-report.md]

Missing:
  [list which file(s) are missing]

To retry: Run /banneker:audit again.
```

**Failure (no reports):**

Display error message:
```
✗ Audit failed

No reports created at .banneker/audit-report.json or .banneker/audit-report.md

Check for errors above.

To retry: Run /banneker:audit again.
```

## Important Implementation Notes

- This skill file runs inside an AI runtime (Claude Code, OpenCode, Gemini). All file operations (mkdir, cat, ls, wc, find, node) are executed via the runtime's Bash tool.
- Unlike survey/architect/feed commands, this command does NOT require survey.json or architecture-decisions.json
- The audit command is designed to work on any project with plan files (GSD, Banneker, or standalone)
- The orchestrator is lean - all rubric evaluation, scoring, and recommendation logic lives in the `banneker-auditor` agent, not here.
- Resume detection (Step 1) handles existing reports (offers re-audit or keep)
- The auditor references the completeness rubric config at `@config/completeness-rubric.md`
- ROADMAP.md provides phase context to prevent penalizing Phase 1 for Phase 5 topics (deferred items)
- This file is the user-facing entry point for `/banneker:audit` - keep error messages helpful and actionable.

## Requirements Coverage

- **REQ-CONT-002**: Resume detection in Step 1 (checks existing reports before starting)
- **REQ-AUDIT-001**: Discovers plan files from multiple sources (.planning/, .banneker/, current directory)
- **REQ-AUDIT-002**: Passes completeness rubric config reference to auditor agent
- **REQ-AUDIT-003**: Displays grade and percentage in completion message
- **REQ-AUDIT-004**: Dual output verification (JSON for programmatic use, Markdown for human review)
