#!/bin/bash
set -euo pipefail

APP="$RUNNER_TEMP/export/StandLock.app"
FW="$APP/Contents/Frameworks/Sparkle.framework"

codesign --force --timestamp --options runtime \
  --sign "$SIGNING_IDENTITY" "$FW/Versions/Current/XPCServices/Downloader.xpc"
codesign --force --timestamp --options runtime \
  --sign "$SIGNING_IDENTITY" "$FW/Versions/Current/XPCServices/Installer.xpc"
codesign --force --timestamp --options runtime \
  --sign "$SIGNING_IDENTITY" "$FW/Versions/Current/Updater.app"
codesign --force --timestamp --options runtime \
  --sign "$SIGNING_IDENTITY" "$FW/Versions/Current/Autoupdate"
codesign --force --timestamp --options runtime \
  --sign "$SIGNING_IDENTITY" "$FW"
codesign --force --timestamp --options runtime \
  --sign "$SIGNING_IDENTITY" "$APP"
