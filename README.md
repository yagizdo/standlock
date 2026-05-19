# StandLock

[![Version](https://img.shields.io/badge/version-0.1.1-blue)](https://github.com/yagizdo/StandLock/releases)
[![Release](https://github.com/yagizdo/standlock/actions/workflows/release.yml/badge.svg)](https://github.com/yagizdo/standlock/actions/workflows/release.yml)
[![macOS 15+](https://img.shields.io/badge/macOS-15%2B-brightgreen)](https://github.com/yagizdo/StandLock/releases/latest)
[![Homebrew](https://img.shields.io/badge/brew-yagizdo%2Ftap%2Fstandlock-orange)](https://github.com/yagizdo/homebrew-tap)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple)](LICENSE)

A macOS menu bar app that reminds you to stand up and move. It sits quietly in your menu bar, tracks your schedules, and puts a full-screen overlay when it's time for a break. You pick how strict it should be: skip freely, type a phrase to dismiss, or lock your input entirely until the break is over.

## Why

Most break reminder apps show a notification you can swipe away in half a second. That doesn't work if you're deep in focus and keep ignoring it. StandLock takes a different approach: instead of asking nicely, it can actually block your screen. You choose the level of enforcement per schedule. Use Gentle mode during casual browsing and Strict mode during long coding sessions. The goal is to make skipping a break a conscious decision, not a reflex.

## Features

**Three Discipline Levels**

| Level | Behavior |
|-------|----------|
| Gentle | Full-screen overlay with an immediate skip button |
| Firm | Timed skip delay + type an escape phrase to dismiss |
| Strict | Full input blocking, only an emergency key combo exits |

**Smart Scheduling**
- Multiple named schedules with independent settings
- Time windows (e.g., 09:00–12:00, 13:00–17:00)
- Day selection: weekdays, weekends, every day, or custom
- Pomodoro-style repetition cycles (short/long break patterns)

**Context Awareness**
- Defers breaks during meetings (camera/microphone active)
- Respects screen sharing sessions
- Integrates with Calendar to skip during events
- Detects idle time so you don't get a break after already being away
- Honors macOS Focus modes

**Break Experience**
- Full-screen overlay with countdown timer
- Exercise suggestions during breaks (stretches, water breaks, squats)
- Streak and completion statistics in the menu bar

## Install

### Requirements

- macOS 15+ (Sequoia)

### GitHub Releases

Download: <https://github.com/yagizdo/StandLock/releases/latest>

### Homebrew

```bash
brew install --cask yagizdo/tap/standlock
```

## macOS Permissions

StandLock requests only the permissions it needs, and only when you use a feature that requires them.

| Permission | Why |
|------------|-----|
| **Accessibility** | Required for Strict mode. Blocks keyboard and mouse input during breaks by installing a system-level event tap. Without this, Strict mode cannot enforce breaks. |
| **Input Monitoring** | Recommended alongside Accessibility. Lets StandLock detect idle time accurately so it won't interrupt you right after you've already been away from the keyboard. |
| **Calendar** | Optional. Reads your calendar events to automatically defer breaks during meetings. Never modifies your calendar. |
| **Camera & Microphone** | Not accessed directly. StandLock checks whether another app is using the camera or mic to detect active meetings and defer breaks accordingly. |

You can revoke any permission at any time in **System Settings > Privacy & Security**. StandLock will fall back gracefully: Strict mode becomes unavailable without Accessibility, idle detection becomes less accurate without Input Monitoring, and meeting detection is skipped without Calendar access.

## Building from Source

```bash
git clone https://github.com/yagizdo/StandLock.git
cd StandLock
open StandLock.xcodeproj
```

Build and run the `StandLock` scheme in Xcode. The app lives in your menu bar.

## License

MIT · Yilmaz Yagiz Dokumaci ([yagizdo](https://x.com/yagizdo))
