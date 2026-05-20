#!/bin/bash
set -euo pipefail

APP="$RUNNER_TEMP/export/StandLock.app"
FW="$APP/Contents/Frameworks/Sparkle.framework"

codesign --force --timestamp --options runtime \
  --sign "$SIGNING_IDENTITY" "$FW/Versions/B/XPCServices/Downloader.xpc"
codesign --force --timestamp --options runtime \
  --sign "$SIGNING_IDENTITY" "$FW/Versions/B/XPCServices/Installer.xpc"
codesign --force --timestamp --options runtime \
  --sign "$SIGNING_IDENTITY" "$FW/Versions/B/Updater.app"
codesign --force --timestamp --options runtime \
  --sign "$SIGNING_IDENTITY" "$FW/Versions/B/Autoupdate"
codesign --force --timestamp --options runtime \
  --sign "$SIGNING_IDENTITY" "$FW"
codesign --force --timestamp --options runtime \
  --sign "$SIGNING_IDENTITY" "$APP"
