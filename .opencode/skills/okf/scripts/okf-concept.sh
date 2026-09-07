#!/usr/bin/env bash
# okf-concept.sh — create or update a single OKF concept with valid frontmatter.
# Usage: okf-concept.sh <bundle-dir> <type> <slug> <title> <description> [tags...]
set -euo pipefail

bundle_dir="${1:?usage: okf-concept.sh <bundle-dir> <type> <slug> <title> <description> [tags...]}"
type="$2"
slug="$3"
title="$4"
description="$5"
shift 5 || true
tags=("$@")

concept_dir="$bundle_dir/$type"
concept_file="$concept_dir/$slug.md"
mkdir -p "$concept_dir"

tag_line=""
if ((${#tags[@]} > 0)); then
  tag_list=$(printf '%s, ' "${tags[@]}")
  tag_list="${tag_list%, }"
  tag_line="tags: [$tag_list]"
fi

cat > "$concept_file" <<EOF
---
type: $type
title: $title
description: $description
$tag_line
---

# $title

$description
EOF

echo "Concept written to $concept_file"
echo "Next: edit the body, update index.md/log.md, then 'okf validate --all --root $bundle_dir'"