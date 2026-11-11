# Changelog

## StandLock v0.15.0

**Features**
- Reset StandLock, at the bottom of Settings › General, deletes your settings, schedules and statistics and reopens the app as if newly installed. Permissions you granted in System Settings stay (9bc88cb)

**Improvements**
- The menu bar countdown shows hours for long waits: 16h58m instead of 1018m (a41b883)
- Settings descriptions now say in plain words what each option does, with examples. In Turkish, the levels are now called Esinti, Rüzgâr and Fırtına (a41b883)
- Importing a settings file no longer stalls the Settings window, and a file over 1 MiB is refused (cd3eabd). Thanks @kanihal!

**Bug Fixes**
- With two schedules on whose days and hours overlap, the one with the longer interval never gave a break. Now only one of them can be on: turning one on turns the other off, and the schedule page tells you first. If you already have such a pair, the later one in the list is turned off after the update (a41b883)

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.14.0...v0.15.0

## StandLock v0.14.0

**Features**
- Pomodoro can now cover the screen during focus instead of during breaks, for work away from the Mac. Choose it in Settings › Pomodoro under Cover the screen; a covered focus lasts up to 60 minutes (c4cbe69)

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.13.0...v0.14.0

## StandLock v0.13.0

**Features**
- Pomodoro sessions. Start one from the menu bar panel and stop it or skip its phase from the same row; the status row shows the phase, the round and the time left. A session runs with or without a schedule, and your schedules wait until it ends. Its breaks use the strictest level among your enabled schedules, Gentle if none is enabled. Skip and Pause in the panel are off during a session. The session keeps running through sleep, screen lock and a relaunch on the same day, and time you were away counts as rest (202b1c5, 2d77a46)
- Settings › Pomodoro sets the focus length, the short and long breaks and the number of rounds, 25/5/15 minutes with four rounds by default. Export and import carry these settings (1fce972)
- The break screen shows a Pomodoro chip during a session break, with the round (POMODORO · 2/4) or LONG BREAK (f0e34bc)
- Statistics has a Pomodoro card with focus time, rounds, and finished and abandoned sessions. A day with no schedule where you finish at least one break now extends your streak; a day like that with no finished break still does not end it (58514a4)

**Improvements**
- The Pomodoro schedule template now has a long break: three 5 minute breaks, then one of 15 minutes (1fce972)

**Bug Fixes**
- An imported settings file can no longer set a break longer than 60 minutes, a Strict emergency hold longer than 30 seconds or a Firm skip delay longer than 60 seconds. Import refuses such a file, and values already saved are capped when a break uses them (5b13ddf). Thanks @kanihal!
- An interval under one minute, from an imported file or a hand-edited preference, no longer opens the next break right after a skip or a finished break. A Firm escape phrase that cannot be typed (empty, multi-line, very long or with control characters) falls back to the default, and import refuses both (7c94424)

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.12.0...v0.13.0

## StandLock v0.12.0

**Features**
- Fifteen new menu bar scenes: a frog, a fox, a capybara, a robot, a campfire, a hamster, a sprout, a coffee mug, a bread loaf, reading, fishing, painting, cooking, a rainy day and a hammock. Each one follows your break like the first four, and the desk worker and the penguin now get up and hop when it is time to stand. Settings › Menu Bar shows two rows of scenes, and "More scenes" opens the rest (48f0ce8)
- Export and import your settings in Settings › General. The file holds preferences, schedules, theme, language and Show help. Import lists what will change and applies nothing until you confirm, and a file StandLock cannot use shows why and changes nothing. Calendar choices are not carried over, because calendars have different identifiers on each Mac (3d12c9e)
- A copy installed with Homebrew now updates from inside the app. StandLock checks the tap once a day and installs through `brew` from the menu bar banner or Settings › About (3f21dfa)
- The first-launch setup is rebuilt in four steps: welcome, your first schedule, a menu bar scene, and where the app lives. Permissions are asked only if you pick Strict, and launch at login starts off and is offered on the last step. Closing the window finishes setup instead of bringing it back on every launch (5a46c6c)
- Opening StandLock again from Finder, Spotlight or Launchpad while it runs opens Settings. On macOS 26 and later the menu bar icon can be hidden, which left no way into the app (5a46c6c)

**Improvements**
- About, Settings and Quit are now buttons in the menu bar panel's bottom row, so each takes one click. Quit asks first (9ba7423)
- The open menu bar panel uses less CPU with a moving scene: 2-5%, down from 8-13% (661ebde)

**Bug Fixes**
- The Update button in the menu bar update banner now opens the update window. It did nothing beyond bringing the app forward (7b45164)
- The Dock icon goes away again after first-launch setup. It used to stay until you quit (5a46c6c)
- The schedule made during first-launch setup is named in your language. It was always saved as "Work Hours" (5a46c6c)

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.11.0...v0.12.0

## StandLock v0.11.0

**Features**
- Settings is now one window with a sidebar instead of tabs. General, Menu Bar, Break Screen, Discipline, Detection, Permissions, Statistics and About each have a page, and every schedule has its own row. The sidebar adds search, a countdown to the next break, a badge when a permission needs attention, and a Show help switch for the description text. Command F focuses search. About shows the update status (f493cc8)
- Schedules are edited on their own page. Leaving the page, closing the window or quitting with unsaved edits asks you to save, discard or cancel. A schedule can start from a 20-20-20, Pomodoro or 52/17 template, and the form lists every break of the day before you save (f493cc8)
- Two optional sounds in Settings › Break Screen, both off by default: one a minute before a break, one when you finish a break. The first stays quiet when the break is going to wait or you are away (f493cc8)
- The menu bar panel opens on a drawn scene that follows your break: alert in the last minute, resting when you pause. Pick an hourglass, a desk, a calico cat, a penguin or Off in Settings › Menu Bar (bdd1f59)

**Improvements**
- The menu bar panel now has compact Skip, Pause and gear controls. Settings, About and Quit moved into the gear's menu (bdd1f59)
- Daily skip limits moved to Settings › Discipline and Pause Media to Settings › Break Screen (f493cc8)

**Bug Fixes**
- Skip in the menu bar now skips the break when you are outside the schedule's hours or near their end. It used to count a skip and reset your streak while the break stayed in place (922a173)
- Skip in the menu bar is disabled when no schedule is enabled. It used to count a skip with nothing to skip (922a173)

**Notes**
- If you go back to an older version and change any setting there, your scene and sound choices are lost.

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.10.1...v0.11.0

## StandLock v0.10.1

**Improvements**
- Updated Sparkle, the framework behind in-app updates, to 2.10.1 (bd63c06)

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.10.0...v0.10.1

## StandLock v0.10.0

**Features**
- The break screen can be customized in a new Break Screen section in Settings › General. Pick your own background and text colours, by colour picker or hex code, and a live preview shows the result. One colour pair applies to Gentle, Firm and Strict, and each level keeps its own accent colour. A warning appears when the text may be hard to read on the background. You can also hide today's statistics at the bottom of the break screen and add a message that shows under the timer during every break (6522ac1)

**Notes**
- With custom colours on, the break screen uses them instead of following the Appearance setting.
- If you go back to an older version and change any setting there, your Break Screen settings are lost.

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.9.0...v0.10.0

## StandLock v0.9.0

**Features**
- A break that lands during a call can be postponed instead of skipped. Click Postpone on the break screen and the break comes back at full length once your microphone and camera have been free for 2 minutes. Postponing counts as a deferral, so it does not use up a skip, raise the Progressive Enforcement tier or break your streak. The wait is set in Settings › Detection (1 to 10 minutes), and the menu bar counts down to the break's return (closes #72, aa28f2e)

**Notes**
- Each break can be postponed once. A postponed break still comes back after a screen lock, sleep, a pause or a schedule edit, but not after you quit StandLock.

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.8.1...v0.9.0

## StandLock v0.8.1

**Bug Fixes**
- Days when none of your schedules run no longer break your day streak. A weekday-only schedule used to lose the streak every Monday; now only a scheduled day without a completed break ends it (8ab123d)

**Notes**
- After updating, your current streak can grow longer, because past days without a schedule stop counting against it. Past days are judged by the schedules you have today. Best streak is not recalculated.

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.8.0...v0.8.1

## StandLock v0.8.0

**Features**
- StandLock speaks Simplified Chinese. The interface, the break screens, the exercise suggestions and every escalation challenge are translated, and the Language picker in Settings › General lists it (closes #47, c147bfb)

**Bug Fixes**
- Turning a schedule off and on again no longer restarts its countdown when you have more than one schedule. The break stays due at the time it was set for (5aec21d)
- Quitting and reopening StandLock no longer restarts the countdown, and it no longer clears today's skip count or the Progressive Enforcement tier. They carry over within the same day (5aec21d)

**Improvements**
- `brew install` and `brew upgrade` no longer print deprecation warnings for the StandLock cask (94609b3, 6075cde). Thanks @dobladov and @tim-hilde!

**Notes**
- If a break came due while a schedule was off or StandLock was closed, that break is dropped and a fresh interval starts, as before. Quitting during a break still ends the break.

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.7.1...v0.8.0

## StandLock v0.7.1

**Bug Fixes**
- A break no longer runs past its length when your Mac is busy. The countdown took a second off each time it woke up, so every late wake-up made the lock longer; it now counts down to a fixed end time (#63, 8aa4229)
- The escape phrase field gets your typing without a click first. Keys typed during a break used to go to the app behind the break screen; StandLock now comes to the front when a break starts (#63, 8aa4229)

**Notes**
- StandLock shows up in the app switcher (Cmd-Tab) while a break is on screen and leaves it when the break ends.

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.7.0...v0.7.1

## StandLock v0.7.0

**Features**
- Break duration and the Repetition Cycle short break now accept decimal minutes, down to 0.1 (six seconds). Idle detection only counts a break as taken once you've been away for at least a minute, or the full break length if longer, so a quick glance away no longer swallows a break under a minute (fixes #59, 593a385)

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.6.0...v0.7.0

## StandLock v0.6.0

**Features**
- Calendar integration can now be narrowed to the calendars you choose. Settings › Detection gains an All calendars / Specific calendars switch; every calendar starts ticked, so nothing changes until you untick one (closes #48, a5bec45). Thanks @tim-hilde!
- An Appearance setting in Settings › General: System, Light or Dark. System is the default and follows your Mac, and each discipline level gets its own dark break palette (closes #55, e77aee1).

**Notes**
- The break overlay used to render light whatever your Mac was set to. It now follows the Appearance setting, so a Mac in dark appearance gets dark break screens from this version on. Choose Light in Settings › General to keep the old look.

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.5.0...v0.6.0

## StandLock v0.5.0

**Features**
- StandLock speaks Turkish. The interface, the break screens, the exercise suggestions and every escalation challenge are translated (ffc3d27, 6b7a022, 595e3e1, 33171ed, 6656b64)
- A Language picker in Settings › General switches the interface in place, with no restart. System follows your Mac's language (5e1f868, 89e271b)

**Bug Fixes**
- Statistics no longer crashes on a non-Gregorian calendar. The year heatmap numbered the months with your calendar but labelled them from a twelve-month Gregorian list, so the thirteenth month of a Coptic, Ethiopic or Hebrew leap year ran off the end of the list (47c9024)
- Editing a schedule no longer empties the menu bar progress ring. The break itself stayed put, but the ring re-measured its interval from the moment of the edit, so changing a discipline level twenty seconds before a break drained the icon and refilled it over those twenty seconds. The same reset hit a break re-armed after wake or unlock (002026e)

**Improvements**
- Opening a Settings window from the menu bar popover now dismisses the popover instead of leaving it up behind the window (89e271b, e1d8aff)
- Weekday abbreviations and month names in Settings and Statistics follow your locale instead of being fixed to English (6b7a022)

**Notes**
- Choosing a language also writes it into StandLock's own preferences, so the app menu and the updater follow it from the next launch. Switching back to System removes it again.

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.4.0...v0.5.0

## StandLock v0.4.0

**Features**
- The menu bar now flags a Strict schedule that is running as Firm. Without Accessibility or Input Monitoring, Strict cannot enforce a break, and the menu bar used to print an unqualified "Strict" that read like the real thing (459eda4)
- Daily skip limits for Gentle and Firm are editable in Settings › General. Strict still has no limit (9c86f86)

**Bug Fixes**
- The calendar look-ahead setting works now. It filtered out every event that had not started yet, so the window could never change the outcome, and the stepper's value only reached the detector after a restart (3d09b8c)
- Editing a schedule no longer pushes the next break away. Every rebuild re-measured the interval from that moment, so repeated edits, or a Strict permission reading that flapped, could postpone a break indefinitely (2c40135, 3d09b8c)
- Editing a schedule no longer leaves the app believing a break is on screen when none is, and no longer re-arms the daily cap from zero, restarts the interval cycle or cancels a pause (3d09b8c)
- Turning your only enabled schedule off and back on no longer clears today's counters and re-arms the daily skip cap from zero (a606759)
- Idle detection no longer asks for Input Monitoring. Its toggle sat behind a permission the feature never uses, and the preference was switched off whenever that permission was missing (c7db216)
- A Strict schedule keeps its level while Accessibility or Input Monitoring is missing. It runs as Firm and says so in the schedule list, instead of being silently rewritten to Gentle (b1a6dd9, 3d09b8c)
- Removed the Focus mode setting. It read a macOS key that has not been written since macOS 11, so on macOS 13 and later it never deferred a break or reduced one to Gentle (3392f3f)

**Notes**
- The calendar look-ahead now also defers a break that would fire shortly before a meeting starts, not only one during a meeting. A gap between two meetings shorter than the look-ahead value stops producing a break.

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.3.1...v0.4.0

## StandLock v0.3.1

**Bug Fixes**
- Calendar Access can be granted again. The notarized build was signed without the calendar entitlement, so clicking Grant in Settings never showed the macOS prompt and StandLock never appeared under Privacy & Security > Calendars (#42, d5079fb, 429f9b3). Thanks @florian-grassl!
- No more crash on macOS 13 Ventura when requesting Calendar access. The usage description for the pre-Sonoma calendar API was missing, and macOS terminates an app that asks without one (93fc6a5)
- Ventura and Sonoma users are now offered updates and can install through Homebrew. The update feed and the cask claimed macOS 15 while the app has required 13 since 0.3.0 (9873261)

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.3.0...v0.3.1

## StandLock v0.3.0

**Features**
- A schedule can now cycle through multiple work intervals instead of one, e.g. 58 min sitting > 2 min break > 28 min standing > 2 min break > repeat. Each interval can carry an optional label, and the break screen shows what comes next ("NEXT: STANDING"). The cycle stays on plan regardless of how a break ends, and each day starts from the first interval. Existing single-interval schedules are unchanged (fixes #30, 8f21732)

**Notes**
- The position within an interval cycle is not saved. Quitting and relaunching restarts the cycle at its first interval, even mid-day.

**Full Changelog:** https://github.com/yagizdo/StandLock/compare/v0.2.8...v0.3.0

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
