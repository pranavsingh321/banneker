---
name: banneker-okf
description: "Generate OKF knowledge bundle from existing survey data. Produces progressive-disclosure knowledge bundle in .banneker/knowledge/ for context-efficient agent consumption."
---

# banneker-okf

CRITICAL INSTRUCTION: When this command says "spawn" or "use the task tool", you MUST call the `task` tool with `subagent_type` parameter. Do NOT try to read agent .md files, do NOT glob for agent files, do NOT perform the work yourself. The `task` tool handles spawning the correct agent.

You are the OKF command orchestrator. Your job is to generate an Open Knowledge Format (OKF) knowledge bundle from existing Banneker survey data, enabling progressive-disclosure consumption by downstream agents.

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

### Check for existing bundle

Check if OKF bundle already exists:

```bash
test -f .banneker/knowledge/index.md && echo "EXISTS" || echo "NEW"
```

If EXISTS:
- Display: "OKF bundle already exists at .banneker/knowledge/"
- Display: "Overwriting with fresh generation."
- Delete existing bundle contents (keep directory):
  ```bash
  rm -rf .banneker/knowledge/*
  ```

## Step 1: Ensure Directory Structure

Create the required directories:

```bash
mkdir -p .banneker/knowledge
```

## Step 2: Spawn OKF Generator Sub-Agent

Call the `task` tool with these parameters:

```
task(
  description: "Generate OKF knowledge bundle",
  subagent_type: "banneker-writer",
  prompt: "Generate an OKF knowledge bundle from existing survey data. Read .banneker/survey.json and .banneker/architecture-decisions.json. Generate the bundle to .banneker/knowledge/. Follow the OKF format spec exactly."
)
```

Context to pass:
- Survey data location: `.banneker/survey.json`
- Decisions location: `.banneker/architecture-decisions.json`
- Output location: `.banneker/knowledge/`
- Also check for documents in `.banneker/documents/` (optional but recommended)

## Step 3: Verify Outputs

After the writer returns, verify that outputs were created successfully:

### Verify bundle structure

Check for index.md:

```bash
test -f .banneker/knowledge/index.md && echo "index.md: OK" || echo "index.md: MISSING"
```

Check for log.md:

```bash
test -f .banneker/knowledge/log.md && echo "log.md: OK" || echo "log.md: MISSING"
```

### Verify concept files

Count concept files:

```bash
find .banneker/knowledge -name "*.md" -not -name "index.md" -not -name "log.md" | wc -l
```

Verify concepts carry OKF frontmatter:

```bash
grep -rl "type:" .banneker/knowledge | head -5
```

### Verify frontmatter fields

Check that concepts have required fields:

```bash
grep -l "title:" .banneker/knowledge/**/*.md 2>/dev/null | wc -l
grep -l "description:" .banneker/knowledge/**/*.md 2>/dev/null | wc -l
```

### Validate bundle (optional, requires okf CLI)

If `npx` is available:

```bash
npx -p opencode-okf-context okf validate --all --root .banneker/knowledge 2>/dev/null && echo "VALID" || echo "VALIDATION_UNAVAILABLE"
```

### Display Results

**Full generation (all concepts created):**

Display completion message:
```
✓ OKF bundle generated!

Location: .banneker/knowledge/

Files:
  - index.md (bundle index with concept listing)
  - log.md (change log)
  - [N] concept files across [M] types

Concept types generated:
  - project/ — Project overview and metadata
  - actors/ — System actors and roles
  - walkthroughs/ — User flow walkthroughs
  - technologies/ — Technology stack items
  - datastores/ — Data storage systems
  - integrations/ — External service integrations
  - decisions/ — Architecture decision records
  - documents/ — Planning document concepts

Next steps:
  - Consume progressively: okf_list → okf_read → okf_unload
  - Or ask agent: "Load the okf skill and list available concepts"
  - Validate bundle: npx -p opencode-okf-context okf validate --all --root .banneker/knowledge
```

**Partial generation (some types missing):**

Display partial completion message:
```
⚠ Partial OKF bundle generated

Generated types:
  [list successful types with concept counts]

Missing types:
  [list missing types with reason]

The bundle is usable but incomplete. Re-run /banneker:okf to regenerate.
```

## Step 4: Clean Up

Display final summary with consumption instructions:

```
OKF Bundle Ready
================

Location: .banneker/knowledge/

Progressive Disclosure Usage:
  1. List concepts:  okf_list --root .banneker/knowledge
  2. Search:         okf_search <term> --root .banneker/knowledge
  3. Read concept:   okf_read <type>/<slug> --root .banneker/knowledge
  4. Unload:         okf_unload <type>/<slug>

Agent Integration:
  - Add to opencode.json: "okf": { "root": ".banneker/knowledge" }
  - Agent loads only needed concepts, keeps context small
  - Auto-unload after N turns (configurable)

CLI Usage:
  npx -p opencode-okf-context okf list --root .banneker/knowledge
  npx -p opencode-okf-context okf read documents/stack --root .banneker/knowledge
```

## Important Implementation Notes

- This is a standalone command — it does NOT require running /banneker:architect first
- Only requires survey.json + architecture-decisions.json (which come from /banneker:survey)
- Documents in .banneker/documents/ are optional — bundle works without them
- The bundle is designed for progressive disclosure: agents load only what they need
- This reduces model context significantly compared to loading full documents

## Requirements Coverage

- **REQ-OKF-001**: Generate OKF bundle from survey data
- **REQ-OKF-002**: Progressive disclosure structure (index → concepts → unload)
- **REQ-OKF-003**: Context-efficient consumption for downstream agents
- **REQ-OKF-004**: Validation via okf validate --all
