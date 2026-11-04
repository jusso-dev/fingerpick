# FingerPick design

## Interaction flow
1. **Waiting:** empty screen with a short prompt ("Everyone put a finger down"). Each new touch gets a ring in a distinct colour.
2. **Stabilising:** fingers are being added or lifted. Any change restarts the stability timer.
3. **Countdown:** with at least 2 fingers (configurable) and no change for about 3 seconds, rings pulse in sync for the countdown. Lifting or adding a finger cancels it and returns to Stabilising.
4. **Selected:** the winner (or winners, teams, order) is revealed. Losing rings fade. A success haptic plays.
5. **Reset:** when all fingers lift, return to Waiting after a short pause.

## States
| State | Entry | Exit |
|---|---|---|
| waiting | app launch, all fingers lifted | first touch |
| countdown | minimum fingers, stable ~3 s | touch added/removed (back), timer ends (selected) |
| selected | selection made | all fingers lifted |

The state machine lives in a pure Swift type so it can be unit tested without UI.

## Haptics (Core Haptics)
- Light transient tap when a finger lands.
- Soft ticks during the countdown, one per second, rising in intensity.
- Strong success pattern on the reveal.
- Fall back to `UIFeedbackGenerator` where Core Haptics isn't supported. Respect the haptics toggle in Settings.

## Accessibility
- **VoiceOver:** an accessible mode announces finger count, countdown and result ("Blue was picked"). Use `UIAccessibility.post(notification:)` announcements. Direct touch area (`.allowsDirectInteraction`) so fingers still register with VoiceOver on.
- **Reduce Motion:** replace pulsing and scaling with fades and colour changes.
- **Dynamic Type:** all text uses text styles and scales to accessibility sizes.
- **Colour contrast:** at least 4.5:1 for text, 3:1 for ring outlines against the background, in light and dark mode.
- **Colour-blind-safe palette:** use a palette based on Okabe-Ito, and pair each colour with a shape or number marker so colour isn't the only cue.

## Layout
- Respect safe areas and the Dynamic Island. No interactive UI under the island or home indicator.
- Defer system edge gestures during a round (`preferredScreenEdgesDeferringSystemGestures`) and hide the home indicator.
- ProMotion: drive animations at up to 120 Hz.
- Keep the screen awake during a round (`isIdleTimerDisabled`).
