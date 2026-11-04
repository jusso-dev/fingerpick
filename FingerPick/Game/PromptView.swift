import FingerPickKit
import SwiftUI

/// Short status line at the top of the play area.
struct PromptView: View {
    let model: GameModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            content(now: model.now())
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func content(now: TimeInterval) -> some View {
        let engine = model.engine
        switch engine.phase {
        case .waiting:
            if engine.players.isEmpty {
                Text("Everyone put a finger down")
                    .font(.title2.weight(.semibold))
            } else {
                Text("Waiting for at least \(engine.configuration.requiredPlayers) fingers")
                    .font(.title3)
            }
        case .stabilising:
            if let cancelled = model.countdownCancelledAt, now - cancelled < 1.5 {
                Text("Countdown cancelled. Hold still")
                    .font(.title3.weight(.semibold))
            } else {
                Text("Hold still")
                    .font(.title3)
            }
        case let .countdown(start):
            let remaining = engine.configuration.countdownDuration - (now - start)
            Text(Int(max(1, remaining.rounded(.up))), format: .number)
                .font(.largeTitle.weight(.bold).monospacedDigit())
                .contentTransition(.numericText(countsDown: true))
        case .selected:
            EmptyView()
        }
    }
}
