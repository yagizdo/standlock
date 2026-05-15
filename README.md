# StandLock

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

## Requirements

- macOS 14.0 or later
- Accessibility permission (required for Strict mode input blocking)
- Input Monitoring permission (recommended)
- Calendar access (optional, for meeting detection)

## Building from Source

```bash
git clone https://github.com/yagizdo/StandLock.git
cd StandLock
open StandLock.xcodeproj
```

Build and run the `StandLock` scheme in Xcode. The app lives in your menu bar.

## Architecture

StandLock is built with SwiftUI and AppKit, organized as a modular Swift Package:

```
StandLockKit/
├── StandLockCore    # Shared models, protocols, and types
├── Scheduling       # Schedule evaluation and repetition tracking
├── Detection        # Camera, mic, screen sharing, calendar, idle, focus mode
├── Coordination     # Break lifecycle orchestration
└── Locking          # Event tap controller and escape detection
```

The main app target (`StandLock/`) contains the UI layer: menu bar popover, settings, onboarding, and the break overlay window.

## License

[MIT](LICENSE)
