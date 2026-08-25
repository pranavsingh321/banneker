#!/bin/bash
set -euo pipefail

# Banneker CLI wrapper - runs Banneker commands via opencode
# Usage: ./banneker-run.sh [--target <path>] [command]
# Commands: document, survey, architect, roadmap, appendix, feed, audit, all (default: all)

TARGET_DIR=""
COMMAND="all"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET_DIR="$2"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1"
      echo "Usage: $0 [--target <path>] [command]"
      exit 1
      ;;
    *)
      COMMAND="$1"
      shift
      ;;
  esac
done

if [[ -n "$TARGET_DIR" ]]; then
  if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: Directory not found: $TARGET_DIR"
    exit 1
  fi
  echo "==> Installing Banneker in $TARGET_DIR..."
  (cd "$TARGET_DIR" && npx banneker --opencode --local)
fi

echo "==> Running Banneker: $COMMAND"

if [[ -n "$TARGET_DIR" ]]; then
  WORK_DIR="$TARGET_DIR"
else
  WORK_DIR="."
fi

run_banneker() {
  local cmd="$1"
  echo "==> Running /banneker:${cmd}..."
  opencode run --dir "$WORK_DIR" --command "banneker-${cmd}" --auto
  echo "==> /banneker:${cmd} finished."
}

case "$COMMAND" in
  document|survey|architect|roadmap|appendix|feed|audit)
    run_banneker "$COMMAND"
    ;;
  all)
    run_banneker "document"
    run_banneker "roadmap"
    run_banneker "appendix"
    ;;
  *)
    echo "Unknown command: $COMMAND"
    echo "Usage: $0 [--target <path>] [document|survey|architect|roadmap|appendix|feed|audit|all]"
    exit 1
    ;;
esac

echo "==> Done!"
