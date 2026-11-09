import SwiftUI

/// One short animated hint on first launch (#28). Dismissed with the button or the first touch.
struct FirstRunHint: View {
    static let seenKey = "hasSeenFirstRunHint"

    let dismiss: () -> Void
    @State private var isAnimating = false
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize = 44
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // At the largest text sizes on the small outer display the card scrolls, so the button
        // is never pushed off screen.
        ViewThatFits(in: .vertical) {
            card
            ScrollView { card }
                .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear { isAnimating = !reduceMotion }
    }

    private var card: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: iconSize))
                .symbolEffect(.bounce, options: .repeat(.periodic(delay: 0.8)), value: isAnimating)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            Text("Everyone puts one finger on the screen. Hold still, and FingerPick picks someone.")
                .font(.body)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .allowsHitTesting(false)
            Button("Got it", action: dismiss)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("hint.dismiss")
        }
        .padding(24)
        .frame(maxWidth: 360)
        // Only the button takes touches; a finger anywhere else goes to the play area.
        .background {
            RoundedRectangle(cornerRadius: 24).fill(.regularMaterial).allowsHitTesting(false)
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("hint")
    }
}

#Preview {
    FirstRunHint {}
}
