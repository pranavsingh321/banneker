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
  cd "$TARGET_DIR"
  echo "==> Installing Banneker in $TARGET_DIR..."
  npx banneker --opencode --local
fi

echo "==> Running Banneker: $COMMAND"

case "$COMMAND" in
  document)
    opencode -c "Run /banneker:document to analyze this codebase"
    ;;
  survey)
    opencode -c "Run /banneker:survey to start the discovery interview"
    ;;
  architect)
    opencode -c "Run /banneker:architect to generate planning documents"
    ;;
  roadmap)
    opencode -c "Run /banneker:roadmap to generate architecture diagrams"
    ;;
  appendix)
    opencode -c "Run /banneker:appendix to compile HTML reference"
    ;;
  feed)
    opencode -c "Run /banneker:feed to export planning artifacts"
    ;;
  audit)
    opencode -c "Run /banneker:audit to evaluate planning documents"
    ;;
  all)
    opencode -c "
      Run /banneker:document to analyze the codebase.
      Then run /banneker:roadmap to generate architecture diagrams.
      Then run /banneker:appendix to compile HTML reference.
      Show me the results.
    "
    ;;
  *)
    echo "Unknown command: $COMMAND"
    echo "Usage: $0 [--target <path>] [document|survey|architect|roadmap|appendix|feed|audit|all]"
    exit 1
    ;;
esac

echo "==> Done!"
