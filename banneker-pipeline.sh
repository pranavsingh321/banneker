#!/bin/bash
set -euo pipefail

# Banneker CI/CD Pipeline Script
# Platform-agnostic automation for codebase analysis and planning document generation.
#
# Usage:
#   ./banneker-pipeline.sh                          # uses defaults
#   TARGET_DIR=./my-repo BRANCH=main ./banneker-pipeline.sh
#
# Environment Variables:
#   TARGET_DIR       - Path to the repository to analyze (required)
#   BRANCH           - Branch to commit results back to (default: banneker/auto-docs)
#   BANNEKER_STEPS   - Comma-separated steps to run (default: document,architect)
#   SKIP_COMMIT      - Set to "true" to skip git commit/push (default: false)
#   OPENCODE_BIN     - Path to opencode binary (default: opencode)

TARGET_DIR="${TARGET_DIR:?ERROR: TARGET_DIR is required}"
BRANCH="${BRANCH:-banneker/auto-docs}"
BANNEKER_STEPS="${BANNEKER_STEPS:-document,architect}"
SKIP_COMMIT="${SKIP_COMMIT:-false}"
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
}

run_step() {
  local step="$1"
  log "Running /banneker:${step}..."
  "$OPENCODE_BIN" run --dir "$TARGET_DIR" --command "banneker-${step}" --auto
  log "/banneker:${step} complete."
}

# Auto-generate survey.json from codebase-understanding.md if it doesn't exist.
# This enables the architect step to run without an interactive interview.
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

  cd "$TARGET_DIR"

  # Check if there are changes to commit
  if git diff --quiet .banneker/ 2>/dev/null && \
     [[ -z "$(git ls-files --others --exclude-standard .banneker/ 2>/dev/null)" ]]; then
    log "No changes in .banneker/ to commit."
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
  git add .banneker/
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
      ;;
    survey)
      run_step "survey"
      ;;
    architect)
      # Architect needs survey.json — auto-generate if missing
      auto_generate_survey
      run_step "architect"
      ;;
    roadmap|appendix|feed|audit)
      run_step "$step"
      ;;
    *)
      log "WARNING: Unknown step '$step', skipping."
      ;;
  esac
done

commit_results

log "Pipeline complete."
log "Output location: $TARGET_DIR/.banneker/"
