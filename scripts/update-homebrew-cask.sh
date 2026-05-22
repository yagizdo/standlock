#!/bin/bash
set -euo pipefail

if [ -z "$TAP_TOKEN" ]; then
  echo "TAP_GITHUB_TOKEN not set, skipping Homebrew cask update"
  exit 0
fi

git clone "https://github.com/yagizdo/homebrew-tap.git" "$RUNNER_TEMP/homebrew-tap"
cd "$RUNNER_TEMP/homebrew-tap"
git remote set-url origin "https://x-access-token:${TAP_TOKEN}@github.com/yagizdo/homebrew-tap.git"
mkdir -p Casks

cat > Casks/standlock.rb <<RUBY
cask "standlock" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "https://github.com/yagizdo/StandLock/releases/download/v#{version}/StandLock-#{version}.dmg",
      verified: "github.com/yagizdo/StandLock/"
  name "StandLock"
  desc "Stand reminder and break screen for macOS"
  homepage "https://github.com/yagizdo/StandLock"

  depends_on macos: ">= :sequoia"

  app "StandLock.app"

  zap trash: [
    "~/Library/Application Support/StandLock",
    "~/Library/Preferences/com.yagizdokumaci.standlock.plist",
    "~/Library/Caches/com.yagizdokumaci.standlock",
  ]
end
RUBY

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git add Casks/standlock.rb
if ! git diff --cached --quiet; then
  git commit -m "chore: update standlock to ${VERSION}"
  git pull --rebase
  git push
fi
