#!/bin/bash
set -euo pipefail

STAGE=$(mktemp -d)
# mktemp's 0700 would otherwise become the mode of the volume root.
chmod 755 "$STAGE"

ditto "$RUNNER_TEMP/export/StandLock.app" "$STAGE/StandLock.app"
ln -s /Applications "$STAGE/Applications"
# hdiutil can fail with "Resource busy" on CI; -ov lets a retry overwrite.
for attempt in 1 2 3; do
  hdiutil create -volname StandLock -srcfolder "$STAGE" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "StandLock-${VERSION}.dmg" && exit 0
  sleep $((attempt * 10))
done
exit 1
