import FingerPickKit
import SwiftUI
import UIKit

/// Keeps the screen awake during a round and for two minutes after the last touch (#21).
@MainActor
final class IdleTimerController {
    private var recheck: Task<Void, Never>?

    func update(model: GameModel, scenePhase: ScenePhase) {
        recheck?.cancel()
        let now = model.now()
        let isForeground = scenePhase == .active
        UIApplication.shared.isIdleTimerDisabled = IdleTimerPolicy.keepsScreenAwake(
            isForeground: isForeground,
            hasFingers: model.isRoundActive,
            isShowingResult: model.reveal != nil,
            lastActivity: model.lastActivityAt,
            now: now
        )
        guard isForeground, let next = IdleTimerPolicy.nextCheck(lastActivity: model.lastActivityAt, now: now) else { return }
        recheck = Task { [weak self, model] in
            try? await Task.sleep(for: .seconds(next - now))
            guard !Task.isCancelled else { return }
            self?.update(model: model, scenePhase: scenePhase)
        }
    }
}
