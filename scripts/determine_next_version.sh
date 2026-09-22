#!/usr/bin/env bash

set -exu

semanticRelease=$(npx semantic-release --dry-run --ci false 2>&1)
version=$(echo "$semanticRelease" | sed -nE 's/.*(The next release version is |Published release |Skip v)([0-9]+\.[0-9]+\.[0-9]+).*/\2/p' | head -n 1)

echo "$version" > "$VERSION_FILE"
