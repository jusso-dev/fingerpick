import FingerPickKit
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
    /// Called with fresh geometry on every layout pass and trait change (iPhone Duo fold/unfold).
    var onLayout: ((PlayLayout) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isExclusiveTouch = false
        backgroundColor = .clear
        registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitDisplayScale.self]) { (view: Self, _) in
            view.reportLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        reportLayout()
    }

    /// Sized from this view, never the screen, so it follows the app between displays.
    func reportLayout() {
        onLayout?(PlayLayout(
            size: bounds.size,
            isRegularWidth: traitCollection.horizontalSizeClass == .regular,
            displayScale: traitCollection.displayScale,
            reserved: reservedAreas()
        ))
    }

    /// The fold (division) and camera (occlusion) regions on iOS 27.1+. Inactive regions are
    /// included so layout can plan for them without jumping.
    private func reservedAreas() -> [ReservedArea] {
        guard #available(iOS 27.1, *) else { return [] }
        let divisions = reservedRegions(kind: .division, options: .includeInactive).map {
            ReservedArea(kind: .division, frame: $0.frame, isActive: $0.isActive)
        }
        let occlusions = reservedRegions(kind: .occlusion, options: .includeInactive).map {
            ReservedArea(kind: .occlusion, frame: $0.frame, isActive: $0.isActive)
        }
        return divisions + occlusions
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
    let onLayout: (PlayLayout) -> Void

    func makeUIView(context: Context) -> MultitouchView {
        let view = MultitouchView()
        view.onEvent = onEvent
        view.onLayout = onLayout
        return view
    }

    func updateUIView(_ view: MultitouchView, context: Context) {
        view.onEvent = onEvent
        view.onLayout = onLayout
    }
}
