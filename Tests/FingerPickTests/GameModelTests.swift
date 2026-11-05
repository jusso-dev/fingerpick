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
}
