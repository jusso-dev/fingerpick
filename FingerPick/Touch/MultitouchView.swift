import FingerPickKit
import os
import SwiftUI
import UIKit

/// Why the play area changed under the players' fingers.
enum EnvironmentChange: Equatable {
    /// Folded, unfolded, moved display or hinge posture changed (iPhone Duo).
    case folded
    /// Rotated: the size swapped width and height.
    case rotated
}

/// A raw touch event from the UIKit tracking view. `key` is the identity of the `UITouch`.
enum TouchEvent {
    case began(key: ObjectIdentifier, location: CGPoint)
    case moved(key: ObjectIdentifier, location: CGPoint)
    case ended(key: ObjectIdentifier)
    /// The system cancelled touches (call, Control Centre, fold). Clear every finger.
    case cancelled
    /// The view's size or the hinge changed. Any round in progress must start again.
    case environmentChanged(EnvironmentChange)
}

/// Tracks every touch independently. SwiftUI gestures can't follow 10+ separate fingers reliably.
/// No software limit is applied: every touch UIKit delivers is forwarded.
final class MultitouchView: UIView {
    var onEvent: ((TouchEvent) -> Void)?
    /// Called with fresh geometry on every layout pass and trait change (iPhone Duo fold/unfold).
    var onLayout: ((PlayLayout) -> Void)?

    private var lastSize: CGSize = .zero
    private var activeTouches: Set<ObjectIdentifier> = []
    private let survival = TouchSurvivalLog()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isExclusiveTouch = false
        backgroundColor = .clear
        registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitDisplayScale.self]) { (view: Self, _) in
            view.reportLayout()
        }
        installHingeInteraction()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        reportLayout()
        let size = bounds.size
        defer { lastSize = size }
        guard lastSize != .zero, size != lastSize else { return }
        let rotated = size.width == lastSize.height && size.height == lastSize.width
        environmentChanged(rotated ? .rotated : .folded)
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

    /// Hinge status changes (closed, partially open, fully open) cancel a round and refresh the
    /// fold regions. Apple advises using the hinge for effects, not layout, so the angle is ignored.
    private func installHingeInteraction() {
        guard #available(iOS 27.1, *) else { return }
        var lastStatus: UIHinge.Status?
        addInteraction(UIHingeInteraction { [weak self] _, update in
            let status = update.hinge?.status
            defer { lastStatus = status }
            guard let self, let lastStatus, status != lastStatus else { return }
            self.reportLayout()
            self.environmentChanged(.folded)
        })
    }

    private func environmentChanged(_ change: EnvironmentChange) {
        survival.environmentChanged(activeTouches: activeTouches)
        onEvent?(.environmentChanged(change))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            activeTouches.insert(ObjectIdentifier(touch))
            onEvent?(.began(key: ObjectIdentifier(touch), location: touch.location(in: self)))
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            survival.touchSeen(ObjectIdentifier(touch), outcome: "moved")
            onEvent?(.moved(key: ObjectIdentifier(touch), location: touch.location(in: self)))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            activeTouches.remove(ObjectIdentifier(touch))
            survival.touchSeen(ObjectIdentifier(touch), outcome: "ended")
            onEvent?(.ended(key: ObjectIdentifier(touch)))
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            activeTouches.remove(ObjectIdentifier(touch))
            survival.touchSeen(ObjectIdentifier(touch), outcome: "cancelled")
        }
        onEvent?(.cancelled)
    }
}

/// Debug-only log of whether touches that were down during a fold keep delivering events
/// afterwards. Apple hasn't confirmed this, so it's measured on device (#35).
private final class TouchSurvivalLog {
    #if DEBUG
    private let logger = Logger(subsystem: "dev.jusso.fingerpick", category: "fold")
    private var touchesAtChange: Set<ObjectIdentifier> = []
    #endif

    func environmentChanged(activeTouches: Set<ObjectIdentifier>) {
        #if DEBUG
        touchesAtChange = activeTouches
        logger.debug("Environment changed with \(activeTouches.count) touches down")
        #endif
    }

    func touchSeen(_ key: ObjectIdentifier, outcome: String) {
        #if DEBUG
        guard touchesAtChange.remove(key) != nil else { return }
        logger.debug("Touch from before the change was \(outcome, privacy: .public) afterwards")
        #endif
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
