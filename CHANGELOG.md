# Changelog

## StandLock v0.1.4

**Features**
- Pause and resume system media during breaks (4d6d938)

**Bug Fixes**
- Show deferral reason in menu bar instead of stale countdown (ccb84ba)
- Propagate preference changes to a running break coordinator (6f5cec8)
- Prevent Dock icon from appearing when opening settings (72c21a1)
- Resume media on timer auto-complete and add backward-compatible preference decoding (b2889e4)

**Improvements**
- Switch Gentle and Firm break palettes to London Sands tones (94446c4)
- Add tests for preference propagation through the coordinator (b423ecd)

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.1.3...v0.1.4

## StandLock v0.1.3

**Features**
- Custom delete confirmation dialog for schedules (8090abf)

**Improvements**
- Replace SwiftUI Window scene with programmatic NSWindow for onboarding (8213e6d)
- Update app icon (f5cd559)
- Extract inline CI workflow scripts into standalone files (28cc859)

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.1.2...v0.1.3

## StandLock v0.1.2

**Bug Fixes**
- Use Info.plist build number for release versioning instead of CI run number (acabeb3)

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.1.1...v0.1.2

## StandLock v0.1.1

**Bug Fixes**
- Add CFBundleDisplayName so Spotlight and system UI show the correct app name (ba0eb7e)
- Fix version string in Info.plist that was out of sync with the release tag (0d16665)

**Improvements**
- Rewrite README with install steps, permissions table, and feature overview (6908813)

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.1.0...v0.1.1

## StandLock v0.1.0

Initial release.

- Menu bar app for macOS 15.0+
- Stand reminders with customizable intervals
- Accessibility and Screen Recording permission management
- Sparkle auto-update support
- Homebrew cask installation
