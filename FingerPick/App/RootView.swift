import SwiftUI

struct RootView: View {
    @State private var model = GameModel()

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
        }
        // During a round, edge swipes need a second swipe, and the home indicator and status bar hide.
        .defersSystemGestures(on: model.isRoundActive ? .all : [])
        .persistentSystemOverlays(model.isRoundActive ? .hidden : .automatic)
        .statusBarHidden(model.isRoundActive)
    }
}

#Preview {
    RootView()
}
