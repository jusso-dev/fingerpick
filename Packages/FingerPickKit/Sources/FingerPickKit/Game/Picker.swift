/// What a round decides.
public enum PickMode: Hashable, Sendable {
    /// One winner.
    case single

    /// Fewest fingers this mode can pick from.
    public var minimumPlayers: Int {
        switch self {
        case .single: 2
        }
    }
}

/// The outcome of a round.
public enum RoundResult: Hashable, Sendable {
    /// Winners in reveal order.
    case winners([PlayerID])

    /// Every player who was picked for something (winner, team member, ranked).
    public var pickedPlayers: [PlayerID] {
        switch self {
        case let .winners(ids): ids
        }
    }
}

/// Chooses a result from the players currently down.
public protocol Picker {
    mutating func pick(from players: [PlayerID], mode: PickMode) -> RoundResult
}

/// Uniform random choice. Production uses `SystemRandomNumberGenerator` (a CSPRNG);
/// tests inject a seeded generator.
public struct FairPicker<Generator: RandomNumberGenerator>: Picker {
    public var generator: Generator

    public init(generator: Generator) {
        self.generator = generator
    }

    public mutating func pick(from players: [PlayerID], mode: PickMode) -> RoundResult {
        precondition(players.count >= mode.minimumPlayers, "Not enough players for \(mode)")
        // Sort first so the result never depends on touch order, only on the generator.
        let pool = players.sorted()
        switch mode {
        case .single:
            return .winners([pool.randomElement(using: &generator)!])
        }
    }
}

extension FairPicker where Generator == SystemRandomNumberGenerator {
    public init() {
        self.init(generator: SystemRandomNumberGenerator())
    }
}

/// Deterministic SplitMix64 generator for tests and UI-test hooks. Not for production picks.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
