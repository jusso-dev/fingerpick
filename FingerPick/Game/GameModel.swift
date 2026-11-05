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

/// Main-actor model that turns raw touches into round state for the views.
@MainActor
@Observable
final class GameModel {
    private(set) var touches = TouchRegistry<ObjectIdentifier>()
    private(set) var engine: RoundEngine

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
        switch event {
        case let .began(key, location):
            if let id = touches.begin(key, at: location) {
                apply(engine.fingerDown(id, at: now))
            }
        case let .moved(key, location):
            touches.move(key, to: location)
        case let .ended(key):
            if let id = touches.end(key) {
                apply(engine.fingerUp(id, at: now))
            }
        case .cancelled:
            touches.removeAll()
            apply(engine.cancelAllFingers(at: now))
        }
    }

    /// Advances the engine to the current time. Normally called by the scheduled timer.
    func tick() {
        apply(engine.tick(at: clock.now()))
    }

    private func apply(_ events: [RoundEvent]) {
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
