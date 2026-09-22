#!/usr/bin/env bash

set -exu

# Inject CI values via the same xcconfig override mechanism used locally.
# Xcode substitutes $(VAR) refs into Info.plist at build time.
version=$(cat "$VERSION_FILE" 2>/dev/null || true)
cat > config/local.xcconfig <<EOF
CURRENT_PROJECT_VERSION = ${version:-1.0.0}
APPCENTER_SECRET = ${APPCENTER_SECRET:-}
EOF

if [ -z "${APPLE_P12_CERTIFICATE:-}" ]; then
  cat >> config/local.xcconfig <<EOF
CODE_SIGN_IDENTITY = -
CODE_SIGNING_REQUIRED = NO
EOF
fi
