# Contributing to StandLock

Thanks for helping out. StandLock is a small app with one maintainer, so small, focused PRs get merged fastest. If you found a bug, open a PR. If you want to add a feature or change how something behaves, open an issue first so we can agree on the approach before you spend an evening on it.

## Setup

Most of the logic lives in `StandLockKit`, a plain Swift package. For changes there you don't need Xcode at all. Running `swift test --package-path StandLockKit` from the repo root is enough.

For the app itself:

```bash
git clone https://github.com/yagizdo/StandLock.git
cd StandLock
open StandLock.xcodeproj
```

Xcode will complain that it has no account for my signing team. Pick your own team, or "Sign to Run Locally", under Signing & Capabilities, and leave that change out of your commit.

The project file is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen) and committed, so you don't need XcodeGen installed. Add, move, or delete files through Xcode as usual. The project is regenerated from the folder contents anyway, so nothing you add gets lost. Build settings belong in `project.yml`, since anything set directly in the project file is lost on the next regeneration.

## Tests

Every test lives in `StandLockKit`, one test target per module (`StandLockCore`, `Scheduling`, `Detection`, `Locking`, `Coordination`). CI runs the suite on each PR.

```bash
swift test --package-path StandLockKit
```

When you change behaviour in `StandLockKit`, update the tests that cover it. New logic needs new tests in the matching test target. For a bug fix, add a regression test that fails before the fix and passes after. That test is often more useful to me than the fix itself. Changes that only touch the app target (the UI) have no unit tests, so describe in the PR how you checked them. Put new logic in `StandLockKit` where you can, so it stays testable.

Before you add a test, name the bug it would catch. If another test already fails for that bug, extend it or turn it into a parameterized `@Test(arguments:)` instead of adding a near copy. See every new test fail once, before the fix or by breaking the line it covers for a moment. Do not test what the compiler or Foundation already guarantees: a synthesized `Codable` round trip, `Equatable`, `allCases.count`, or a constant compared with its own literal.

One thing that will confuse you at some point: after you add or remove a stored property on a model, the suite may die with `signal code 11` and no failing test name. That is SPM linking a test target against a stale build. Run `swift package clean --package-path StandLockKit` and try again.

## Code

- No `print()`, `debugPrint()`, or `NSLog()` in committed code.
- One concern per file, named after its primary type. Keep helpers out of `StandLockApp.swift` and `AppDelegate.swift`.
- Open an issue before adding a dependency.
- Leave `CHANGELOG.md` alone. I write the release notes when I cut a release and credit contributors there.
- The minimum macOS version lives in four files. See [Deployment Target](#deployment-target) before changing it.

## Deployment Target

The minimum macOS version is declared in four places, and they do not derive from each other:

- `project.yml` -- app target (Xcode project is regenerated from this with `xcodegen generate`)
- `StandLockKit/Package.swift` -- Swift package (separate platform list)
- `scripts/generate-appcast.sh` -- `sparkle:minimumSystemVersion`, decides which installs Sparkle offers the update to
- `scripts/update-homebrew-cask.sh` -- `depends_on macos:`, decides who `brew install` lets in

When raising or lowering the deployment target, update all four and run `xcodegen generate` to refresh `StandLock.xcodeproj`. Direct edits to `StandLock.xcodeproj/project.pbxproj` are overwritten on the next regeneration.

The last two are easy to miss because nothing fails when they are wrong: the build succeeds, and users on the excluded versions are simply never offered the app. That is how 0.3.0 shipped telling Sparkle and Homebrew it needed macOS 15 while the binary reported `minos 13.0`.

## Pull requests

Branch from `main` and keep each PR to one change. Write commit subjects in the imperative mood, like "Fix calendar prompt on Ventura". In the description, say what problem the PR solves, what changed, and how you tested it. UI changes should come with a screenshot.

## AI tools

Use them if they help. Read and understand every line before you submit it, because you are the one I will be talking to in review. Keep AI out of the git metadata: no "Generated with Claude Code" style lines in commits or PR descriptions, and no `Co-Authored-By:` trailers naming an AI tool. GitHub turns those trailers into contributor credits, and that list is for people. Mentioning in the PR description that you used an AI tool is fine, but you don't have to. [AGENTS.md](AGENTS.md) carries the same rules in a form coding agents pick up on their own.

Contributions are licensed under the [MIT License](LICENSE).
