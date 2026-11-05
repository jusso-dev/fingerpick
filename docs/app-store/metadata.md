# App Store Connect metadata

Draft listing for FingerPick. Nothing here has been submitted. Fields marked **(to confirm)** need the owner's decision.

## App information
| Field | Value |
|---|---|
| Name | FingerPick |
| Subtitle (30) | Everyone taps. One gets picked. |
| Bundle ID | `dev.jusso.fingerpick` |
| Primary category | Entertainment |
| Secondary category | Utilities |
| Age rating | 4+ (no objectionable content) |
| Price | Free **(to confirm)** |
| Copyright | 2026 Justin Middler **(to confirm)** |
| Support URL | https://github.com/jusso-dev/fingerpick/issues |
| Privacy policy URL | https://github.com/jusso-dev/fingerpick/blob/main/docs/privacy.md **(to confirm: GitHub Pages or own domain)** |

## Promotional text (170)
Can't decide who goes first? Everyone puts a finger on the screen and FingerPick chooses, fairly and instantly. Built for iPhone Duo.

## Description
Everyone puts a finger on the screen. After a short countdown, FingerPick picks one person at random. Use it to decide who goes first, who pays, or who does the dishes.

• Fair: every pick uses the system's secure random number generator, so finger order and position make no difference.
• Four modes: pick one winner, pick several, split into balanced teams, or rank everyone in turn order.
• Clear for everyone: every player gets a colour, a shape and a number, with a colour-blind-safe palette.
• Feels right: rings follow each finger, the countdown pulses, and haptics confirm every step.
• Made for iPhone Duo: a large canvas for bigger groups on the inner display, a compact mode on the cover screen, and content that stays clear of the fold.
• Accessible: VoiceOver, Reduce Motion, Dynamic Type, Increase Contrast, light and dark mode.
• Private: no accounts, no ads, no tracking, no data collected. Works fully offline.

## Keywords (100)
`decide,chooser,random,picker,finger,who goes first,party,game,team,turn order,roulette,draw,lots`

## What's New (1.0)
First release.

## Screenshots
Required sizes: 6.9" (1320 × 2868) and 6.3" (1206 × 2622). Generate them with the **Screenshots** workflow (`.github/workflows/screenshots.yml`), which runs `AppStoreScreenshots` UI tests on the iPhone 18 Pro Max and iPhone 18 Pro simulators and uploads the PNGs as an artefact.

1. Waiting screen: "Everyone put a finger down".
2. Five fingers counting down.
3. Winner reveal.
4. Teams.
5. Turn order.

## App Privacy (nutrition label)
- Data collection: **Data Not Collected**. Answer "No, we do not collect data from this app".
- Tracking: none. App Tracking Transparency isn't used.
- Privacy manifest: `FingerPick/Resources/PrivacyInfo.xcprivacy` (no tracking, no collected data types; required-reason APIs: UserDefaults `CA92.1`, system boot time `35F9.1`).

## Review notes
No sign-in needed. To test: have two or more people (or two fingers) touch the screen and hold still for about four seconds. Settings (gear icon, top corner on the empty screen) changes the mode.

## Accessibility (App Store accessibility labels) (to confirm)
Supports VoiceOver, Larger Text, Dark Interface, Differentiate Without Colour Alone (shape and number markers), Sufficient Contrast and Reduced Motion. Confirm each after the manual checks in docs/testing.md.
