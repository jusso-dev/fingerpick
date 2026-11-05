import FingerPickKit
import Testing
import UIKit
@testable import FingerPick

struct AnnouncementTests {
    private let reveal = Reveal(
        result: .winners([PlayerID(0)]), markers: [PlayerID(0): PlayerMarker(slot: 0)], positions: [:], startedAt: 0
    )

    @Test func announcesFingerCountCountdownAndResult() {
        #expect(Announcements.text(for: [.playerJoined(PlayerID(0))], fingerCount: 3, reveal: nil) == "3 fingers down")
        #expect(Announcements.text(for: [.countdownStarted, .countdownTick(secondsRemaining: 3)], fingerCount: 2, reveal: nil)
            == "Countdown started. Hold still")
        #expect(Announcements.text(for: [.selected(reveal.result)], fingerCount: 2, reveal: reveal) == "Orange circle 1 picked")
        #expect(Announcements.text(for: [.playerLeft(PlayerID(1)), .countdownCancelled], fingerCount: 1, reveal: nil)
            == "Countdown cancelled")
        #expect(Announcements.text(for: [.interrupted], fingerCount: 0, reveal: nil)?.hasPrefix("Phone folded") == true)
        #expect(Announcements.text(for: [.countdownTick(secondsRemaining: 2)], fingerCount: 2, reveal: nil) == nil)
    }
}

@MainActor
struct PlayAreaAccessibilityTests {
    @Test func playAreaAllowsDirectInteraction() {
        let view = MultitouchView()
        #expect(view.isAccessibilityElement)
        #expect(view.accessibilityTraits.contains(.allowsDirectInteraction))
        #expect(view.accessibilityLabel == "Play area")
    }
}

/// Dark mode uses a true black background (OLED); light mode uses white (#19).
struct AppearanceTests {
    @Test func backgroundIsBlackInDarkModeAndWhiteInLight() {
        let dark = UIColor.systemBackground.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        let light = UIColor.systemBackground.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var white: CGFloat = 0, alpha: CGFloat = 0
        dark.getWhite(&white, alpha: &alpha)
        #expect(white == 0)
        light.getWhite(&white, alpha: &alpha)
        #expect(white == 1)
    }
}
