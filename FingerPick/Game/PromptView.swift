import FingerPickKit
import SwiftUI

/// Short status line at the top of the play area.
struct PromptView: View {
    let model: GameModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            let now = model.now()
            content(now: now)
                .id(stage(now: now))
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 6)))
                .animation(.smooth(duration: 0.25), value: stage(now: now))
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal)
        .allowsHitTesting(false)
    }

    /// Which message shows. Changing it cross-fades the prompt; the countdown number rolls instead.
    private func stage(now: TimeInterval) -> Int {
        let engine = model.engine
        switch engine.phase {
        case .waiting:
            if model.interruption != nil, engine.players.isEmpty { return 0 }
            return engine.players.isEmpty ? 1 : 2
        case .stabilising:
            if let cancelled = model.countdownCancelledAt, now - cancelled < 1.5 { return 3 }
            return 4
        case .countdown: return 5
        case .selected: return 6
        }
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
            let seconds = Int(max(1, remaining.rounded(.up)))
            Text(seconds, format: .number)
                .font(.largeTitle.weight(.bold).monospacedDigit())
                .contentTransition(reduceMotion ? .opacity : .numericText(countsDown: true))
                .animation(.snappy, value: seconds)
        case .selected:
            EmptyView()
        }
    }
}
