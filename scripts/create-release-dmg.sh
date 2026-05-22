#!/bin/bash
set -euo pipefail

create-dmg \
  --volname "StandLock" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 80 \
  --icon "StandLock.app" 180 170 \
  --app-drop-link 480 170 \
  --no-internet-enable \
  --skip-jenkins \
  --hdiutil-quiet \
  "StandLock-${VERSION}.dmg" \
  "$RUNNER_TEMP/export/StandLock.app"
