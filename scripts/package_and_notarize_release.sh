#!/usr/bin/env bash

set -exu

version="$(cat "$VERSION_FILE")"
appFile="$APP_NAME.app"
zipName="$APP_NAME-$version.zip"
oldPwd="$PWD"

cd "$XCODE_BUILD_PATH"
ditto -c -k --keepParent "$appFile" "$zipName"

# request notarization if credentials are provided
if [ -z "${APPLE_ID:-}" ] || [ -z "${APPLE_PASSWORD:-}" ] || [ -z "${APPLE_TEAM_ID:-}" ]; then
  echo "Apple notarization credentials not provided; skipping notarization."
  exit 0
fi

requestStatus=$("$oldPwd"/scripts/notarytool submit \
  --apple-id "$APPLE_ID" \
  --password "$APPLE_PASSWORD" \
  --team-id "$APPLE_TEAM_ID" \
  "$zipName" \
  --wait --timeout 15m 2>&1 |
  tee /dev/tty |
  awk -F ': ' '/  status:/ { print $2; }')
if [[ $requestStatus != "Accepted" ]]; then exit 1; fi

# staple build
xcrun stapler staple "$appFile"
ditto -c -k --keepParent "$appFile" "$zipName"
