#!/usr/bin/env bash
# okf-init.sh — scaffold a new OKF knowledge bundle.
# Usage: okf-init.sh <bundle-dir> <bundle-name> [description]
set -euo pipefail

bundle_dir="${1:?usage: okf-init.sh <bundle-dir> <bundle-name> [description]}"
bundle_name="$2"
description="${3:-Knowledge bundle ${bundle_name}}"

mkdir -p "$bundle_dir"

# index.md
cat > "$bundle_dir/index.md" <<EOF
---
okf_version: 0.2
name: $bundle_name
description: $description
---

# $bundle_name

$description

## Bundles

This section is maintained for one-level navigation. Add a \`type\` list per
concept type discovered below.

\`\`\`
type | id | title
-----|----|-------
\`\`\`
EOF

# log.md
cat > "$bundle_dir/log.md" <<'EOF'
# Bundle Log

Changes to this bundle. Append a line per change:

- `YYYY-MM-DD`: added/updated/removed `type/slug` — short description
EOF

echo "OKF bundle scaffolded at $bundle_dir"
echo "  index.md: created"
echo "  log.md:   created"
echo "Next: add concepts with okf-concept.sh, then run 'okf validate --all --root $bundle_dir'"