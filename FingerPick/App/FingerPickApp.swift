import SwiftUI

@main
struct FingerPickApp: App {
    init() {
        #if DEBUG
        UITestHooks.prepare()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
