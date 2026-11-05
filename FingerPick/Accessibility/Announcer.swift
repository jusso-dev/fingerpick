import FingerPickKit
import SwiftUI
import UIKit

/// What VoiceOver should say for a batch of round events (#16). Pure, so it's unit-tested.
enum Announcements {
    static func text(for events: [RoundEvent], fingerCount: Int, reveal: Reveal?) -> String? {
        for event in events.reversed() {
            switch event {
            case .selected:
                return reveal.map(ResultText.spoken(for:))
            case .interrupted:
                return String(localized: "Phone folded, everyone put your fingers back down")
            case .countdownCancelled:
                return String(localized: "Countdown cancelled")
            case .countdownStarted:
                return String(localized: "Countdown started. Hold still")
            case .reset:
                return String(localized: "New round. Everyone put a finger down")
            case .playerJoined, .playerLeft:
                return fingerCountText(fingerCount)
            case .countdownTick:
                continue
            }
        }
        return nil
    }

    static func fingerCountText(_ count: Int) -> String {
        String(localized: "\(count) fingers down", comment: "VoiceOver finger count. Pluralised in the string catalogue.")
    }
}

/// Posts announcements while VoiceOver is running. Finger-count changes are coalesced so a group
/// putting fingers down doesn't queue one announcement per finger.
@MainActor
final class Announcer {
    private var pendingCount: Task<Void, Never>?

    func handle(_ events: [RoundEvent], model: GameModel) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        let onlyFingers = events.allSatisfy {
            switch $0 {
            case .playerJoined, .playerLeft: true
            default: false
            }
        }
        guard !onlyFingers else {
            pendingCount?.cancel()
            pendingCount = Task { [weak model] in
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled, let model else { return }
                Self.post(Announcements.fingerCountText(model.touches.count))
            }
            return
        }
        pendingCount?.cancel()
        if let text = Announcements.text(for: events, fingerCount: model.touches.count, reveal: model.reveal) {
            Self.post(text)
        }
    }

    private static func post(_ text: String) {
        AccessibilityNotification.Announcement(text).post()
    }
}
