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

## iPhone Duo (foldable)
Confirmed from Apple sources:
- Outer display 5.4-inch, 1398 x 2034 px at 460 ppi. Inner display 7.6-inch, 1878 x 2670 px at 430 ppi. Both share the same aspect ratio. Both have the Dynamic Island and ProMotion up to 120 Hz.
- The app resizes when the device folds or unfolds; it moves between the outer and inner displays. Size from the view or window, never `UIScreen.main`, and re-layout on every size change.
- The fold is a **division reserved region**: `GeometryProxy.reservedRegions(kind: .division, options: .includeInactive)` in SwiftUI, `UIView.reservedRegions(kind:options:)` in UIKit. It's active only when partially open; when flat it's inactive with zero width. An **occlusion** region covers the inner under-display camera while it's in use.
- Hinge state: `onHingeChange` (SwiftUI) or `UIHingeInteraction` (UIKit), with status closed, partiallyOpen or fullyOpen and an angle. Apple says to use it for effects, not layout.
- Testing: Xcode 27.1 iPhone Duo simulator in Device Hub (Closed, Partially Open, Open). There's no supported `simctl` or XCUITest command to change posture, so fold layouts are also tested in code.

Not confirmed (verify on device before relying on it):
- Whether in-flight `UITouch`es survive a fold or unfold. We assume they're cancelled.
- The physical crease width in points and how reliable touches are directly on the crease when flat.
- Maximum simultaneous touches on the inner display.

### Layouts
- **Inner, fully open:** large canvas, up to the hardware touch maximum. Ring diameter scales with view size. Prompts and Settings button avoid the inner camera occlusion region.
- **Inner, partially open (book or tabletop):** the play area is split by the fold. Winner reveal and labels are centred in the larger half, never across the division. A finger landing on the fold gets a ring nudged clear of it.
- **Outer (closed):** compact mode, same flow, smaller recommended player count (prompt suggests up to 6).

### Folding mid-round
Treat any fold or unfold, display move or size change during countdown as a cancel: stop the countdown, clear touches, play a soft haptic and show "Phone folded, everyone put your fingers back down". If a result is showing, keep the result and re-lay it out on the new display. Never select a winner from touches that were cancelled by the transition.
