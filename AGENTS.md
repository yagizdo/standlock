# Agent instructions

Read [CONTRIBUTING.md](CONTRIBUTING.md) before changing anything. It covers setup, tests, code rules and pull request expectations. The points below are the ones agents get wrong most often.

- Most logic lives in `StandLockKit`, a plain Swift package. Put new logic there, not in the app target, so it stays testable.
- Run `swift test --package-path StandLockKit` before you finish. A bug fix needs a regression test that fails before the fix.
- If the suite dies with `signal code 11` after a model change, run `swift package clean --package-path StandLockKit` and retry.
- No `print()`, `debugPrint()`, or `NSLog()` in committed code. Do not wrap them in `#if DEBUG`; delete them.
- One concern per file, named after its primary type. Keep helpers out of `StandLockApp.swift` and `AppDelegate.swift`.
- Build settings go in `project.yml`, not `StandLock.xcodeproj`. The project file is regenerated from `project.yml` and the folder contents.
- Do not edit `CHANGELOG.md`. Release notes are written at release time.
- Do not add dependencies without an issue agreeing to it first.
- Keep AI out of git metadata: no `Co-Authored-By:` trailers naming an AI tool, no "Generated with" lines in commits or PR descriptions.
