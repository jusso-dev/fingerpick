#if DEBUG
import FingerPickKit
import SwiftUI

/// Launch-argument hooks for UI tests (#23). XCUITest can't put ten fingers down, so `-uitest`
/// adds a small injector that feeds fake touches through the real model. Debug builds only.
enum UITestHooks {
    static var isEnabled: Bool { arguments.contains("-uitest") }

    /// `-uitest-reset` clears saved settings before launch.
    static func prepare() {
        guard isEnabled, arguments.contains("-uitest-reset"), let id = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: id)
    }

    /// `-uitest-seed <n>` makes picks deterministic.
    static var seed: UInt64? {
        guard isEnabled, let index = arguments.firstIndex(of: "-uitest-seed"), index + 1 < arguments.count else { return nil }
        return UInt64(arguments[index + 1])
    }

    /// `-uitest-dark` / `-uitest-light` force an appearance for screenshot runs.
    static var colorScheme: ColorScheme? {
        guard isEnabled else { return nil }
        if arguments.contains("-uitest-dark") { return .dark }
        if arguments.contains("-uitest-light") { return .light }
        return nil
    }

    private static var arguments: [String] { ProcessInfo.processInfo.arguments }
}

/// Buttons that add and lift fake fingers.
struct TestTouchInjector: View {
    let model: GameModel
    @State private var fingers: [NSObject] = []

    var body: some View {
        HStack {
            Button {
                let finger = NSObject()
                let index = fingers.count
                fingers.append(finger)
                let point = CGPoint(x: 80 + CGFloat(index % 3) * 110, y: 260 + CGFloat(index / 3) * 160)
                model.handle(.began(key: ObjectIdentifier(finger), location: point))
            } label: {
                Text(verbatim: "Add finger")
            }
            .accessibilityIdentifier("uitest.addFinger")
            Button {
                for finger in fingers {
                    model.handle(.ended(key: ObjectIdentifier(finger)))
                }
                fingers.removeAll()
            } label: {
                Text(verbatim: "Lift all")
            }
            .accessibilityIdentifier("uitest.liftAll")
        }
        .font(.caption)
        .buttonStyle(.bordered)
        .padding()
    }
}
#endif
