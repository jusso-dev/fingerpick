# FingerPick

Everyone puts a finger on the iPhone screen. After a short countdown, FingerPick picks one person at random. Use it to decide who goes first, who pays, or who does the dishes.

## How it works
1. Each person places one finger on the screen. A coloured ring appears under every finger.
2. When nobody has added or lifted a finger for about 3 seconds, a countdown runs.
3. FingerPick selects a winner with a fair, uniform random choice. The winning ring grows, the others fade, and the phone gives a haptic tap.
4. Lift all fingers to start a new round.

Modes: pick one winner, pick several, split into teams, or rank everyone in order.

## Design principles (Apple Human Interface Guidelines)
- Content first: the whole screen is the play area, with minimal chrome.
- Direct manipulation and instant feedback for every touch.
- Haptics that match what's on screen, never gratuitous.
- Full support for VoiceOver, Reduce Motion, Dynamic Type, Increase Contrast and colour-blind-safe colours.
- Respects safe areas, the Dynamic Island, light and dark mode.

See [docs/design.md](docs/design.md).

## Tech
- SwiftUI app shell, with a UIKit multitouch view bridged through `UIViewRepresentable` (SwiftUI gestures don't track 10+ independent touches well).
- iOS 18+ deployment target, built with the iOS 27.1 SDK so iPhone Duo fold APIs are used where available (`if #available`).
- Core Haptics, `SystemRandomNumberGenerator`.
- Fully offline. No ads, no tracking, no accounts, no data collected.

## Optimised for iPhone Duo
FingerPick is built first for iPhone Duo, Apple's foldable iPhone, and works on every other current iPhone.
- **Unfolded (7.6-inch inner display, 1878 x 2670 px):** a large canvas for bigger groups around a table. Rings are sized and spaced for more players.
- **Folded (5.4-inch outer display, 1398 x 2034 px):** a compact cover-screen mode for small groups. Both displays share the same aspect ratio, so the layout scales proportionally.
- **Folding or unfolding mid-round:** the round resets safely, with a clear message, rather than picking from a broken set of touches.
- **The crease:** rings, countdown and winner reveal stay clear of the fold using iOS 27.1's reserved-region API (`reservedRegions(kind: .division)`).
- **Adaptive layout:** sized from the view, never `UIScreen.main`, using size classes and geometry changes.
- Tested on the iPhone Duo simulator in Xcode 27.1 (Closed, Partially Open, Open).

Specs from [Apple's iPhone Duo tech specs](https://www.apple.com/iphone-duo/specs/) and APIs from [Apple's iPhone Duo Prepare guide](https://developer.apple.com/iphone-duo/prepare/) and the [adaptive layouts tech talk](https://developer.apple.com/videos/play/tech-talks/111463/).

## Building
[![CI](https://github.com/jusso-dev/fingerpick/actions/workflows/ci.yml/badge.svg)](https://github.com/jusso-dev/fingerpick/actions/workflows/ci.yml)

Requires Xcode 27.1 or later (iOS 27.1 SDK). The deployment target is iOS 18. CI runs on GitHub's `xcode-27` image against the iPhone 17 and iPhone Duo simulators.

```sh
open FingerPick.xcodeproj            # then Run on an iPhone simulator
```

Command line:

```sh
xcodebuild -project FingerPick.xcodeproj -scheme FingerPick \
  -destination 'platform=iOS Simulator,name=iPhone 17' build test
```

The pure game logic lives in the local Swift package `Packages/FingerPickKit` and also tests on macOS:

```sh
swift test --package-path Packages/FingerPickKit
```

`FingerPick.xcodeproj` is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen). After adding or removing files, run `xcodegen generate` and commit the result. Lint with `swiftlint`.

## Status
In development. See the issues and milestones (MVP, v1, Later).

## Licence
MIT
