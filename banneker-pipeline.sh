#!/bin/bash
set -euo pipefail

# Banneker CI/CD Pipeline Script
# Analyzes a target repo and stores results locally.
#
# Usage:
#   ./banneker-pipeline.sh
#   TARGET_DIR=~/repos/nova ./banneker-pipeline.sh
#   TARGET_DIR=~/repos/nova BANNEKER_STEPS=document,architect,roadmap,appendix ./banneker-pipeline.sh
#
# Environment Variables:
#   TARGET_DIR       - Path to the repository to analyze (required)
#   OUTPUT_DIR       - Where to store results (default: ./banneker-output/<target-name>)
#   BANNEKER_STEPS   - Comma-separated steps to run (default: all pipeline-ready steps)
#   MINIMAL          - Set to "true" to run only document,architect,audit
#   OPENCODE_BIN     - Path to opencode binary (default: opencode)

TARGET_DIR="${TARGET_DIR:?ERROR: TARGET_DIR is required}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_NAME="$(basename "$TARGET_DIR")"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/banneker-output/$TARGET_NAME}"
MINIMAL="${MINIMAL:-false}"
if [[ "$MINIMAL" == "true" ]]; then
  BANNEKER_STEPS="document,architect,audit"
else
  BANNEKER_STEPS="${BANNEKER_STEPS:-document,architect,audit,roadmap,appendix,engineer,feed,plat}"
fi
OPENCODE_BIN="${OPENCODE_BIN:-opencode}"

log() { echo "==> $*"; }
fail() { echo "ERROR: $*" >&2; exit 1; }

check_deps() {
  local missing=()
  command -v "$OPENCODE_BIN" >/dev/null 2>&1 || missing+=("opencode")
  command -v node          >/dev/null 2>&1 || missing+=("node")
  command -v npm           >/dev/null 2>&1 || missing+=("npm")
  if (( ${#missing[@]} )); then
    fail "Missing required tools: ${missing[*]}"
  fi
}

install_banneker() {
  if [[ ! -d "$TARGET_DIR/.opencode/commands" ]]; then
    log "Installing Banneker in $TARGET_DIR..."
    (cd "$TARGET_DIR" && npx banneker --opencode --local)
  else
    log "Banneker already installed in $TARGET_DIR"
  fi

  if [[ -d "$SCRIPT_DIR/commands" ]]; then
    log "Overlaying fixed commands..."
    mkdir -p "$TARGET_DIR/.opencode/commands" "$TARGET_DIR/.opencode/agents"
    cp "$SCRIPT_DIR"/commands/banneker-*.md "$TARGET_DIR/.opencode/commands/"
    [[ -f "$SCRIPT_DIR/commands/VERSION" ]] && cp "$SCRIPT_DIR/commands/VERSION" "$TARGET_DIR/.opencode/commands/"
  fi
  if [[ -d "$SCRIPT_DIR/agents" ]]; then
    cp "$SCRIPT_DIR"/agents/banneker-*.md "$TARGET_DIR/.opencode/agents/"
  fi
  if [[ -d "$SCRIPT_DIR/.opencode/skills" ]]; then
    log "Overlaying OKF skill..."
    mkdir -p "$TARGET_DIR/.opencode/skills"
    cp -r "$SCRIPT_DIR/.opencode/skills/"* "$TARGET_DIR/.opencode/skills/"
  fi
  if [[ -f "$SCRIPT_DIR/.opencode/okf.jsonc" ]]; then
    log "Overlaying OKF plugin config..."
    cp "$SCRIPT_DIR/.opencode/okf.jsonc" "$TARGET_DIR/.opencode/okf.jsonc"
  fi
}

run_step() {
  local step="$1"
  log "Running /banneker:${step}..."
  "$OPENCODE_BIN" run --dir "$TARGET_DIR" --command "banneker-${step}" --auto
  log "/banneker:${step} complete."
}

copy_results() {
  mkdir -p "$OUTPUT_DIR"
  if [[ -d "$TARGET_DIR/.banneker" ]]; then
    cp -r "$TARGET_DIR/.banneker/"* "$OUTPUT_DIR/" 2>/dev/null || true
    log "Results copied to $OUTPUT_DIR/"
  fi
}

auto_generate_survey() {
  local survey="$TARGET_DIR/.banneker/survey.json"
  local understanding="$TARGET_DIR/.banneker/codebase-understanding.md"

  if [[ -f "$survey" ]]; then
    log "survey.json already exists, skipping auto-generation."
    return
  fi

  if [[ ! -f "$understanding" ]]; then
    log "No codebase-understanding.md found. Run 'document' step first."
    return
  fi

  log "Auto-generating survey.json from codebase analysis..."

  "$OPENCODE_BIN" run --dir "$TARGET_DIR" --auto \
    "Read .banneker/codebase-understanding.md and generate .banneker/survey.json matching the Banneker survey schema. Include: survey_metadata (version, created, runtime), project (name, one_liner, problem_statement, has_backend, has_frontend, project_type, scale), actors array (all system and human actors found), walkthroughs array (key user journeys), backend object (technologies, database, messaging, authentication, deployment, architecture_pattern, driver_ecosystem, api_style, entry_points), gaps array. Write the file to .banneker/survey.json. Also generate .banneker/architecture-decisions.json with a decisions array containing key architectural decisions found in the codebase (id, question, choice, rationale, alternatives_considered, phase, timestamp)."

  if [[ -f "$survey" ]]; then
    log "survey.json generated successfully."
  else
    log "WARNING: survey.json was not created. Architect step may fail."
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

log "Banneker Pipeline starting."
log "  Target:  $TARGET_DIR"
log "  Output:  $OUTPUT_DIR"
log "  Steps:   $BANNEKER_STEPS"

[[ -d "$TARGET_DIR" ]] || fail "Directory not found: $TARGET_DIR"

check_deps
install_banneker

IFS=',' read -ra STEPS <<< "$BANNEKER_STEPS"

for step in "${STEPS[@]}"; do
  step="$(echo "$step" | xargs)"

  case "$step" in
    document)
      run_step "document"
      copy_results
      ;;
    survey)
      run_step "survey"
      copy_results
      ;;
    architect)
      auto_generate_survey
      run_step "architect"
      copy_results
      ;;
    roadmap|appendix|feed|audit|engineer|plat)
      run_step "$step"
      copy_results
      ;;
    *)
      log "WARNING: Unknown step '$step', skipping."
      ;;
  esac
done

log "Pipeline complete."
log "Output: $OUTPUT_DIR/"
