#!/bin/bash
set -euo pipefail

ditto -c -k --keepParent --rsrc --sequesterRsrc \
  "$RUNNER_TEMP/export/StandLock.app" "StandLock-${VERSION}.zip"
shasum -a 256 "StandLock-${VERSION}.zip" > "StandLock-${VERSION}.zip.sha256"
SHA256_VALUE=$(awk '{print $1}' "StandLock-${VERSION}.zip.sha256")
echo "SHA256=${SHA256_VALUE}" >> "$GITHUB_ENV"
