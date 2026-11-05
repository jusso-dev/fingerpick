import FingerPickKit
import SwiftUI

/// The result label, shown over the winner's colour once the reveal has grown.
struct ResultView: View {
    let reveal: Reveal

    @State private var isVisible = false

    var body: some View {
        Text(ResultText.headline(for: reveal))
            .font(.largeTitle.weight(.bold))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color(.systemBackground))
            .padding()
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.9)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("result")
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.spring(duration: 0.35).delay(Reveal.expandDuration * 0.5)) {
                    isVisible = true
                }
            }
    }
}

enum ResultText {
    /// For example "Orange circle 1 picked".
    static func headline(for reveal: Reveal) -> String {
        let names = reveal.result.pickedPlayers.compactMap { reveal.markers[$0] }.map(Palette.name)
        switch reveal.result {
        case .winners:
            return String(localized: "\(names.formatted(.list(type: .and))) picked", comment: "Result. For example: Orange circle 1 picked")
        }
    }
}
