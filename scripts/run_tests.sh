#!/usr/bin/env bash

set -ex

xcodebuild -version
xcodebuild -project alt-tab-macos.xcodeproj -scheme Release -showBuildSettings | grep SWIFT_VERSION

SIGNING_FLAGS=""
if [ -z "${APPLE_P12_CERTIFICATE:-}" ]; then
  SIGNING_FLAGS="CODE_SIGN_IDENTITY= CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO"
fi

set -o pipefail && xcodebuild test -project alt-tab-macos.xcodeproj -scheme Test -configuration Release $SIGNING_FLAGS | scripts/xcbeautify
