#!/bin/bash
set -euo pipefail

FW="${RUNNER_TEMP:?}/export/StandLock.app/Contents/Frameworks/Sparkle.framework"
for item in Sparkle Autoupdate Resources XPCServices Updater.app; do
  if [ -e "$FW/$item" ] && [ ! -L "$FW/$item" ]; then
    rm -rf "${FW:?}/$item"
    ln -s "Versions/Current/$item" "$FW/$item"
  fi
done
