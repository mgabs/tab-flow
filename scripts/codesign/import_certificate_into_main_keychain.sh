#!/usr/bin/env bash

set -exu

certificateFile="$1"
certificatePassword="$2"

# import p12 into Keychain. Must run as the current user (not root) so it lands in
# ~/Library/Keychains/login.keychain-db, not root's.
security import $certificateFile.p12 -P $certificatePassword -T /usr/bin/codesign
# in Keychain, set Trust > Code Signing > "Always Trust". Omitting `-d` targets the per-user trust
# domain instead of the admin domain — the admin domain always requires an interactive SecurityAgent
# authorization dialog (sudo does not bypass it), which fails non-interactively. The user domain only
# needs write access to the current user's own trust settings, which this account already has.
security add-trusted-cert -r trustRoot -p codeSign $certificateFile.crt
