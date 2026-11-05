import SwiftUI

struct RootView: View {
    @State private var model = GameModel()
    @State private var haptics = HapticsDirector(service: NoHaptics())
    @AppStorage(Haptics.enabledKey) private var hapticsEnabled = true

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground)
                .ignoresSafeArea()
            RingsView(model: model)
                .ignoresSafeArea()
            MultitouchSurface { model.handle($0) }
                .ignoresSafeArea()
            PromptView(model: model)
                .padding(.top, 24)
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
        .onAppear {
            model.onEvents = { [haptics, model] events in
                haptics.handle(events, countdownDuration: model.engine.configuration.countdownDuration)
            }
        }
    }
}

#Preview {
    RootView()
}
