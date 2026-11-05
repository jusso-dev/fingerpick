import FingerPickKit
import SwiftUI

/// The result label, shown over the winner's colour once the reveal has grown.
struct ResultView: View {
    let reveal: Reveal

    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(ResultText.headline(for: reveal))
            .font(.largeTitle.weight(.bold))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color(.systemBackground))
            .padding()
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible || reduceMotion ? 1 : 0.9)
            .accessibilityLabel(ResultText.spoken(for: reveal))
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("result")
            .allowsHitTesting(false)
            .onAppear {
                let animation: Animation = reduceMotion ? .easeIn(duration: 0.3) : .spring(duration: 0.35)
                withAnimation(animation.delay(Reveal.expandDuration * 0.5)) {
                    isVisible = true
                }
            }
    }
}

enum ResultText {
    /// Short on-screen line, for example "Orange circle 1 picked".
    static func headline(for reveal: Reveal) -> String {
        switch reveal.result {
        case let .winners(ids):
            return String(
                localized: "\(names(ids, in: reveal).formatted(.list(type: .and))) picked",
                comment: "Result. For example: Orange circle 1 picked"
            )
        case let .teams(teams):
            return String(localized: "Split into \(teams.count) teams", comment: "Teams result headline")
        case let .order(ids):
            return String(
                localized: "\(names(Array(ids.prefix(1)), in: reveal).joined()) goes first",
                comment: "Order result headline. For example: Orange circle 1 goes first"
            )
        }
    }

    /// Full result for VoiceOver: every winner, team member or rank.
    static func spoken(for reveal: Reveal) -> String {
        switch reveal.result {
        case .winners:
            return headline(for: reveal)
        case let .teams(teams):
            return teams.enumerated().map { index, ids in
                String(
                    localized: "Team \(index + 1): \(names(ids, in: reveal).formatted(.list(type: .and)))",
                    comment: "One team in the spoken result. For example: Team 1: Orange circle 1 and Blue square 5"
                )
            }.joined(separator: ". ")
        case let .order(ids):
            return ids.enumerated().map { index, id in
                String(
                    localized: "\(index + 1): \(names([id], in: reveal).joined())",
                    comment: "One turn in the spoken order. For example: 1: Orange circle 1"
                )
            }.joined(separator: ". ")
        }
    }

    private static func names(_ ids: [PlayerID], in reveal: Reveal) -> [String] {
        ids.compactMap { reveal.markers[$0] }.map(Palette.name)
    }
}
