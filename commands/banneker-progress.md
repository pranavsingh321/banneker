---
name: banneker-progress
description: "Show current Banneker workflow state from state files and available outputs"
---

# banneker-progress

You are the progress command for Banneker. Your job is to read state files and available outputs to display current workflow status and recommend next steps.

## Step 1: Check for .banneker Directory

Verify that a Banneker project has been initialized:

```bash
test -d .banneker && echo "exists" || echo "missing"
```

If the directory does NOT exist:
- Display: "No Banneker project initialized. Run /banneker:survey to start."
- Exit (do not proceed)

If the directory exists, proceed to Step 2.

## Step 2: Read State Files

List all state files in the state directory:

```bash
ls .banneker/state/*.md 2>/dev/null
```

For each state file found, extract and parse:

### Extract frontmatter fields

```bash
for state_file in .banneker/state/*.md; do
  echo "=== $(basename "$state_file") ==="

  # Extract YAML frontmatter fields
  grep "^command:" "$state_file" 2>/dev/null
  grep "^status:" "$state_file" 2>/dev/null
  grep "^started_at:" "$state_file" 2>/dev/null
  grep "^items_completed:" "$state_file" 2>/dev/null
  grep "^items_total:" "$state_file" 2>/dev/null
  grep "^current_position:" "$state_file" 2>/dev/null

  echo ""
done
```

### Parse markdown body for progress checklist

Count completed and total items:

```bash
for state_file in .banneker/state/*.md; do
  echo "Progress for $(basename "$state_file"):"

  # Count checked items
  checked=$(grep -c "^- \[x\]" "$state_file" 2>/dev/null || echo "0")

  # Count total items (checked + unchecked)
  total=$(grep -c "^- \[[x ]\]" "$state_file" 2>/dev/null || echo "0")

  # Calculate percentage
  if [ "$total" -gt 0 ]; then
    percent=$((checked * 100 / total))
    echo "  $checked/$total complete ($percent%)"
  else
    echo "  No checklist found"
  fi

  echo ""
done
```

Store this information for display in Step 5.

## Step 3: Check for Handoff Files

Read the handoff file if it exists:

```bash
cat .banneker/state/.continue-here.md 2>/dev/null
```

If the file exists:
- Parse the content to identify which command and what wave/phase needs to continue
- Store this information for display in Step 5

If the file does NOT exist:
- Note that no handoff is pending

## Step 4: Check Available Outputs

Scan for completed workflow outputs across all categories:

### Survey outputs

```bash
test -f .banneker/survey.json && echo "survey.json: exists" || echo "survey.json: missing"
test -f .banneker/architecture-decisions.json && echo "architecture-decisions.json: exists" || echo "architecture-decisions.json: missing"
```

### Documents

```bash
if [ -d .banneker/documents ]; then
  echo "Documents directory exists"
  ls .banneker/documents/*.md 2>/dev/null | while read doc; do
    echo "  - $(basename "$doc")"
  done
else
  echo "Documents directory: missing"
fi
```

### Diagrams

```bash
if [ -d .banneker/diagrams ]; then
  echo "Diagrams directory exists"
  ls .banneker/diagrams/*.html 2>/dev/null | while read diagram; do
    echo "  - $(basename "$diagram")"
  done
else
  echo "Diagrams directory: missing"
fi
```

### Appendix

```bash
if [ -d .banneker/appendix ]; then
  echo "Appendix directory exists"
  test -f .banneker/appendix/index.html && echo "  - index.html" || echo "  - index.html: missing"
  ls .banneker/appendix/*.html 2>/dev/null | grep -v "index.html" | while read page; do
    echo "  - $(basename "$page")"
  done
else
  echo "Appendix directory: missing"
fi
```

### Exports

```bash
if [ -d .banneker/exports ]; then
  echo "Exports directory exists"
  ls .banneker/exports/* 2>/dev/null | while read export; do
    echo "  - $(basename "$export")"
  done
else
  echo "Exports directory: missing"
fi
```

### Audit reports

```bash
test -f .banneker/audit-report.json && echo "audit-report.json: exists" || echo "audit-report.json: missing"
test -f .banneker/audit-report.md && echo "audit-report.md: exists" || echo "audit-report.md: missing"
```

Store all output availability information for display in Step 5.

## Step 5: Display Summary

Display grouped status based on the information collected in Steps 2-4:

### In Progress Section

If state files exist (from Step 2), display:

```
## In Progress

Commands currently running or interrupted:

[For each state file:]
- **[command_name]** — [status]
  - Started: [started_at]
  - Progress: [items_completed]/[items_total] ([percentage]%)
  - Current: [current_position]
```

If no state files exist, skip this section.

### Pending Handoff Section

If a handoff file exists (from Step 3), display:

```
## Pending Handoff

A command needs to be resumed:

[Display handoff file contents]

To resume: Run the command again (it will auto-detect the handoff)
```

If no handoff file exists, skip this section.

### Completed Outputs Section

Based on output scans from Step 4, display:

```
## Completed Outputs

Available artifacts from previous commands:

**Survey:**
- survey.json [if exists]
- architecture-decisions.json [if exists]

**Documents:** [count] documents
[List each document if directory exists]

**Diagrams:** [count] diagrams
[List each diagram if directory exists]

**Appendix:** [count] pages
[List each page if directory exists]

**Exports:** [count] exports
[List each export if directory exists]

**Audit Reports:**
- audit-report.json [if exists]
- audit-report.md [if exists]
```

Display only sections that have content. If a category has no outputs, show "[category]: none".

### Next Steps Section

Based on what exists and what's missing, recommend the next logical command:

**If no survey.json and no state files:**
```
## Next Steps

Start your Banneker workflow:

1. /banneker:survey — Conduct discovery interview (greenfield)
   OR
   /banneker:document — Analyze existing codebase (brownfield)
```

**If survey.json exists but no documents:**
```
## Next Steps

Continue your workflow:

1. /banneker:architect — Generate planning documents from survey
```

**If documents exist but no diagrams:**
```
## Next Steps

Continue your workflow:

1. /banneker:roadmap — Generate architecture diagrams
```

**If diagrams exist but no appendix:**
```
## Next Steps

Continue your workflow:

1. /banneker:appendix — Compile HTML reference
```

**If appendix exists but no exports:**
```
## Next Steps

Continue your workflow:

1. /banneker:feed — Export to downstream frameworks
```

**If everything exists and no state files:**
```
## Next Steps

Your Banneker workflow is complete!

Optional next steps:
- /banneker:audit — Evaluate planning document completeness
- Review outputs in .banneker/
- Use exports in .banneker/exports/ for downstream tools
```

**If state files or handoff files exist:**
```
## Next Steps

Resume interrupted command:

1. Run the in-progress command again (it will auto-detect resume)
```

Adapt the recommendation based on actual project state — the above are templates to guide the logic.

## Step 6: Exit

Display a friendly closing message:

```
---

Run /banneker:help for command reference.
```

Exit successfully.

## Important Implementation Notes

- This is a stateless, read-only command — no state tracking or resume detection needed
- The command reads state files but does NOT modify them
- All file operations (test, ls, cat, grep) are executed via the runtime's Bash tool
- State file format uses YAML frontmatter + markdown body (established in Phase 3)
- Progress calculation uses bash arithmetic: `percent=$((checked * 100 / total))`
- The next steps logic should be smart: detect what's complete and suggest the natural next command
- If both in-progress state files AND completed outputs exist, prioritize resuming the interrupted command
- Handle edge cases gracefully: empty directories, missing fields, malformed state files should not crash the command
