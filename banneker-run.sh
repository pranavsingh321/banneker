#!/bin/bash
set -euo pipefail

# Banneker CLI wrapper - runs Banneker commands via opencode
# Usage: ./banneker-run.sh [command]
# Commands: document, survey, architect, roadmap, appendix, feed, audit, all (default: all)

COMMAND="${1:-all}"

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
    echo "Usage: $0 [document|survey|architect|roadmap|appendix|feed|audit|all]"
    exit 1
    ;;
esac

echo "==> Done!"
