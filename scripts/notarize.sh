#!/bin/bash
set -euo pipefail

xcrun notarytool submit "StandLock-${VERSION}.dmg" \
  --keychain-profile "ci-notary" --wait

xcrun stapler staple "StandLock-${VERSION}.dmg"
