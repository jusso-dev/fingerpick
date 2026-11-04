import SwiftUI

struct RootView: View {
    @State private var model = GameModel()
    @State private var haptics = HapticsDirector(service: NoHaptics())
    @State private var idleTimer = IdleTimerController()
    @AppStorage(Haptics.enabledKey) private var hapticsEnabled = true
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground)
                .ignoresSafeArea()
            RingsView(model: model, diameter: model.layout.ringDiameter)
                .ignoresSafeArea()
            MultitouchSurface(onEvent: { model.handle($0) }, onLayout: { model.updateLayout($0) })
                .ignoresSafeArea()
            GeometryReader { proxy in
                labels(safeArea: proxy.safeAreaInsets)
            }
            .ignoresSafeArea()
        }
        // During a round, edge swipes need a second swipe, and the home indicator and status bar hide.
        .defersSystemGestures(on: model.isRoundActive ? .all : [])
        .persistentSystemOverlays(model.isRoundActive ? .hidden : .automatic)
        .statusBarHidden(model.isRoundActive)
        .onChange(of: hapticsEnabled, initial: true) {
            haptics.service = Haptics.make(enabled: hapticsEnabled)
        }
        .onChange(of: IdleInputs(model: model, scenePhase: scenePhase), initial: true) {
            idleTimer.update(model: model, scenePhase: scenePhase)
        }
        .onAppear {
            model.onEvents = { [haptics, model] events in
                haptics.handle(events, countdownDuration: model.engine.configuration.countdownDuration)
            }
        }
    }
}

extension RootView {
    /// Prompt and result, placed in the play area's reveal rect: the whole screen, or the larger
    /// side of an active fold, so text never crosses it. Coordinates are the touch view's (full
    /// screen, unmirrored), so this container keeps a fixed left-to-right direction for placement
    /// and gives the text back the user's direction.
    @ViewBuilder
    private func labels(safeArea: EdgeInsets) -> some View {
        let layout = model.layout
        let area = layout.revealRect
        let safe = CGRect(
            x: safeArea.leading, y: safeArea.top,
            width: max(0, layout.size.width - safeArea.leading - safeArea.trailing),
            height: max(0, layout.size.height - safeArea.top - safeArea.bottom)
        )
        let region = area.intersection(safe).isNull ? area : area.intersection(safe)
        let top = layout.labelTop(from: region.minY + 24, height: 60)
        ZStack(alignment: .topLeading) {
            PromptView(model: model)
                .environment(\.layoutDirection, layoutDirection)
                .frame(width: region.width)
                .offset(x: region.minX, y: top)
            if let reveal = model.reveal {
                ResultView(reveal: reveal)
                    .id(reveal.startedAt)
                    .environment(\.layoutDirection, layoutDirection)
                    .frame(width: region.width, height: region.height)
                    .offset(x: region.minX, y: region.minY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// Everything the screen-awake decision depends on.
private struct IdleInputs: Equatable {
    let isRoundActive: Bool
    let isShowingResult: Bool
    let lastActivityAt: TimeInterval?
    let scenePhase: ScenePhase

    @MainActor
    init(model: GameModel, scenePhase: ScenePhase) {
        isRoundActive = model.isRoundActive
        isShowingResult = model.reveal != nil
        lastActivityAt = model.lastActivityAt
        self.scenePhase = scenePhase
    }
}

#Preview {
    RootView()
}
