import FingerPickKit
import SwiftUI

/// The FingerPick mark: four players' rings round the picked winner. The geometry matches the app
/// icon (scripts/make-icon.swift) and the launch screen logo (scripts/make-launch-logo.swift).
struct LogoMark: View {
    /// The four rings have landed. Changing it springs them in one after another.
    var landed = true
    /// Changing it plays the winner's pop and ripple.
    var picked = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Point size of the launch screen logo, so the splash starts exactly where the launch screen
    /// left off.
    static let launchSize: CGFloat = 240

    /// Player colours for the four rings, clockwise from top left (sky blue, green, yellow,
    /// purple), round the orange winner. Okabe-Ito, as in the icon.
    private static let ringSlots = [1, 2, 3, 6]

    var body: some View {
        GeometryReader { proxy in
            let s = min(proxy.size.width, proxy.size.height)
            ZStack {
                ForEach(0..<4, id: \.self) { index in
                    ring(index, size: s)
                }
                winner(size: s)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func ring(_ index: Int, size s: CGFloat) -> some View {
        let angle = 5 * Double.pi / 4 + Double(index) * .pi / 2
        return Circle()
            .stroke(Palette.colour(PlayerMarker(slot: Self.ringSlots[index])), lineWidth: s * 0.03)
            .frame(width: s * 0.17, height: s * 0.17)
            // Reduce Motion: the rings fade in where they are instead of springing up.
            .scaleEffect(landed || reduceMotion ? 1 : 0.01)
            .opacity(landed ? 1 : 0)
            .offset(x: cos(angle) * s * 0.33, y: sin(angle) * s * 0.33)
            .animation(
                (reduceMotion ? Animation.easeOut(duration: 0.25) : .spring(duration: 0.45, bounce: 0.45))
                    .delay(Double(index) * 0.07),
                value: landed
            )
    }

    private func winner(size s: CGFloat) -> some View {
        let colour = Palette.colour(PlayerMarker(slot: 0))
        return ZStack {
            Circle()
                .stroke(colour, lineWidth: s * 0.02)
                .frame(width: s * 0.37, height: s * 0.37)
                .keyframeAnimator(initialValue: Ripple(), trigger: picked) { content, ripple in
                    content.scaleEffect(ripple.scale).opacity(ripple.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) { CubicKeyframe(2.2, duration: 0.8) }
                    KeyframeTrack(\.opacity) {
                        LinearKeyframe(0.7, duration: 0.01)
                        LinearKeyframe(0, duration: 0.79)
                    }
                }
            Group {
                Circle()
                    .fill(colour)
                    .frame(width: s * 0.27, height: s * 0.27)
                Circle()
                    .stroke(colour, lineWidth: s * 0.025)
                    .frame(width: s * 0.37, height: s * 0.37)
            }
            .keyframeAnimator(initialValue: 1.0, trigger: picked) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(1.15, duration: 0.15)
                    SpringKeyframe(1, duration: 0.45, spring: .bouncy)
                }
            }
        }
    }

    private struct Ripple {
        var scale: CGFloat = 1
        var opacity: Double = 0
    }
}

#Preview {
    LogoMark()
        .frame(width: LogoMark.launchSize)
}
