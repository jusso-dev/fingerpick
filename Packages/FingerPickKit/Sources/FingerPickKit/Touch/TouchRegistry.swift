import CoreGraphics

/// Stable identity for one finger on the screen, valid from touch-down to lift.
public struct PlayerID: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public init(_ rawValue: Int) {
        self.rawValue = rawValue
    }

    public static func < (lhs: PlayerID, rhs: PlayerID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var description: String { "P\(rawValue)" }
}

/// Maps platform touch identities (for example `ObjectIdentifier(UITouch)`) to stable player IDs.
///
/// There is no software limit on the number of touches: every touch the hardware reports gets a
/// player. The hardware maximum is the only cap.
public struct TouchRegistry<Key: Hashable>: Sendable where Key: Sendable {
    private var ids: [Key: PlayerID] = [:]
    private var nextRawID = 0

    /// Current finger positions, in the tracking view's coordinate space.
    public private(set) var positions: [PlayerID: CGPoint] = [:]

    public init() {}

    public var count: Int { ids.count }
    public var isEmpty: Bool { ids.isEmpty }

    /// Player IDs in touch-down order.
    public var players: [PlayerID] { positions.keys.sorted() }

    /// Registers a new touch. Returns `nil` if the key is already tracked.
    @discardableResult
    public mutating func begin(_ key: Key, at point: CGPoint) -> PlayerID? {
        guard ids[key] == nil else { return nil }
        let id = PlayerID(nextRawID)
        nextRawID += 1
        ids[key] = id
        positions[id] = point
        return id
    }

    /// Updates a tracked touch's position. Unknown keys are ignored.
    @discardableResult
    public mutating func move(_ key: Key, to point: CGPoint) -> PlayerID? {
        guard let id = ids[key] else { return nil }
        positions[id] = point
        return id
    }

    /// Removes one touch. Unknown keys are ignored.
    @discardableResult
    public mutating func end(_ key: Key) -> PlayerID? {
        guard let id = ids.removeValue(forKey: key) else { return nil }
        positions[id] = nil
        return id
    }

    /// Clears every touch, for example when the system cancels touches for a call or a fold.
    @discardableResult
    public mutating func removeAll() -> [PlayerID] {
        let removed = players
        ids.removeAll()
        positions.removeAll()
        return removed
    }
}
