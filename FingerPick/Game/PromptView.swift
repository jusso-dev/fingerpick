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

    /// Larger text on large canvases such as the iPhone Duo inner display.
    private var isLarge: Bool { model.layout.canvas == .large }

    @ViewBuilder
    private func content(now: TimeInterval) -> some View {
        let engine = model.engine
        switch engine.phase {
        case .waiting:
            if let interruption = model.interruption, engine.players.isEmpty {
                Text(interruption.change == .folded
                     ? "Phone folded, everyone put your fingers back down"
                     : "Screen rotated, everyone put your fingers back down")
                    .font(isLarge ? .title2.weight(.semibold) : .title3.weight(.semibold))
            } else if engine.players.isEmpty {
                VStack(spacing: 6) {
                    Text("Everyone put a finger down")
                        .font(isLarge ? .largeTitle.weight(.semibold) : .title2.weight(.semibold))
                    Text("Best with up to \(model.layout.suggestedPlayers) players")
                        .font(isLarge ? .title3 : .subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Waiting for at least \(engine.configuration.requiredPlayers) fingers")
                    .font(isLarge ? .title2 : .title3)
            }
        case .stabilising:
            if let cancelled = model.countdownCancelledAt, now - cancelled < 1.5 {
                Text("Countdown cancelled. Hold still")
                    .font(isLarge ? .title2.weight(.semibold) : .title3.weight(.semibold))
            } else {
                Text("Hold still")
                    .font(isLarge ? .title2 : .title3)
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
