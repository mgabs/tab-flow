#!/usr/bin/env bash

set -exu

if [ -z "${APPLE_P12_CERTIFICATE:-}" ]; then
  echo "APPLE_P12_CERTIFICATE is not set. Skipping certificate setup."
  exit 0
fi

certificateFile="codesign"

# Recreate the certificate from the secure environment variable
echo "$APPLE_P12_CERTIFICATE" | base64 --decode > $certificateFile.p12

scripts/codesign/import_certificate_into_new_keychain.sh "$certificateFile" ""
