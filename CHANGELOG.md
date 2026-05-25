# Changelog

## StandLock v0.2.2

**Bug Fixes**
- Fix Sparkle delegate methods hidden from Obj-C runtime by MainActor isolation (59b9f94)
- Fix overlay not appearing over full-screen apps (4f8fda8)

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.2.1...v0.2.2

## StandLock v0.2.1

**Features**
- Per-schedule progressive enforcement replaces global escalation level (c03e86d)
- Playful escalation mechanics on break screen for persistent skippers (f3dafd3)
- Permission-gated toggles for Calendar, Idle Detection, and Strict settings (404169a)

**Bug Fixes**
- Make enforcement migration idempotent and scope skip limit to Firm level only (bfdf736)
- Improve Input Monitoring detection with event tap probe fallback for stale TCC cache (d0e2620)

**Improvements**
- Consolidate PermissionChecker to a single shared instance (3db84a4)
- Add gated toggle binding tests and fix PermissionsView indentation (71873ea)

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.2.0...v0.2.1

## StandLock v0.2.0

**Features**
- Detect active screen sharing sessions and defer breaks automatically (befaf41)
- Add post-deferral behavior option with 10-second polling for deferred breaks (adcdcac)
- Progressive friction escalation: skipping breaks gets harder the more you skip (04a8308)
- Redesigned menu bar dropdown with rounded-row buttons and update banner (619eef9)
- Refreshed settings UI with improved layout and escalation path controls (189dd93)
- Replaced ZIP distribution with DMG for drag-to-Applications install experience (395a747)

**Bug Fixes**
- Staple notarization ticket to app bundle before DMG packaging (4d11993)
- Allow app termination during relaunch even when break overlay is active (183c24b)
- Enforce overlay focus on all screens and block quit during breaks (9c70503)
- Eliminate dual-timer race condition and pre-fetch detection context (cc78ee2)
- Decode raw Int for EscalationLevel to survive unrecognized stored values (26d8c7c)
- Reset escalation tier on idle-counted breaks, fix skip button deduplication (2dd9d39)
- Add #available guards for macOS 14+ APIs (07f9237)

**Improvements**
- Lower deployment target from macOS 15 to macOS 13 (Ventura) (336dd03)
- Replace @Observable with ObservableObject for macOS 13 compatibility (5cf1ff7)
- Migrate SwiftUI property wrappers and onChange closures for macOS 13 (2b0d5e6, 763a449)
- Replace boolean escalation flags with EscalationLevel enum (0116278)
- Add polling loop and screen sharing detector tests (48595e3)

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.1.4...v0.2.0

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
