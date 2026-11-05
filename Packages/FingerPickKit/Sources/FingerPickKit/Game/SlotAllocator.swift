/// How a player is drawn: colour, shape marker and number. Derived from an unbounded slot index.
public struct PlayerMarker: Hashable, Sendable {
    /// Colours and shapes in the palette.
    public static let paletteSize = 10

    public let slot: Int

    public init(slot: Int) {
        self.slot = slot
    }

    public var colourIndex: Int { slot % Self.paletteSize }

    /// Shifts by one for every lap of the palette, so colour and shape together stay unique for
    /// the first 100 players. The number is always unique.
    public var shapeIndex: Int { (slot + slot / Self.paletteSize) % Self.paletteSize }

    /// One-based number shown with the ring.
    public var number: Int { slot + 1 }
}

/// Gives each finger a slot. No colour repeats until the palette is used up; after that, slots keep
/// counting up (colours cycle, numbers stay unique), so any number of fingers is supported.
public struct SlotAllocator: Sendable {
    public private(set) var slots: [PlayerID: Int] = [:]
    /// Preference order for the first `paletteSize` slots.
    private var preference: [Int] = Array(0..<PlayerMarker.paletteSize)

    public init() {}

    public func marker(for id: PlayerID) -> PlayerMarker? {
        slots[id].map(PlayerMarker.init)
    }

    @discardableResult
    public mutating func assign(_ id: PlayerID) -> PlayerMarker {
        if let slot = slots[id] { return PlayerMarker(slot: slot) }
        let used = Set(slots.values)
        let slot = preference.first { !used.contains($0) }
            ?? (PlayerMarker.paletteSize...).first { !used.contains($0) }!
        slots[id] = slot
        return PlayerMarker(slot: slot)
    }

    public mutating func release(_ id: PlayerID) {
        slots[id] = nil
    }

    public mutating func releaseAll() {
        slots.removeAll()
    }

    /// Moves these colours to the back of the queue, for example last round's winner, so the
    /// first finger next round doesn't get the same colour again.
    public mutating func deprioritise(colours: [Int]) {
        let moved = colours.filter { (0..<PlayerMarker.paletteSize).contains($0) }
        preference.removeAll { moved.contains($0) }
        preference += moved
    }
}
