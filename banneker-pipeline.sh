#!/bin/bash
set -euo pipefail

# Banneker CI/CD Pipeline Script
# Platform-agnostic automation for codebase analysis and planning document generation.
#
# Usage:
#   ./banneker-pipeline.sh                                      # uses defaults
#   TARGET_DIR=./my-repo ./banneker-pipeline.sh                 # analyze my-repo, store results here
#   TARGET_DIR=./my-repo OUTPUT_DIR=./reports ./banneker-pipeline.sh  # custom output location
#
# Environment Variables:
#   TARGET_DIR       - Path to the repository to analyze (required)
#   OUTPUT_DIR       - Where to store results (default: ./banneker-output/<target-name>)
#   BRANCH           - Branch to commit results back to (default: banneker/auto-docs)
#   BANNEKER_STEPS   - Comma-separated steps to run (default: document,architect)
#   SKIP_COMMIT      - Set to "true" to skip git commit/push (default: false)
#   CLEAN_TARGET     - Set to "true" to remove .banneker/ from target after copy (default: false)
#   OPENCODE_BIN     - Path to opencode binary (default: opencode)

TARGET_DIR="${TARGET_DIR:?ERROR: TARGET_DIR is required}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_NAME="$(basename "$TARGET_DIR")"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/banneker-output/$TARGET_NAME}"
BRANCH="${BRANCH:-banneker/auto-docs}"
BANNEKER_STEPS="${BANNEKER_STEPS:-document,architect}"
SKIP_COMMIT="${SKIP_COMMIT:-false}"
CLEAN_TARGET="${CLEAN_TARGET:-false}"
OPENCODE_BIN="${OPENCODE_BIN:-opencode}"
COMMIT_MSG="banneker: update analysis $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log() { echo "==> $*"; }
fail() { echo "ERROR: $*" >&2; exit 1; }

check_deps() {
  local missing=()
  command -v "$OPENCODE_BIN" >/dev/null 2>&1 || missing+=("opencode")
  command -v node          >/dev/null 2>&1 || missing+=("node")
  command -v npm           >/dev/null 2>&1 || missing+=("npm")
  command -v git           >/dev/null 2>&1 || missing+=("git")
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

  # Overlay our fixed commands/agents (npm version may be outdated)
  if [[ -d "$SCRIPT_DIR/commands" ]]; then
    log "Overlaying fixed commands..."
    mkdir -p "$TARGET_DIR/.opencode/commands" "$TARGET_DIR/.opencode/agents"
    cp "$SCRIPT_DIR"/commands/banneker-*.md "$TARGET_DIR/.opencode/commands/"
    [[ -f "$SCRIPT_DIR/commands/VERSION" ]] && cp "$SCRIPT_DIR/commands/VERSION" "$TARGET_DIR/.opencode/commands/"
  fi
  if [[ -d "$SCRIPT_DIR/agents" ]]; then
    cp "$SCRIPT_DIR"/agents/banneker-*.md "$TARGET_DIR/.opencode/agents/"
  fi
}

run_step() {
  local step="$1"
  log "Running /banneker:${step}..."
  "$OPENCODE_BIN" run --dir "$TARGET_DIR" --command "banneker-${step}" --auto
  log "/banneker:${step} complete."
}

# Copy .banneker/ from target to output dir
copy_results() {
  mkdir -p "$OUTPUT_DIR"
  if [[ -d "$TARGET_DIR/.banneker" ]]; then
    cp -r "$TARGET_DIR/.banneker/"* "$OUTPUT_DIR/" 2>/dev/null || true
    log "Results copied to $OUTPUT_DIR/"
  fi
}

# Auto-generate survey.json from codebase-understanding.md if it doesn't exist.
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

commit_results() {
  if [[ "$SKIP_COMMIT" == "true" ]]; then
    log "Skipping commit (SKIP_COMMIT=true)."
    return
  fi

  cd "$SCRIPT_DIR"

  # Check if there are changes to commit
  if git diff --quiet "banneker-output/$TARGET_NAME/" 2>/dev/null && \
     [[ -z "$(git ls-files --others --exclude-standard "banneker-output/$TARGET_NAME/" 2>/dev/null)" ]]; then
    log "No changes in banneker-output/$TARGET_NAME/ to commit."
    return
  fi

  # Configure git if needed
  git config user.email "${GIT_USER_EMAIL:-banneker-bot[bot]@users.noreply.github.com}" 2>/dev/null || true
  git config user.name  "${GIT_USER_NAME:-banneker-bot}" 2>/dev/null || true

  # Create or switch to the target branch
  if ! git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
    git checkout -b "$BRANCH"
  else
    git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH"
  fi

  # Stage and commit
  git add "banneker-output/$TARGET_NAME/"
  git commit -m "$COMMIT_MSG" || {
    log "Nothing to commit."
    return
  }

  # Push if remote exists
  if git remote get-url origin >/dev/null 2>&1; then
    log "Pushing to origin/$BRANCH..."
    git push origin "$BRANCH" || log "WARNING: Push failed. Commit created locally."
  else
    log "No remote configured. Commit created locally."
  fi

  log "Results committed to branch: $BRANCH"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

log "Banneker Pipeline starting."
log "  Target:    $TARGET_DIR"
log "  Output:    $OUTPUT_DIR"
log "  Branch:    $BRANCH"
log "  Steps:     $BANNEKER_STEPS"
log "  Commit:    $SKIP_COMMIT"

[[ -d "$TARGET_DIR" ]] || fail "Directory not found: $TARGET_DIR"

check_deps
install_banneker

IFS=',' read -ra STEPS <<< "$BANNEKER_STEPS"

for step in "${STEPS[@]}"; do
  step="$(echo "$step" | xargs)"  # trim whitespace

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
      # Architect needs survey.json — auto-generate if missing
      auto_generate_survey
      run_step "architect"
      copy_results
      ;;
    roadmap|appendix|feed|audit)
      run_step "$step"
      copy_results
      ;;
    *)
      log "WARNING: Unknown step '$step', skipping."
      ;;
  esac
done

# Optionally clean up target's .banneker/
if [[ "$CLEAN_TARGET" == "true" ]]; then
  rm -rf "$TARGET_DIR/.banneker"
  log "Cleaned .banneker/ from target directory."
fi

commit_results

log "Pipeline complete."
log "Output location: $OUTPUT_DIR/"
