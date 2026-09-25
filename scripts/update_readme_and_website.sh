#!/usr/bin/env bash

set -exu

githubRepo="${GITHUB_REPOSITORY:-mgabs/alt-tab-macos}"

github_api_request() {
  local url="$1"
  curl -s \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$githubRepo$url"
}

unicode_sort() {
  python3 -c 'import sys, unicodedata; print("".join(sorted((line for line in sys.stdin if line.strip()), key=lambda s: unicodedata.normalize("NFKD", s.casefold()))), end="")'
}

github_contributors() {
  github_api_request "/contributors" |
    jq -r '.[]|("[" + .login + "](" + .html_url + ")")' |
    sed -e '/semantic-release-bot/d' |
    unicode_sort |
    awk '{printf "%s%s", sep, $0; sep=", "} END{print ""}'
}

# Rewrite only the "Developed the app" section of docs/contributors.md, preserving the
# frozen "Localized the app" section below it.
update_developer_contributors() {
  local file="docs/contributors.md"
  {
    echo "## [Developed the app](https://github.com/$githubRepo/graphs/contributors)"
    echo
    github_contributors
    echo
    sed -n '/## Localized the app/,$p' "$file"
  } > "$file.tmp" && mv "$file.tmp" "$file"
}

update_developer_contributors
