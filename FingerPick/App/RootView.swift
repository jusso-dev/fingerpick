import SwiftUI

struct RootView: View {
    @State private var model = GameModel()

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            MultitouchSurface { model.handle($0) }
                .ignoresSafeArea()
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
