# StandLock

[![Version](https://img.shields.io/badge/version-0.2.6-blue)](https://github.com/yagizdo/StandLock/releases)
[![Release](https://github.com/yagizdo/standlock/actions/workflows/release.yml/badge.svg)](https://github.com/yagizdo/standlock/actions/workflows/release.yml)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-brightgreen)](https://github.com/yagizdo/StandLock/releases/latest)
[![Homebrew](https://img.shields.io/badge/brew-yagizdo%2Ftap%2Fstandlock-orange)](https://github.com/yagizdo/homebrew-tap)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple)](LICENSE)
[![Website](https://img.shields.io/badge/website-standlock.app-blue)](https://standlock.app?ref=github-readme)

A macOS menu bar app that forces you to take stand-up breaks. It runs quietly in your menu bar, manages multiple schedules, and puts a full-screen overlay on every display when it's time. You pick how strict each schedule should be, and the app gets progressively harder to dismiss the more you skip.

## Why

Most break reminder apps show a notification you can swipe away in half a second. That doesn't work if you're deep in focus and keep ignoring it. StandLock takes a different approach: instead of asking nicely, it can actually block your screen. You choose the level of enforcement per schedule. Use Gentle mode during casual browsing and Strict mode during long coding sessions. The goal is to make skipping a break a conscious decision, not a reflex.

## Features

### Discipline Levels

Each schedule has its own discipline level. Pick one per schedule and change it anytime.

| Level | Behavior |
|-------|----------|
| Gentle | Full-screen overlay with an immediate skip button |
| Firm | Timed skip delay + type an escape phrase to dismiss |
| Strict | Full input blocking, only an emergency key combo (Ctrl+Option+Command hold) exits |

### Escalation

Enable progressive enforcement on any schedule and each consecutive skip makes the next break harder to dismiss. Challenges range from dodging buttons and mini-games to typing embarrassing phrases with snarky app commentary. Complete a break (or let idle detection count one) and the tier resets.

### Smart Scheduling

- Multiple named schedules, each with its own discipline level and settings
- Time windows (e.g., 09:00-12:00, 13:00-17:00)
- Day selection: weekdays, weekends, every day, or custom
- Pomodoro-style repetition cycles with short/long break patterns
- Configurable daily skip limits per discipline level

### Context Awareness

- Defers breaks during meetings (camera/microphone active) or screen sharing
- Integrates with Calendar to skip during upcoming events
- Detects idle time: if you've already been away long enough, the break counts as completed
- Honors macOS Focus modes
- Each detection can be set to defer the break, reduce to Gentle, or ignore it entirely

### Break Experience

- Full-screen overlay on every display with countdown timer
- Exercise suggestions during breaks (stretches, water reminders, squats)
- Pauses system media during breaks

### Break Statistics

A dedicated Statistics tab in Settings tracks break history over time.

- 6 metric cards: completions, skips, completion rate, current streak, best streak, total break time
- Week view with per-day cards, month calendar, and year heatmap
- Filtered by period: today, this week, this month, this year

### Menu Bar

- Timer showing remaining time until next break (always-on or last-minutes countdown)
- Break stats: completions, streak, and skips for today
- Pause/resume controls

### General

- **Launch at login** via macOS login items
- **Auto-update** checks every 4 hours via Sparkle, with an update banner in the menu bar

## Install

### Requirements

- macOS 13+ (Ventura)

### GitHub Releases

Download the DMG: <https://github.com/yagizdo/StandLock/releases/latest>

Drag StandLock to your Applications folder, then open it. The app appears in your menu bar.

### Homebrew

```bash
brew install --cask yagizdo/tap/standlock
```

## macOS Permissions

StandLock requests only the permissions it needs, and only when you use a feature that requires them.

| Permission | Why |
|------------|-----|
| **Accessibility** | Required for Strict mode. Blocks keyboard and mouse input during breaks by installing a system-level event tap. Without this, Strict mode cannot enforce breaks. |
| **Input Monitoring** | Required for Strict mode (alongside Accessibility). Also lets StandLock detect idle time accurately so it won't interrupt you right after you've already been away from the keyboard. |
| **Calendar** | Optional. Reads your calendar events to automatically defer breaks during meetings. Never modifies your calendar. |
| **Camera & Microphone** | Not accessed directly. StandLock checks whether another app is using the camera or mic to detect active meetings and defer breaks accordingly. |

You can revoke any permission at any time in **System Settings > Privacy & Security**. When a permission is revoked, features that depend on it are auto-disabled: Strict mode switches schedules back to Gentle, idle detection turns off, and calendar integration is skipped. No crashes, no broken state.

## Building from Source

```bash
git clone https://github.com/yagizdo/StandLock.git
cd StandLock
xcodegen generate   # required after pulling -- regenerates StandLock.xcodeproj from project.yml
open StandLock.xcodeproj
```

Build and run the `StandLock` scheme in Xcode. The app lives in your menu bar.

### Deployment Target

The minimum macOS version is declared in two source-of-truth files:

- `project.yml` -- app target (Xcode project is regenerated from this with `xcodegen generate`)
- `StandLockKit/Package.swift` -- Swift package (separate platform list)

When raising or lowering the deployment target, update both files and run `xcodegen generate` to refresh `StandLock.xcodeproj`. Direct edits to `StandLock.xcodeproj/project.pbxproj` are overwritten on the next regeneration.

## License

MIT · Yilmaz Yagiz Dokumaci ([yagizdo](https://x.com/yagizdo))
