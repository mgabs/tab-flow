#!/usr/bin/env bash

set -exu

if [ -z "${GH_TOKEN:-}" ]; then
  echo "GH_TOKEN (WEBSITE_DISPATCH_TOKEN) is not set; skipping website update."
  exit 0
fi

gh api "repos/${GITHUB_REPOSITORY:-mgabs/alt-tab-macos}-website/dispatches" -f event_type=update-website
