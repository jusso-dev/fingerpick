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
- iOS 18+, iPhone first.
- Core Haptics, `SystemRandomNumberGenerator`.
- Fully offline. No ads, no tracking, no accounts, no data collected.

## A note on "iPhone Duo optimised"
The original brief said "iPhone Duo optimised". There's no iPhone Duo model, so we've read this as iPhone first, optimised for the current lineup: Dynamic Island, ProMotion 120 Hz displays and all current screen sizes. If it meant something else (for example two-player play, or a dual-screen device), raise an issue.

## Status
Planning. See the issues and milestones (MVP, v1, Later).

## Licence
MIT
