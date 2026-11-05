import FingerPickKit
import Observation
import QuartzCore
import SwiftUI

/// Monotonic time source, injectable for tests.
protocol GameClock {
    func now() -> TimeInterval
}

struct MonotonicClock: GameClock {
    func now() -> TimeInterval { CACurrentMediaTime() }
}

/// A ring whose finger has lifted, drawn briefly while it fades out.
struct LiftedRing: Equatable {
    let marker: PlayerMarker
    let position: CGPoint
    let liftedAt: TimeInterval

    static let fadeDuration: TimeInterval = 0.25
}

/// A showing result, with each picked player's marker and last position captured at selection,
/// so it can still be drawn after fingers lift.
struct Reveal: Equatable {
    let result: RoundResult
    let markers: [PlayerID: PlayerMarker]
    let positions: [PlayerID: CGPoint]
    let startedAt: TimeInterval

    /// Winning circle growth and losers' fade. The whole reveal finishes in under a second.
    static let expandDuration: TimeInterval = 0.6
    static let fadeDuration: TimeInterval = 0.3
}

/// Main-actor model that turns raw touches into round state for the views.
@MainActor
@Observable
final class GameModel {
    private(set) var touches = TouchRegistry<ObjectIdentifier>()
    private(set) var engine: RoundEngine
    private(set) var slots = SlotAllocator()
    /// When each current finger landed, for the scale-in animation.
    private(set) var landedAt: [PlayerID: TimeInterval] = [:]
    /// Rings of lifted fingers, kept briefly for the fade-out.
    private(set) var liftedRings: [LiftedRing] = []
    /// When the last countdown was cancelled, for the cancel feedback.
    private(set) var countdownCancelledAt: TimeInterval?
    /// The result being shown, if any.
    private(set) var reveal: Reveal?
    /// When a finger last landed or lifted, for the screen-awake policy.
    private(set) var lastActivityAt: TimeInterval?

    /// Receives every round event (haptics, VoiceOver announcements).
    @ObservationIgnored var onEvents: (([RoundEvent]) -> Void)?
    @ObservationIgnored private let clock: any GameClock
    @ObservationIgnored private var tickTask: Task<Void, Never>?

    init(engine: RoundEngine = RoundEngine(), clock: any GameClock = MonotonicClock()) {
        self.engine = engine
        self.clock = clock
    }

    /// True while any finger is down. Drives system gesture deferral and the home indicator.
    var isRoundActive: Bool { !touches.isEmpty }

    func now() -> TimeInterval { clock.now() }

    func handle(_ event: TouchEvent) {
        let now = clock.now()
        if case .moved = event {} else { lastActivityAt = now }
        switch event {
        case let .began(key, location):
            if let id = touches.begin(key, at: location) {
                apply(engine.fingerDown(id, at: now), at: now)
            }
        case let .moved(key, location):
            touches.move(key, to: location)
        case let .ended(key):
            let positions = touches.positions
            if let id = touches.end(key) {
                apply(engine.fingerUp(id, at: now), at: now, liftedFrom: positions)
            }
        case .cancelled:
            let positions = touches.positions
            touches.removeAll()
            apply(engine.cancelAllFingers(at: now), at: now, liftedFrom: positions)
        }
    }

    /// Advances the engine to the current time. Normally called by the scheduled timer.
    func tick() {
        let now = clock.now()
        apply(engine.tick(at: now), at: now)
    }

    private func apply(_ events: [RoundEvent], at now: TimeInterval, liftedFrom positions: [PlayerID: CGPoint] = [:]) {
        liftedRings.removeAll { now - $0.liftedAt > LiftedRing.fadeDuration }
        for event in events {
            switch event {
            case let .playerJoined(id):
                slots.assign(id)
                landedAt[id] = now
            case let .playerLeft(id):
                if let marker = slots.marker(for: id), let position = positions[id] {
                    liftedRings.append(LiftedRing(marker: marker, position: position, liftedAt: now))
                }
                slots.release(id)
                landedAt[id] = nil
            case .countdownCancelled:
                countdownCancelledAt = now
            case let .selected(result):
                reveal = Reveal(
                    result: result,
                    markers: slots.slots.mapValues(PlayerMarker.init),
                    positions: touches.positions,
                    startedAt: now
                )
                // Next round, the first finger shouldn't land on last round's winning colour.
                slots.deprioritise(colours: result.pickedPlayers.compactMap { slots.marker(for: $0)?.colourIndex })
            case .reset:
                reveal = nil
            default:
                break
            }
        }
        if !events.isEmpty { onEvents?(events) }
        scheduleTick()
    }

    private func scheduleTick() {
        tickTask?.cancel()
        let now = clock.now()
        guard let deadline = engine.nextDeadline(after: now) else { return }
        let delay = max(0, deadline - now)
        tickTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.tick()
        }
    }
}
