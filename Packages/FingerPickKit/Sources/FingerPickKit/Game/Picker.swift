/// What a round decides.
public enum PickMode: Hashable, Sendable {
    /// One winner.
    case single
    /// Several winners at once, for example two drivers.
    case winners(Int)
    /// Balanced teams.
    case teams(Int)
    /// A full turn order.
    case order

    public static let winnerRange = 1...9
    public static let teamRange = 2...5

    /// Fewest fingers this mode can pick from: winners need at least one loser, teams at least one
    /// player each.
    public var minimumPlayers: Int {
        switch self {
        case .single, .order: 2
        case let .winners(count): max(2, count + 1)
        case let .teams(count): max(2, count)
        }
    }
}

/// The outcome of a round.
public enum RoundResult: Hashable, Sendable {
    /// Winners, revealed together.
    case winners([PlayerID])
    /// Teams in team-number order; sizes differ by at most one.
    case teams([[PlayerID]])
    /// Turn order, first to last.
    case order([PlayerID])

    /// Players the result is about: winners, or everyone for teams and order.
    public var pickedPlayers: [PlayerID] {
        switch self {
        case let .winners(ids), let .order(ids): ids
        case let .teams(teams): teams.flatMap { $0 }
        }
    }

    /// Players who came out on top: the winners, or whoever goes first. Empty for teams.
    public var leaders: [PlayerID] {
        switch self {
        case let .winners(ids): ids
        case let .order(ids): Array(ids.prefix(1))
        case .teams: []
        }
    }

    /// Zero-based team index for a player in a teams result.
    public func team(of id: PlayerID) -> Int? {
        guard case let .teams(teams) = self else { return nil }
        return teams.firstIndex { $0.contains(id) }
    }

    /// One-based rank for a player in an order result.
    public func rank(of id: PlayerID) -> Int? {
        guard case let .order(ids) = self else { return nil }
        return ids.firstIndex(of: id).map { $0 + 1 }
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
        case let .winners(count):
            return .winners(Array(pool.shuffled(using: &generator).prefix(count)))
        case let .teams(count):
            // Shuffle, then deal round-robin so sizes differ by at most one.
            var teams = [[PlayerID]](repeating: [], count: count)
            for (index, id) in pool.shuffled(using: &generator).enumerated() {
                teams[index % count].append(id)
            }
            return .teams(teams)
        case .order:
            return .order(pool.shuffled(using: &generator))
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
