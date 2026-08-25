#!/bin/bash
set -euo pipefail

# Banneker Setup Script
# Installs Banneker commands into a target project for opencode
# Usage: ./setup.sh [target-directory]

TARGET_DIR="${1:-.}"

echo "==> Setting up Banneker in: $TARGET_DIR"

# Validate Node.js
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is required (>= 18.0.0)"
    echo "Install from https://nodejs.org/"
    exit 1
fi

NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "Error: Node.js >= 18.0.0 required (found $(node -v))"
    exit 1
fi

# Validate opencode
if ! command -v opencode &> /dev/null; then
    echo "Error: opencode is required"
    echo "Install from https://opencode.ai"
    exit 1
fi

# Install Banneker commands into the target project
echo "==> Installing Banneker commands (local)..."
cd "$TARGET_DIR"
npx banneker --opencode --local

echo ""
echo "==> Setup complete!"
echo ""
echo "Available commands:"
echo "  /banneker:document   - Analyze existing codebase"
echo "  /banneker:survey     - Discovery interview (new projects)"
echo "  /banneker:architect  - Generate planning documents"
echo "  /banneker:roadmap    - Generate architecture diagrams"
echo "  /banneker:appendix   - Compile HTML reference"
echo "  /banneker:feed       - Export to downstream frameworks"
echo ""
echo "Or use the wrapper script:"
echo "  ./banneker-run.sh [document|survey|architect|roadmap|appendix|feed|all]"
