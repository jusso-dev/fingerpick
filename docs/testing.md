# Testing FingerPick

## Automated

| What | Where | Runs in CI |
|---|---|---|
| Round engine, picker, modes, slots, idle policy, layout and fold geometry | `Packages/FingerPickKit/Tests` (`swift test`) | Yes, with a 90% per-file line coverage gate |
| Model, haptics mapping, palette contrast, settings, announcements, fold handling | `Tests/FingerPickTests` (app-hosted) | Yes, on iPhone 17 and iPhone Duo simulators |
| Launch, first-run hint, settings, simulated rounds in every mode | `Tests/FingerPickUITests` | Yes |
| Screenshots in light, dark and AX5 | `FingerPickScreenshotTests`, attached to the `.xcresult` | Yes (kept, not diffed) |

UI tests can't put several fingers down, so the app accepts `-uitest` (debug builds only). This adds an **Add finger / Lift all** injector that feeds fake touches through the real model. Related arguments: `-uitest-reset` clears saved settings, `-uitest-seed <n>` makes picks deterministic, `-uitest-dark` / `-uitest-light` force an appearance. Any setting can be overridden for a launch with its key, for example `-countdownSeconds 1 -mode teams`.

Fold geometry is tested in code with fake division and occlusion regions (`FoldLayoutTests`, `PlayLayoutTests`, `FoldHandlingTests`). The iPhone Duo simulator has no supported `simctl` or XCUITest control for posture and boots closed, so CI covers the outer display only. Don't add unsupported community fold tools to CI.

## Manual iPhone Duo checklist

Run before every TestFlight build, on the iPhone Duo simulator in Xcode 27.1+ (Device Hub posture controls) and on a device when available. Repeat each posture in portrait and both landscape orientations.

For each posture, check:

- [ ] Prompt, Settings button and result are inside the safe area, clear of the Dynamic Island and the inner camera.
- [ ] Rings appear under every finger and follow them; badges stay readable.
- [ ] A full round completes and the reveal plays; haptics fire (device only).
- [ ] Settings opens, and changes apply to the next round.

### Closed (outer display)
- [ ] Compact layout: prompt suggests up to 6 players; rings at least 88 pt.
- [ ] No clipped text at AX5 (Settings > Accessibility > Display & Text Size).

### Open (inner display, flat)
- [ ] Large layout: bigger rings and text; prompt suggests up to 10 players.
- [ ] Ten fingers are tracked (device). Note the maximum the hardware reports: ______.
- [ ] Nothing drawn under the inner camera when it's in use.
- [ ] A finger directly on the crease registers. Note how reliable it is: ______.

### Partially open, book (vertical fold)
- [ ] Countdown, prompt and result sit in the larger half, never across the fold.
- [ ] A finger on the fold still counts; its ring is drawn beside the fold.

### Partially open, tabletop (horizontal fold, rotated)
- [ ] Same as book posture, with the fold horizontal.

### Transitions
- [ ] Fold or unfold during the countdown: the round cancels, a soft haptic plays, "Phone folded, everyone put your fingers back down" shows, and no winner is picked.
- [ ] Fold or unfold while a result shows: the result stays and is laid out again on the new display.
- [ ] 20 fold/unfold cycles: layout stays correct, no crash.
- [ ] Debug build: check the `dev.jusso.fingerpick` / `fold` log to see whether touches that were down during a fold delivered events afterwards. Record the result here: ______.

## Other manual checks
- VoiceOver: a full round with VoiceOver on (the play area allows direct interaction); announcements for finger count, countdown and result.
- Reduce Motion, Increase Contrast, AX5 text, light and dark mode.
- Double-length pseudo-language: run the **FingerPick (Double-length)** scheme and look for clipped text.
- Instruments: no hitches with 10 rings on a ProMotion device, running at 120 Hz.
