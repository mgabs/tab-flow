#!/usr/bin/env bash

set -euo pipefail

# Write tag_name and release body to $GITHUB_OUTPUT for the GitHub release step
version="$(cat "$VERSION_FILE" 2>/dev/null || true)"
if [ -z "$version" ]; then
  echo "tag_name=" >> "$GITHUB_OUTPUT"
  echo "body=" >> "$GITHUB_OUTPUT"
  exit 0
fi

echo "tag_name=v$version" >> "$GITHUB_OUTPUT"
echo "body<<EOF" >> "$GITHUB_OUTPUT"
awk '/^##? \[/{if(found) exit; found=1; next} found' changelog.md >> "$GITHUB_OUTPUT"
echo "EOF" >> "$GITHUB_OUTPUT"
