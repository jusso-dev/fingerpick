import Foundation

/// Tunable round timings and rules.
public struct RoundConfiguration: Equatable, Sendable {
    /// Allowed countdown durations, in seconds.
    public static let countdownRange: ClosedRange<TimeInterval> = 1...5

    /// Fewest fingers needed before a countdown can start (never below 2).
    public var minimumPlayers: Int {
        didSet { minimumPlayers = max(2, minimumPlayers) }
    }
    /// How long the fingers must stay unchanged before the countdown starts.
    public var settleDelay: TimeInterval
    /// Length of the visible countdown.
    public var countdownDuration: TimeInterval {
        didSet { countdownDuration = countdownDuration.clamped(to: Self.countdownRange) }
    }
    /// Pause after the last finger lifts before returning to waiting.
    public var resetDelay: TimeInterval
    public var mode: PickMode

    public init(
        minimumPlayers: Int = 2,
        settleDelay: TimeInterval = 1,
        countdownDuration: TimeInterval = 3,
        resetDelay: TimeInterval = 0.5,
        mode: PickMode = .single
    ) {
        self.minimumPlayers = max(2, minimumPlayers)
        self.settleDelay = settleDelay
        self.countdownDuration = countdownDuration.clamped(to: Self.countdownRange)
        self.resetDelay = resetDelay
        self.mode = mode
    }

    /// Fingers needed for both the minimum setting and the current mode.
    public var requiredPlayers: Int { max(minimumPlayers, mode.minimumPlayers) }
}

/// Where the round is. See docs/design.md.
public enum RoundPhase: Equatable, Sendable {
    /// Too few fingers, or none.
    case waiting
    /// Enough fingers; waiting for them to stay unchanged for `settleDelay`.
    case stabilising(since: TimeInterval)
    /// Counting down to the pick.
    case countdown(startedAt: TimeInterval)
    /// A result is showing.
    case selected(RoundResult)
}

/// Side effects for the UI, haptics and VoiceOver.
public enum RoundEvent: Equatable, Sendable {
    case playerJoined(PlayerID)
    case playerLeft(PlayerID)
    case countdownStarted
    /// Whole seconds left, emitted once per second including at the start.
    case countdownTick(secondsRemaining: Int)
    case countdownCancelled
    case selected(RoundResult)
    /// Back to waiting after a result.
    case reset
    /// The phone folded, unfolded or moved display mid-round; fingers must go back down.
    case interrupted
}

/// Pure round state machine. Time is passed in by the caller, so tests control the clock.
public struct RoundEngine {
    public private(set) var configuration: RoundConfiguration
    public private(set) var phase: RoundPhase = .waiting
    /// Fingers currently down.
    public private(set) var players: Set<PlayerID> = []
    /// When a showing result returns to waiting (set once every finger has lifted).
    public private(set) var resetDeadline: TimeInterval?
    /// True when a result was kept across a fold. It stays until dismissed or a new finger lands.
    public private(set) var isResultPinned = false

    private var picker: any Picker
    private var lastTickSecond: Int?
    /// When the system last cancelled touches during a round, to recognise a fold that follows.
    private var lastRoundCancelAt: TimeInterval?

    public init(configuration: RoundConfiguration = RoundConfiguration(), picker: any Picker = FairPicker()) {
        self.configuration = configuration
        self.picker = picker
    }

    public var result: RoundResult? {
        if case let .selected(result) = phase { result } else { nil }
    }

    public var isCountingDown: Bool {
        if case .countdown = phase { true } else { false }
    }

    // MARK: Events

    public mutating func fingerDown(_ id: PlayerID, at now: TimeInterval) -> [RoundEvent] {
        var events: [RoundEvent] = []
        if result != nil {
            guard players.isEmpty else {
                // A result is showing and fingers are still down: count the finger, keep the result.
                players.insert(id)
                resetDeadline = nil
                return [.playerJoined(id)]
            }
            // Every finger had lifted: the new finger starts the next round.
            events += reset()
        }
        players.insert(id)
        events.append(.playerJoined(id))
        events += rosterChanged(at: now)
        return events
    }

    public mutating func fingerUp(_ id: PlayerID, at now: TimeInterval) -> [RoundEvent] {
        guard players.remove(id) != nil else { return [] }
        var events: [RoundEvent] = [.playerLeft(id)]
        if result != nil {
            if players.isEmpty, !isResultPinned {
                resetDeadline = now + configuration.resetDelay
            }
        } else {
            events += rosterChanged(at: now)
        }
        return events
    }

    /// The system cancelled every touch (call, Control Centre, fold).
    public mutating func cancelAllFingers(at now: TimeInterval) -> [RoundEvent] {
        guard !players.isEmpty else { return [] }
        let left = players.sorted().map(RoundEvent.playerLeft)
        players.removeAll()
        if result != nil {
            if !isResultPinned { resetDeadline = now + configuration.resetDelay }
            return left
        }
        lastRoundCancelAt = now
        let wasCountingDown = isCountingDown
        phase = .waiting
        lastTickSecond = nil
        return left + (wasCountingDown ? [.countdownCancelled] : [])
    }

    /// The display size, display or hinge changed. Never pick from fingers that were down before it.
    public mutating func environmentChanged(at now: TimeInterval) -> [RoundEvent] {
        if result != nil {
            // Keep the result and let the UI lay it out again on the new display.
            players.removeAll()
            resetDeadline = nil
            isResultPinned = true
            return []
        }
        let recentlyCancelled = lastRoundCancelAt.map { now - $0 <= 1 } ?? false
        guard !players.isEmpty || recentlyCancelled else { return [] }
        players.removeAll()
        phase = .waiting
        lastTickSecond = nil
        lastRoundCancelAt = nil
        return [.interrupted]
    }

    /// Advances time. Call at or after `nextDeadline(after:)`.
    public mutating func tick(at now: TimeInterval) -> [RoundEvent] {
        var events: [RoundEvent] = []
        if case let .stabilising(since) = phase, now >= since + configuration.settleDelay {
            phase = .countdown(startedAt: since + configuration.settleDelay)
            lastTickSecond = nil
            events.append(.countdownStarted)
        }
        if case let .countdown(start) = phase {
            let remaining = configuration.countdownDuration - (now - start)
            if remaining <= 0 {
                let result = picker.pick(from: Array(players), mode: configuration.mode)
                phase = .selected(result)
                resetDeadline = nil
                isResultPinned = false
                lastTickSecond = nil
                events.append(.selected(result))
            } else {
                let second = Int(remaining.rounded(.up))
                if second != lastTickSecond {
                    lastTickSecond = second
                    events.append(.countdownTick(secondsRemaining: second))
                }
            }
        }
        if result != nil, let deadline = resetDeadline, now >= deadline {
            events += reset()
        }
        return events
    }

    /// Tap to dismiss a result once every finger has lifted.
    public mutating func dismissResult(at now: TimeInterval) -> [RoundEvent] {
        guard result != nil, players.isEmpty else { return [] }
        return reset()
    }

    public mutating func updateConfiguration(_ configuration: RoundConfiguration, at now: TimeInterval) -> [RoundEvent] {
        self.configuration = configuration
        guard result == nil else { return [] }
        return rosterChanged(at: now)
    }

    // MARK: Timing queries

    /// The next time `tick(at:)` must run, or `nil` if nothing is scheduled.
    public func nextDeadline(after now: TimeInterval) -> TimeInterval? {
        switch phase {
        case .waiting:
            return nil
        case let .stabilising(since):
            return since + configuration.settleDelay
        case let .countdown(start):
            let end = start + configuration.countdownDuration
            let remaining = end - now
            guard remaining > 0 else { return now }
            // Next whole-second boundary before the end, or the end itself.
            return end - (remaining.rounded(.up) - 1)
        case .selected:
            return resetDeadline
        }
    }

    /// Countdown progress from 0 to 1, or `nil` outside the countdown.
    public func countdownProgress(at now: TimeInterval) -> Double? {
        guard case let .countdown(start) = phase else { return nil }
        return ((now - start) / configuration.countdownDuration).clamped(to: 0...1)
    }

    // MARK: Private

    private mutating func rosterChanged(at now: TimeInterval) -> [RoundEvent] {
        let wasCountingDown = isCountingDown
        phase = players.count >= configuration.requiredPlayers ? .stabilising(since: now) : .waiting
        lastTickSecond = nil
        return wasCountingDown ? [.countdownCancelled] : []
    }

    private mutating func reset() -> [RoundEvent] {
        phase = .waiting
        resetDeadline = nil
        isResultPinned = false
        lastTickSecond = nil
        return [.reset]
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
