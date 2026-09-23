#!/usr/bin/env bash

set -exu

if [ -n "${GITHUB_REF_NAME:-}" ] && [[ "${GITHUB_REF:-}" == refs/tags/* ]]; then
  version="${GITHUB_REF_NAME#v}"
elif [[ "${GITHUB_REF:-}" =~ ^refs/tags/v?(.*) ]]; then
  version="${BASH_REMATCH[1]}"
elif [ -n "${GITHUB_REF_NAME:-}" ] && [[ "$GITHUB_REF_NAME" =~ ^v?[0-9]+\.[0-9]+ ]]; then
  version="${GITHUB_REF_NAME#v}"
else
  version="1.0.0"
fi

echo "$version" > "${VERSION_FILE:-VERSION.txt}"
