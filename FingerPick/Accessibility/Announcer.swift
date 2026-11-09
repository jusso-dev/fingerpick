import FingerPickKit
import SwiftUI
import UIKit

/// What VoiceOver should say for a batch of round events (#16). Pure, so it's unit-tested.
enum Announcements {
    static func text(
        for events: [RoundEvent], fingerCount: Int, reveal: Reveal?, interruption: EnvironmentChange? = nil
    ) -> String? {
        for event in events.reversed() {
            switch event {
            case .selected:
                return reveal.map(ResultText.spoken(for:))
            case .interrupted:
                return interruption == .rotated
                    ? String(localized: "Screen rotated, everyone put your fingers back down")
                    : String(localized: "Phone folded, everyone put your fingers back down")
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
            // Players lift straight after the reveal; a finger count would cut the result off.
            guard model.reveal == nil else { return }
            pendingCount = Task { [weak model] in
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled, let model else { return }
                Self.post(Announcements.fingerCountText(model.touches.count), priority: .default)
            }
            return
        }
        pendingCount?.cancel()
        let text = Announcements.text(
            for: events, fingerCount: model.touches.count, reveal: model.reveal, interruption: model.interruption?.change
        )
        guard let text else { return }
        // The result must not be cut off; "New round" waits for it to finish.
        let priority: UIAccessibilityPriority = if events.contains(where: { if case .selected = $0 { true } else { false } }) {
            .high
        } else if events.contains(.reset) {
            .low
        } else {
            .default
        }
        Self.post(text, priority: priority)
    }

    private static func post(_ text: String, priority: UIAccessibilityPriority) {
        let announcement = NSAttributedString(string: text, attributes: [.accessibilitySpeechAnnouncementPriority: priority])
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
}
