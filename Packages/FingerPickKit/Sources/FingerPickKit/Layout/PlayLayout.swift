import CoreGraphics

/// A platform reserved region (iOS 27.1 `reservedRegions`), copied into a plain value so layout
/// can be unit-tested with fake regions.
public struct ReservedArea: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// The fold on iPhone Duo. Active only when partially open.
        case division
        /// Hardware that covers content, such as the inner under-display camera while in use.
        case occlusion
    }

    public var kind: Kind
    /// In the play view's coordinate space, margins included.
    public var frame: CGRect
    public var isActive: Bool

    public init(kind: Kind, frame: CGRect, isActive: Bool) {
        self.kind = kind
        self.frame = frame
        self.isActive = isActive
    }
}

/// Play-area geometry, derived only from the view's own size and regions — never the device model
/// or `UIScreen.main`. Recomputed on every size change, so it follows iPhone Duo between displays.
public struct PlayLayout: Equatable, Sendable {
    public enum Canvas: Equatable, Sendable {
        /// Standard iPhones and the iPhone Duo outer (cover) display.
        case compact
        /// Large canvases such as the iPhone Duo inner display.
        case large
    }

    /// Shortest side, in points, from which the canvas counts as large. Every current single-screen
    /// iPhone and the Duo outer display are below this; the Duo inner display is above it.
    public static let largeCanvasMinimumSide: CGFloat = 500
    public static let minimumRingDiameter: CGFloat = 88
    public static let maximumRingDiameter: CGFloat = 150

    public let size: CGSize
    public let canvas: Canvas
    public let ringDiameter: CGFloat
    public let reserved: [ReservedArea]

    public init(size: CGSize, isRegularWidth: Bool = false, displayScale: CGFloat = 3, reserved: [ReservedArea] = []) {
        self.size = size
        self.reserved = reserved
        let shortSide = min(size.width, size.height)
        canvas = isRegularWidth || shortSide >= Self.largeCanvasMinimumSide ? .large : .compact
        let raw = (shortSide * 0.2).clamped(to: Self.minimumRingDiameter...Self.maximumRingDiameter)
        let scale = max(1, displayScale)
        ringDiameter = (raw * scale).rounded() / scale
    }

    /// Players the prompt suggests: a compact screen gets crowded beyond six fingers.
    public var suggestedPlayers: Int {
        switch canvas {
        case .compact: 6
        case .large: 10
        }
    }

    public var bounds: CGRect { CGRect(origin: .zero, size: size) }

    public var activeOcclusions: [CGRect] {
        reserved.filter { $0.kind == .occlusion && $0.isActive }.map(\.frame)
    }

    /// Pushes a top-anchored label down so it starts below any occlusion (for example the inner
    /// camera) that overlaps it. `top` is the label's top edge in this view's coordinates.
    public func labelTop(from top: CGFloat, height: CGFloat) -> CGFloat {
        let band = CGRect(x: 0, y: top, width: size.width, height: height)
        let blocking = activeOcclusions.filter { $0.intersects(band) }.map(\.maxY).max()
        return max(top, blocking.map { $0 + 8 } ?? top)
    }

    public enum Corner: CaseIterable, Sendable {
        case topTrailing, topLeading, bottomTrailing, bottomLeading
    }

    /// First corner whose control rect, inset from `safeFrame`, misses every occlusion.
    public func controlCorner(controlSize: CGSize, safeFrame: CGRect, inset: CGFloat = 16) -> Corner {
        Corner.allCases.first { corner in
            let rect = controlRect(corner, controlSize: controlSize, safeFrame: safeFrame, inset: inset)
            return !activeOcclusions.contains { $0.intersects(rect) }
        } ?? .topTrailing
    }

    public func controlRect(_ corner: Corner, controlSize: CGSize, safeFrame: CGRect, inset: CGFloat = 16) -> CGRect {
        let x = switch corner {
        case .topTrailing, .bottomTrailing: safeFrame.maxX - inset - controlSize.width
        case .topLeading, .bottomLeading: safeFrame.minX + inset
        }
        let y = switch corner {
        case .topTrailing, .topLeading: safeFrame.minY + inset
        case .bottomTrailing, .bottomLeading: safeFrame.maxY - inset - controlSize.height
        }
        return CGRect(origin: CGPoint(x: x, y: y), size: controlSize)
    }
}
