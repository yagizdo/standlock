#!/bin/bash
set -euo pipefail

SPARKLE_VERSION=$(jq -r '.pins[] | select(.identity == "sparkle") | .state.version' \
  StandLock.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved)
curl -sL -o "$RUNNER_TEMP/Sparkle.tar.xz" \
  "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
mkdir -p "$RUNNER_TEMP/sparkle"
tar xf "$RUNNER_TEMP/Sparkle.tar.xz" -C "$RUNNER_TEMP/sparkle"

SIGN_UPDATE="$RUNNER_TEMP/sparkle/bin/sign_update"
chmod +x "$SIGN_UPDATE"

KEY_FILE="$RUNNER_TEMP/sparkle-key"
echo "$SPARKLE_PRIVATE_KEY" > "$KEY_FILE"

SIGN_OUTPUT=$("$SIGN_UPDATE" "StandLock-${VERSION}.zip" --ed-key-file "$KEY_FILE")
ED_SIGNATURE=$(echo "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
if [ -z "$ED_SIGNATURE" ]; then
  echo "::error::sign_update did not produce an edSignature. Raw output:"
  echo "$SIGN_OUTPUT"
  exit 1
fi
FILE_LENGTH=$(stat -f%z "StandLock-${VERSION}.zip")
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
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <pubDate>${PUB_DATE}</pubDate>
      <enclosure url="https://github.com/yagizdo/StandLock/releases/download/v${VERSION}/StandLock-${VERSION}.zip"
                 sparkle:edSignature="${ED_SIGNATURE}"
                 length="${FILE_LENGTH}"
                 type="application/octet-stream" />
    </item>
  </channel>
</rss>
APPCAST
