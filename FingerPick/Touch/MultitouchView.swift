import SwiftUI
import UIKit

/// A raw touch event from the UIKit tracking view. `key` is the identity of the `UITouch`.
enum TouchEvent {
    case began(key: ObjectIdentifier, location: CGPoint)
    case moved(key: ObjectIdentifier, location: CGPoint)
    case ended(key: ObjectIdentifier)
    /// The system cancelled touches (call, Control Centre, fold). Clear every finger.
    case cancelled
}

/// Tracks every touch independently. SwiftUI gestures can't follow 10+ separate fingers reliably.
/// No software limit is applied: every touch UIKit delivers is forwarded.
final class MultitouchView: UIView {
    var onEvent: ((TouchEvent) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isExclusiveTouch = false
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            onEvent?(.began(key: ObjectIdentifier(touch), location: touch.location(in: self)))
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            onEvent?(.moved(key: ObjectIdentifier(touch), location: touch.location(in: self)))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            onEvent?(.ended(key: ObjectIdentifier(touch)))
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        onEvent?(.cancelled)
    }
}

/// Bridges `MultitouchView` into SwiftUI.
struct MultitouchSurface: UIViewRepresentable {
    let onEvent: (TouchEvent) -> Void

    func makeUIView(context: Context) -> MultitouchView {
        let view = MultitouchView()
        view.onEvent = onEvent
        return view
    }

    func updateUIView(_ view: MultitouchView, context: Context) {
        view.onEvent = onEvent
    }
}
