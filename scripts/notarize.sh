#!/bin/bash
set -euo pipefail

APP="$RUNNER_TEMP/export/StandLock.app"

ditto -c -k --keepParent --rsrc --sequesterRsrc \
  "$APP" "$RUNNER_TEMP/StandLock-notarize.zip"
xcrun notarytool submit "$RUNNER_TEMP/StandLock-notarize.zip" \
  --keychain-profile "ci-notary" --wait

xcrun stapler staple "$APP"
xattr -cr "$APP"
