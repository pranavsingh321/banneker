# AGENTS.md

This repo is the **Banneker Runner** — tooling that installs the Banneker CLI into a *target* repo and analyzes it. It is not a normal application: there is no root `package.json`, no test/lint/build tooling. The "code" is markdown command/agent definitions plus bash scripts. Verification is running the pipeline.

## Layout

- `banneker-pipeline.sh` — non-interactive CI/CD pipeline. Requires `TARGET_DIR` (fails otherwise). Installs Banneker into the target, overlays this repo's files, runs steps, copies results to `banneker-output/<target-name>/` (or `$OUTPUT_DIR`).
- `banneker-run.sh` — interactive CLI wrapper around `opencode run --command banneker-<step>`.
- `commands/banneker-*.md` + `commands/VERSION` — command definitions (source of truth), overlaid onto target `.opencode/commands/`.
- `agents/banneker-*.md` — sub-agent definitions, overlaid onto target `.opencode/agents/`.
- `.opencode/` — OKF integration only: `skills/okf/` (skill + `reference/` + helper scripts) and `okf.jsonc` (plugin config). Not the command/agent source; those live in the top-level dirs.
- `opencode.json` — registers the `opencode-okf-context` plugin.
- Prefer editing top-level `commands/` and `agents/` over the copies users may have in targets.

## Pipeline facts

- Env vars: `TARGET_DIR` (required), `OUTPUT_DIR`, `BANNEKER_STEPS`, `MINIMAL=true` (→ `document,architect,audit`), `OPENCODE_BIN`.
- Default steps: `document,architect,audit,roadmap,appendix,engineer,feed,plat`.
- Step order matters: `okf`/`feed` need `survey.json` + `architecture-decisions.json` (produced by `survey`); `architect` auto-generates `survey.json` from `codebase-understanding.md` instead of prompting. `roadmap` needs survey data too.
- Steps run as `opencode run --dir "$TARGET_DIR" --command "banneker-${step}" --auto`.
- Results are written to the target's `.banneker/`, then `cp -r`'d to the output dir — each run overwrites, so a failed/late step can clobber earlier artifacts.
- New steps/commands/agents must: exist as `banneker-<name>.md` in `commands/` and `agents/`, be added to the `run_step` case in the pipeline, and listed in the README tables.

## Command/agent authoring rules

- Every command mandates: spawn work via the `task` tool with `subagent_type`; never read/glob the agent `.md` files or do the work inline ("CRITICAL INSTRUCTION" at the top of each command).
- Commands self-check prerequisites (`survey.json`, `architecture-decisions.json`) in "Step 0" and abort with a "Run /banneker:survey first" message when missing.
- Keep the `VERSION` file (currently `0.2.0`) in sync with command changes — it's copied into targets.

## OKF

- Bundle target for the plugin is `.banneker/knowledge` (`okf.jsonc`, `bundles[0].path`); `documents/*` is a `protectedConcepts` (read-only) set.
- Skill lives at `.opencode/skills/okf/SKILL.md` with spec in `reference/okf-format.md` and tools in `reference/okf-plugin.md`. Scripts: `okf-init.sh`, `okf-concept.sh`.
- `.opencode/` is its own node package (`package.json` + `package-lock.json`) that is gitignored; a fresh clone still works because `opencode.json` fetches the plugin via npx.

## Style

- Scripts use `set -euo pipefail` and `log()`/`fail()` helpers — follow that pattern.
- CI: `.github/workflows/banneker.yml` sets `OPENCODE_MODEL` and commits results back to the target repo.