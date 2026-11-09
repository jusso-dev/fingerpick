import SwiftUI

/// A short intro after launch, about 1.2 s. It starts on the launch screen's exact frame (the
/// winner's mark on the launch background), then the players' rings spring in, the winner is
/// picked and the name appears before it fades into the play area.
///
/// It never holds up play: it takes no touches, so the first finger goes straight to the play
/// area and dismisses it. Reduce Motion turns it into a short cross-fade.
struct SplashView: View {
    let finished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false
    @State private var picked = false
    @State private var showsName = false
    @State private var leaving = false

    /// Off for UI test runs, so screenshots and taps never wait on it.
    static var showsOnLaunch: Bool {
        #if DEBUG
        !UITestHooks.isEnabled
        #else
        true
        #endif
    }

    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .opacity(leaving ? 0 : 1)
            LogoMark(landed: landed, picked: picked)
                .frame(width: LogoMark.launchSize, height: LogoMark.launchSize)
                .overlay(alignment: .bottom) {
                    Text(verbatim: "FingerPick")
                        .font(.largeTitle.weight(.bold))
                        .fixedSize()
                        .alignmentGuide(.bottom) { $0[.top] }
                        .offset(y: showsName || reduceMotion ? 0 : 12)
                        .opacity(showsName ? 1 : 0)
                }
                .scaleEffect(leaving && !reduceMotion ? 1.3 : 1)
                .opacity(leaving ? 0 : 1)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task { await play() }
    }

    private struct Step {
        let delay: Duration
        var animation: Animation?
        let change: () -> Void
    }

    private func play() async {
        let steps: [Step] = reduceMotion
            ? [
                Step(delay: .milliseconds(50), change: { landed = true }),
                Step(delay: .milliseconds(150), animation: .easeOut(duration: 0.25), change: { showsName = true }),
                Step(delay: .milliseconds(450), animation: .easeIn(duration: 0.25), change: { leaving = true }),
                Step(delay: .milliseconds(250), change: finished),
            ]
            : [
                Step(delay: .milliseconds(50), change: { landed = true }),
                Step(delay: .milliseconds(400), change: { picked = true }),
                Step(delay: .milliseconds(50), animation: .smooth(duration: 0.35), change: { showsName = true }),
                Step(delay: .milliseconds(500), animation: .easeIn(duration: 0.3), change: { leaving = true }),
                Step(delay: .milliseconds(300), change: finished),
            ]
        for step in steps {
            try? await Task.sleep(for: step.delay)
            guard !Task.isCancelled else { return }
            withAnimation(step.animation) { step.change() }
        }
    }
}

#Preview {
    SplashView {}
}
