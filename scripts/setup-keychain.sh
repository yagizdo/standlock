#!/bin/bash
set -euo pipefail

CERT_PATH="$RUNNER_TEMP/certificate.p12"
KEYCHAIN_PATH="$RUNNER_TEMP/build.keychain-db"
KEYCHAIN_PASS=$(openssl rand -base64 24)

echo "$P12_BASE64" | base64 --decode > "$CERT_PATH"

security create-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN_PATH"
security import "$CERT_PATH" -k "$KEYCHAIN_PATH" -P "$P12_PASSWORD" \
  -T /usr/bin/codesign -T /usr/bin/security
security list-keychains -d user -s "$KEYCHAIN_PATH" login.keychain-db
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASS" "$KEYCHAIN_PATH"

IDENTITY=$(security find-identity -v "$KEYCHAIN_PATH" \
  | grep "Developer ID Application" | head -1 \
  | sed 's/.*"\(.*\)"/\1/')
if [ -z "$IDENTITY" ]; then
  echo "::error::No 'Developer ID Application' identity found in keychain."
  security find-identity -v "$KEYCHAIN_PATH"
  exit 1
fi
echo "SIGNING_IDENTITY=$IDENTITY" >> "$GITHUB_ENV"
