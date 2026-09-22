#!/usr/bin/env bash

set -euo pipefail

version="$(cat "${VERSION_FILE:-VERSION.txt}" 2>/dev/null || true)"
tag_name="${GITHUB_REF_NAME:-v${version#v}}"

echo "tag_name=$tag_name" >> "$GITHUB_OUTPUT"
echo "body<<EOF" >> "$GITHUB_OUTPUT"
body=$(awk '/^##? \[/{if(found) exit; found=1; next} found' changelog.md 2>/dev/null || true)
if [ -n "$body" ]; then
  echo "$body" >> "$GITHUB_OUTPUT"
else
  echo "Release $tag_name" >> "$GITHUB_OUTPUT"
fi
echo "EOF" >> "$GITHUB_OUTPUT"
