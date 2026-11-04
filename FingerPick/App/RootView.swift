import SwiftUI

struct RootView: View {
    @State private var model = GameModel()
    @State private var haptics = HapticsDirector(service: NoHaptics())
    @State private var idleTimer = IdleTimerController()
    @AppStorage(Haptics.enabledKey) private var hapticsEnabled = true
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground)
                .ignoresSafeArea()
            RingsView(model: model, diameter: model.layout.ringDiameter)
                .ignoresSafeArea()
            MultitouchSurface(onEvent: { model.handle($0) }, onLayout: { model.updateLayout($0) })
                .ignoresSafeArea()
            GeometryReader { proxy in
                // Prompt top in full-screen coordinates, pushed below any active occlusion (inner camera).
                let top = proxy.safeAreaInsets.top + 24
                PromptView(model: model)
                    .frame(maxWidth: .infinity)
                    .padding(.top, model.layout.labelTop(from: top, height: 60) - proxy.safeAreaInsets.top)
            }
            if let reveal = model.reveal {
                ResultView(reveal: reveal)
                    .id(reveal.startedAt)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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
