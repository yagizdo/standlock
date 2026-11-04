#!/bin/bash
set -euo pipefail

SIGN_UPDATE=$(find "${RUNNER_TEMP:?}/DerivedData/SourcePackages/artifacts" \
  -path '*/Sparkle/bin/sign_update' -type f 2>/dev/null | head -1 || true)
if [ -z "$SIGN_UPDATE" ]; then
  echo "::error::sign_update not found in the SwiftPM artifacts. Did the Resolve SPM dependencies step run with -derivedDataPath \$RUNNER_TEMP/DerivedData?"
  exit 1
fi

# The key goes in on stdin, so it never lands in a file on the runner.
SIGN_OUTPUT=$(echo "$SPARKLE_PRIVATE_KEY" | "$SIGN_UPDATE" "StandLock-${VERSION}.dmg" --ed-key-file -)
ED_SIGNATURE=$(echo "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
if [ -z "$ED_SIGNATURE" ]; then
  echo "::error::sign_update did not produce an edSignature. Raw output:"
  echo "$SIGN_OUTPUT"
  exit 1
fi
FILE_LENGTH=$(stat -f%z "StandLock-${VERSION}.dmg")
PUB_DATE=$(date "+%a, %d %b %Y %H:%M:%S %z")

cat > appcast.xml <<APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>StandLock</title>
    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <pubDate>${PUB_DATE}</pubDate>
      <enclosure url="https://github.com/yagizdo/StandLock/releases/download/v${VERSION}/StandLock-${VERSION}.dmg"
                 sparkle:edSignature="${ED_SIGNATURE}"
                 length="${FILE_LENGTH}"
                 type="application/octet-stream" />
    </item>
  </channel>
</rss>
APPCAST

xmllint --noout appcast.xml
echo "appcast.xml: version ${BUILD_NUMBER}, minimum macOS 13.0"
