#!/usr/bin/env bash

set -exu

token="${TAP_TOKEN:-${HOMEBREW_TAP_TOKEN:-${WEBSITE_DISPATCH_TOKEN:-}}}"

if [ -z "$token" ]; then
  echo "TAP_TOKEN is not set; skipping Homebrew tap update."
  exit 0
fi

version="$(cat "$VERSION_FILE")"
zipName="$APP_NAME-$version.zip"
zipPath="$XCODE_BUILD_PATH/$zipName"

if [ ! -f "$zipPath" ]; then
  echo "Release archive $zipPath not found!"
  exit 1
fi

sha256="$(shasum -a 256 "$zipPath" | awk '{print $1}')"

tapRepo="${HOMEBREW_TAP_REPO:-mgabs/homebrew-tap}"
caskPath="Casks/tab-flow.rb"

# Fetch current cask file metadata from GitHub API
fileJson=$(GH_TOKEN="$token" gh api "repos/$tapRepo/contents/$caskPath")
fileSha=$(echo "$fileJson" | jq -r '.sha')
currentContent=$(echo "$fileJson" | jq -r '.content' | base64 --decode)

# Update version, sha256, and livecheck appcast url if needed
updatedContent=$(echo "$currentContent" | \
  sed -E "s/version \"[^\"]+\"/version \"$version\"/" | \
  sed -E "s/sha256 \"[^\"]+\"/sha256 \"$sha256\"/" | \
  sed "s|master/build/appcast.xml|master/appcast.xml|")

encodedContent=$(echo "$updatedContent" | base64 | tr -d '\n')

# Commit update to the tap repo via GitHub Contents API
GH_TOKEN="$token" gh api \
  --method PUT \
  "repos/$tapRepo/contents/$caskPath" \
  -f message="chore(cask): bump tab-flow to $version" \
  -f content="$encodedContent" \
  -f sha="$fileSha" \
  -f branch="main"

echo "Successfully updated $tapRepo $caskPath to version $version ($sha256)"
