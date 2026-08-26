---
name: banneker-approve
description: "Review and approve AI-generated engineering decisions before they merge to architecture-decisions.json"
---

# banneker-approve

You are the approval command orchestrator. Your job is to guide the user through reviewing ENGINEERING-PROPOSAL.md and approving, editing, or rejecting each proposed decision before it merges to architecture-decisions.json.

## Purpose

This command implements the approval workflow for AI-generated engineering decisions. It provides:

- **Per-decision granularity** (APPROVE-02): Review each decision individually
- **Edit-before-approve** (APPROVE-03): Modify decisions before accepting them
- **Rejection with reasons** (APPROVE-01): Track why decisions were rejected
- **Batch operations**: Quickly approve or reject all when appropriate

## Input Files

- `.banneker/documents/ENGINEERING-PROPOSAL.md` - Contains proposed decisions in ADR format
- `.banneker/architecture-decisions.json` - Existing decision log (may be empty or not exist)

## Workflow Steps

### Step 1: Load Proposals

Read the ENGINEERING-PROPOSAL.md file:

```bash
cat .banneker/documents/ENGINEERING-PROPOSAL.md 2>/dev/null
```

If the file does not exist:
- Display: "No pending proposals found at .banneker/documents/ENGINEERING-PROPOSAL.md"
- Display: "Run /banneker:engineer first to generate engineering proposals."
- Abort and exit (do not proceed)

Parse ADR blocks from the document. Each decision block starts with `# DEC-XXX:` and contains:
- **id**: The decision ID (e.g., DEC-001)
- **question**: What is being decided
- **choice**: The recommended option
- **rationale**: Why this choice was made
- **confidence**: HIGH, MEDIUM, or LOW
- **alternatives_considered**: Other options that were evaluated
- **domain**: Category like "Authentication", "Database", "API Design"

Extract each decision into a structured object.

If no decision blocks found:
- Display: "No decision blocks found in ENGINEERING-PROPOSAL.md."
- Display: "Expected format: blocks starting with '# DEC-XXX:'"
- Abort and exit (do not proceed)

### Step 2: Display Summary Table

Display the proposals grouped by domain with numbered indices for selection.

Use lib/approval-display.js concept (displayProposalsSummary function pattern):
- Group decisions by domain field
- Show each decision with: [number] ID: question
- Include choice and confidence for each
- Track global index (1-based) across all groups

Example output:
```
Proposed Decisions (5 total)
═══════════════════════════════════════════════════════════════

Authentication (2 decisions)
────────────────────────────────────────────────────────────────
[1] DEC-001: How should users authenticate?
    Choice: JWT with refresh tokens
    Confidence: HIGH

[2] DEC-002: Should we use OAuth or custom auth?
    Choice: OAuth 2.0 with PKCE
    Confidence: MEDIUM

Database (3 decisions)
────────────────────────────────────────────────────────────────
[3] DEC-003: What database engine should we use?
    Choice: PostgreSQL
    Confidence: HIGH
...
```

Display confidence distribution:
- HIGH: X decisions
- MEDIUM: Y decisions
- LOW: Z decisions

### Step 3: Batch Selection

Prompt user for batch action:

```
Batch action:
  a) Approve all
  r) Reject all
  s) Select individually (enter numbers like: 1,3,5)

Choice:
```

Handle each case:

**If 'a' (approve all):**
- All decisions marked for approval
- Skip to Step 5 (no rejection reasons needed)

**If 'r' (reject all):**
- All decisions marked for rejection
- Continue to Step 4 for rejection reasons

**If 's' (select individually):**
- Prompt: "Enter numbers to APPROVE (1-N, comma-separated, or empty for none): "
- Parse the input as comma-separated indices
- Decisions NOT in the list are marked for rejection
- Continue with mixed flow

### Step 4: Per-Decision Review (if individual selection)

For each decision that needs individual review, present:

```
────────────────────────────────────────────────────────────────
Decision: DEC-001
Question: How should users authenticate?
Choice: JWT with refresh tokens
Rationale: JWTs provide stateless authentication suitable for microservices...
Confidence: HIGH

Actions:
  y) Approve
  n) Reject
  e) Edit
  s) Skip for now

Choice (y/n/e/s):
```

Handle each action:

**If 'y' (approve):**
- Mark decision as approved
- Continue to next decision

**If 'n' (reject):**
- Mark decision as rejected
- Add to rejection list for Step 5

**If 'e' (edit):**
- Open decision in $EDITOR (see Step 4a)
- After edit, re-prompt with approve/reject for the edited version
- Track that this decision was edited

**If 's' (skip):**
- Keep decision as "Proposed (awaiting approval)"
- Do not include in approved or rejected lists

### Step 4a: Handle Edits

When user chooses 'edit' for a decision:

1. Create a temporary file with the decision as JSON:
   - Include instructional comments at the top
   - Format: lines starting with # are comments
   ```
   # Edit the decision below (lines starting with # are ignored)
   # Decision ID: DEC-XXX
   # Question: [original question]
   #
   # Save and close to accept changes.
   # To cancel, delete all JSON content.

   {
     "id": "DEC-001",
     "question": "How should users authenticate?",
     "choice": "JWT with refresh tokens",
     "rationale": "...",
     "confidence": "HIGH",
     "alternatives_considered": [...],
     "domain": "Authentication"
   }
   ```

2. Open in $EDITOR (or $VISUAL, fallback to 'vi'):
   ```bash
   ${EDITOR:-${VISUAL:-vi}} /tmp/decision-edit.json
   ```

3. Wait for editor to close

4. Read the file back, strip comment lines, parse JSON

5. If JSON is valid:
   - Replace the decision with edited version
   - Re-prompt: "Edited decision ready. Approve this version? (y/n)"
   - If approved: add to approved list
   - If rejected: add to rejected list

6. If JSON is invalid or empty (cancelled):
   - Display: "Edit cancelled or invalid JSON. Decision unchanged."
   - Re-prompt with original decision

### Step 5: Collect Rejection Reasons

For each rejected decision, optionally collect a reason:

```
Rejecting: DEC-003
  Question: What database engine should we use?
  Choice: PostgreSQL

Reason for rejection (optional, press Enter to skip):
```

If user provides a reason, store it. If skipped, use default: "User rejected without reason"

### Step 6: Execute Merge

Using lib/approval.js functions:

**For approved decisions:**
Call mergeApprovedDecisions(approvedDecisions) which:
- Reads existing architecture-decisions.json (or creates new)
- Creates backup before modification
- Appends approved decisions with atomic write
- Returns count of merged decisions

**For rejected decisions:**
Call logRejectedDecisions(rejectedDecisions, reasons) which:
- Appends to .banneker/rejection-log.json
- Includes full_decision for potential recovery
- Stores rejection reason for each

Display result:
```
Approval complete!
  Merged: X decision(s) to architecture-decisions.json
  Rejected: Y decision(s) (logged to rejection-log.json)
  Skipped: Z decision(s) (still pending in ENGINEERING-PROPOSAL.md)
```

### Step 7: Update ENGINEERING-PROPOSAL.md

Update the status of each decision in the proposal document:

**For approved decisions:**
- Add or update line: `**Status:** Accepted (merged to architecture-decisions.json)`

**For rejected decisions:**
- Add or update line: `**Status:** Rejected (reason: [user's reason])`

**For skipped decisions:**
- Keep as: `**Status:** Proposed (awaiting approval)`

Write the updated ENGINEERING-PROPOSAL.md back to disk.

## Important Implementation Notes

- This skill file runs inside an AI runtime (Claude Code, OpenCode, Gemini). All file operations are executed via the runtime's tools (Read, Write, Bash).
- The orchestrator is lean - all atomic merge logic lives in lib/approval.js.
- Editor spawning uses Bash tool with stdio inherit for interactive editor sessions.
- Always verify architecture-decisions.json was updated after merge.
- Rejection log provides audit trail and potential recovery path.

## Requirements Coverage

- **APPROVE-01**: Explicit approval (no auto-merge, user must approve)
- **APPROVE-02**: Per-decision granularity (review each individually via 's' option)
- **APPROVE-03**: Edit-before-approve (open in $EDITOR, modify, then approve)

## Related Commands

- `/banneker:engineer` - Generate engineering proposals from survey data (prerequisite)
- `/banneker:survey` - Conduct discovery interview to create survey data
- `/banneker:architect` - Generate architecture diagrams from decisions

## Example Session

```
$ /banneker:approve

Proposed Decisions (3 total)
═══════════════════════════════════════════════════════════════

Authentication (1 decision)
────────────────────────────────────────────────────────────────
[1] DEC-001: How should users authenticate?
    Choice: JWT with refresh tokens
    Confidence: HIGH

Database (2 decisions)
────────────────────────────────────────────────────────────────
[2] DEC-002: What database engine should we use?
    Choice: PostgreSQL
    Confidence: HIGH

[3] DEC-003: How should we handle database migrations?
    Choice: Prisma Migrate
    Confidence: MEDIUM

Confidence distribution: HIGH: 2, MEDIUM: 1, LOW: 0

Batch action:
  a) Approve all
  r) Reject all
  s) Select individually

Choice: s

Enter numbers to APPROVE (1-3, comma-separated, or empty for none): 1,2

────────────────────────────────────────────────────────────────
Decision: DEC-003
Question: How should we handle database migrations?
Choice: Prisma Migrate
Rationale: Prisma Migrate provides type-safe migrations...
Confidence: MEDIUM

Actions:
  y) Approve
  n) Reject
  e) Edit
  s) Skip for now

Choice (y/n/e/s): n

Rejecting: DEC-003
  Question: How should we handle database migrations?
  Choice: Prisma Migrate

Reason for rejection (optional, press Enter to skip): Prefer raw SQL migrations for better control

Approval complete!
  Merged: 2 decision(s) to architecture-decisions.json
  Rejected: 1 decision(s) (logged to rejection-log.json)
  Skipped: 0 decision(s)
```
