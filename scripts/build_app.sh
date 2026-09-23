#!/usr/bin/env bash

set -ex

SIGNING_FLAGS=""
if [ -z "${APPLE_P12_CERTIFICATE:-}" ] && ! grep -q "CODE_SIGN_IDENTITY" config/local.xcconfig 2>/dev/null; then
  SIGNING_FLAGS="CODE_SIGN_IDENTITY= CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO"
fi

set -o pipefail && xcodebuild -project alt-tab-macos.xcodeproj -scheme Release -derivedDataPath DerivedData $SIGNING_FLAGS | scripts/xcbeautify
file "$BUILD_DIR/$XCODE_BUILD_PATH/$APP_NAME.app/Contents/MacOS/$APP_NAME"
