# Changelog

## Unreleased

**New**
- A schedule can now cycle through multiple work intervals instead of one, e.g. 58 min sitting > 2 min break > 28 min standing > 2 min break > repeat. Each interval can carry an optional label, and the break screen shows what comes next ("NEXT: STANDING"). The cycle stays on plan regardless of how a break ends, and each day starts from the first interval. Existing single-interval schedules are unchanged (fixes #30, #35)

## StandLock v0.2.8

**Bug Fixes**
- Daily counters now reset at the calendar day boundary. An app left running across midnight kept reporting yesterday's "breaks skipped today", permanently tripped the daily skip limit, blocked schedules that had hit their daily break cap, carried escalation tiers into the next day, and wrote multi-day totals into a single day's history record (fixes #32, ecbd6e5)
- Week and Month totals in Statistics are now calendar aligned. They previously summed the trailing 7 and 30 days while the grids below them drew a Monday-to-Sunday week and a calendar month, so the numbers disagreed with the cells right under them. Year stays a rolling 365 days to match its heatmap (2281239)
- Statistics no longer goes stale. Switching periods rebuilt the totals but not the heatmap, and a panel left open across midnight kept drawing yesterday (ace5307)
- Year heatmap columns now start on Monday instead of slicing the window into raw 7-day blocks, today's cell is outlined, and the month grid's leading blanks no longer collide with real day cells (6ce2ff6)
- Removing a time window from a schedule no longer misbinds the remaining rows (6c6912c)
- The slot machine challenge now stops accepting spins once attempts run out. A losing spin on the last attempt left the button live and the next tap crashed (23a07ad)
- Break history is saved after startup pruning, so records older than 400 days are removed once instead of being reloaded and re-pruned on every launch (3d253eb)

**Notes**
- The daily counter fix applies from this version onward. Days already stored in Settings → Statistics keep their old numbers, since those records hold carried-over multi-day totals that cannot be split back into per-day values.
- Week and Month figures will read differently than in earlier versions. The stored break records are unchanged; only the counting window moved.

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.2.7...v0.2.8

## StandLock v0.2.7

**Bug Fixes**
- Countdown timer is preserved when screen configuration changes; connecting or disconnecting a monitor no longer resets the timer to the full duration (4a3c721)
- Emergency escape (⌃⌥⌘ hold) is now available when the daily skip limit is reached, so users are never permanently locked out (883b72b)
- Emergency escape key combo is now detected globally, so it works even when the overlay briefly loses keyboard focus (3eca987)
- Autocorrect is disabled on challenge text fields so macOS does not alter phrases while you type (f0ade57)

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.2.6...v0.2.7

## StandLock v0.2.6

**Features**
- Break statistics dashboard in Settings: 6 metric cards (completions, skips, completion rate, streak, best streak, break time) with week, month, and year history views (2a30763)
- Slot machine challenge as Gentle tier 4 escalation: spin reels to earn a skip (174d7cc)
- Social links and copyright in About view (32bc0d3)

**Bug Fixes**
- Resume schedule correctly after sleep/wake during active pause (958c6a8)
- Emit break event on screen lock and sleep, and restart countdown timer (d9ac47b)
- Handle midnight-crossing time windows in schedule evaluation (0040e97)
- Pause break timer during screen lock (7238981)
- Handle system sleep/wake; replace TabView with custom tab bar to fix navigation issues (579ae35)
- Extend crate spin strip for infinite scroll feel (e5751d3)
- Cancel slot machine auto-stop tasks on re-spin to prevent spin conflicts (79a5f7a)
- Expand tab bar hit area to reduce missed taps (cdd9e34)
- Reduce timer numeral tracking to prevent glyph clipping (2d3dd5a)

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.2.5...v0.2.6

## StandLock v0.2.5

**Features**
- Menu bar countdown timer with two display modes: always-on full timer or last-minutes-only countdown (e041bdb)
- Roast challenge as Firm tier 5 dismiss mechanic: type embarrassing sentences to earn a skip (74e7a00)

**Bug Fixes**
- Active progress dot in roast challenge now renders at 50% opacity to distinguish from completed dots (187b538)

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.2.4...v0.2.5

## StandLock v0.2.4

**Features**
- Find-the-button game as Gentle tier 2 dismiss mechanic (5b85060)
- CS:GO-style crate opening as Gentle tier 3 dismiss mechanic (b1eebb9)
- Improved crate animation with 7-second spin and escalating teasing messages (ba543c0)
- Daily skip limit for Gentle discipline level, 5 skips per day (6332df4)
- Type-a-funny-phrase dismiss as Gentle tier 4 escalation (6bf5851)
- New developer-themed splash texts on break screen (31f49b4)

**Bug Fixes**
- Fix strict mode escape combo never triggering; add visible hold countdown (4ea3348)
- Fix update window appearing behind other windows when launched from menu bar (7beb399)
- Block paste in Firm mode's type-phrase field to prevent cheating (6a88893)
- Remove unreliable auto-resume media playback after breaks (84a6b87)
- Prevent double coordinator start on launch (93807da)
- Auto-disable idle detection, calendar integration, and strict mode when required permissions are revoked (7babc3f)

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.2.3...v0.2.4

## StandLock v0.2.3

**Improvements**
- Check for updates every 4 hours instead of daily (fc1a2ef)

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.2.2...v0.2.3

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
