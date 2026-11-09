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

    /// `-uitest-fingers <n>` puts n fake fingers down at launch, with the injector buttons hidden,
    /// so App Store screenshots show no debug controls.
    static var launchFingers: Int? {
        guard isEnabled, let index = arguments.firstIndex(of: "-uitest-fingers"), index + 1 < arguments.count else { return nil }
        return Int(arguments[index + 1])
    }

    private static var arguments: [String] { ProcessInfo.processInfo.arguments }
}

/// Buttons that add and lift fake fingers.
struct TestTouchInjector: View {
    let model: GameModel
    @State private var fingers: [NSObject] = []

    var body: some View {
        if let count = UITestHooks.launchFingers {
            Color.clear
                .frame(width: 1, height: 1)
                .task { for _ in 0..<count { addFinger() } }
        } else {
            buttons
        }
    }

    private func addFinger() {
        let finger = NSObject()
        let index = fingers.count
        fingers.append(finger)
        let point = CGPoint(x: 80 + CGFloat(index % 3) * 110, y: 260 + CGFloat(index / 3) * 160)
        model.handle(.began(key: ObjectIdentifier(finger), location: point))
    }

    private var buttons: some View {
        HStack {
            Button {
                addFinger()
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
