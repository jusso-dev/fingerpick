import FingerPickKit
import Foundation
import Testing
@testable import FingerPick

/// Clock the test moves by hand.
final class ManualClock: GameClock {
    var time: TimeInterval = 0
    func now() -> TimeInterval { time }
}

@MainActor
struct GameModelTests {
    private func makeModel(clock: ManualClock = ManualClock()) -> GameModel {
        GameModel(engine: RoundEngine(picker: FairPicker(generator: SeededGenerator(seed: 1))), clock: clock)
    }

    @Test func cancelledTouchesClearTheRound() {
        let model = makeModel()
        let fingers = (0..<10).map { _ in NSObject() }
        for finger in fingers {
            model.handle(.began(key: ObjectIdentifier(finger), location: .zero))
        }
        #expect(model.touches.count == 10)
        #expect(model.engine.players.count == 10)
        #expect(model.isRoundActive)

        model.handle(.cancelled)
        #expect(model.touches.isEmpty)
        #expect(model.engine.players.isEmpty)
        #expect(!model.isRoundActive)
    }

    @Test func liftingOneFingerKeepsTheOthers() {
        let model = makeModel()
        let a = NSObject(), b = NSObject()
        model.handle(.began(key: ObjectIdentifier(a), location: .zero))
        model.handle(.began(key: ObjectIdentifier(b), location: .zero))
        model.handle(.ended(key: ObjectIdentifier(a)))
        #expect(model.touches.count == 1)
        #expect(model.engine.players.count == 1)
    }

    @Test func fullRoundSelectsAWinnerFromTheFingersDown() {
        let clock = ManualClock()
        let model = makeModel(clock: clock)
        var received: [RoundEvent] = []
        model.onEvents = { received += $0 }
        let fingers = (0..<3).map { _ in NSObject() }
        for finger in fingers {
            model.handle(.began(key: ObjectIdentifier(finger), location: .zero))
        }
        clock.time = 1
        model.tick()
        clock.time = 4
        model.tick()
        let winner = try? #require(model.engine.result?.pickedPlayers.first)
        #expect(winner.map { model.touches.players.contains($0) } == true)
        #expect(received.contains(.countdownStarted))
    }

    @Test func revealKeepsWinnerAfterFingersLiftAndClearsOnReset() {
        let clock = ManualClock()
        let model = makeModel(clock: clock)
        let fingers = (0..<2).map { _ in NSObject() }
        for finger in fingers { model.handle(.began(key: ObjectIdentifier(finger), location: .zero)) }
        clock.time = 1; model.tick()
        clock.time = 4; model.tick()
        #expect(model.reveal?.markers.count == 2)

        clock.time = 5
        for finger in fingers { model.handle(.ended(key: ObjectIdentifier(finger))) }
        #expect(model.reveal != nil)
        clock.time = 5.5; model.tick()
        #expect(model.reveal == nil)
    }

    @Test func tenRoundsInARowLeaveNoStaleRings() {
        let clock = ManualClock()
        let model = makeModel(clock: clock)
        var lastWinnerColour: Int?
        for round in 0..<10 {
            let base = Double(round) * 10
            let fingers = (0..<3).map { _ in NSObject() }
            clock.time = base
            for finger in fingers { model.handle(.began(key: ObjectIdentifier(finger), location: .zero)) }
            if let lastWinnerColour {
                // The first finger of the next round doesn't get last round's winning colour.
                #expect(model.slots.slots.values.min() != lastWinnerColour)
            }
            clock.time = base + 1; model.tick()
            clock.time = base + 4; model.tick()
            let winner = model.engine.result?.pickedPlayers.first
            lastWinnerColour = winner.flatMap { model.reveal?.markers[$0]?.colourIndex }
            clock.time = base + 5
            for finger in fingers { model.handle(.ended(key: ObjectIdentifier(finger))) }
            clock.time = base + 6; model.tick()
            #expect(model.reveal == nil)
            #expect(model.touches.isEmpty)
            #expect(model.slots.slots.isEmpty)
            #expect(model.landedAt.isEmpty)
        }
    }
}
