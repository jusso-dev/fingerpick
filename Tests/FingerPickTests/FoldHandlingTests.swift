import FingerPickKit
import Foundation
import Testing
@testable import FingerPick

/// Folding or unfolding iPhone Duo mid-round (#35), driven through GameModel.
@MainActor
struct FoldHandlingTests {
    private let outer = PlayLayout(size: CGSize(width: 466, height: 678))
    private let inner = PlayLayout(size: CGSize(width: 626, height: 890))

    private func modelInCountdown(clock: ManualClock) -> (GameModel, [NSObject]) {
        let model = GameModel(engine: RoundEngine(picker: FairPicker(generator: SeededGenerator(seed: 3))), clock: clock)
        model.updateLayout(outer)
        let fingers = (0..<3).map { _ in NSObject() }
        for (index, finger) in fingers.enumerated() {
            model.handle(.began(key: ObjectIdentifier(finger), location: CGPoint(x: 100 + index * 100, y: 300)))
        }
        clock.time = 1
        model.tick()
        return (model, fingers)
    }

    @Test func foldMidCountdownNeverProducesAWinner() {
        let clock = ManualClock()
        let (model, fingers) = modelInCountdown(clock: clock)
        #expect(model.engine.isCountingDown)

        clock.time = 2
        model.updateLayout(inner)
        model.handle(.environmentChanged(.folded))
        #expect(model.interruption?.change == .folded)
        #expect(model.touches.isEmpty)
        #expect(model.slots.slots.isEmpty)

        // Late events from the old touches are ignored.
        model.handle(.moved(key: ObjectIdentifier(fingers[0]), location: .zero))
        model.handle(.ended(key: ObjectIdentifier(fingers[1])))
        clock.time = 100
        model.tick()
        #expect(model.reveal == nil)
        #expect(model.engine.result == nil)
    }

    @Test func nextFingerClearsTheFoldMessage() {
        let clock = ManualClock()
        let (model, _) = modelInCountdown(clock: clock)
        model.handle(.environmentChanged(.folded))
        let finger = NSObject()
        model.handle(.began(key: ObjectIdentifier(finger), location: .zero))
        #expect(model.interruption == nil)
    }

    @Test func resultSurvivesAFoldAndIsLaidOutAgain() throws {
        let clock = ManualClock()
        let (model, _) = modelInCountdown(clock: clock)
        clock.time = 4
        model.tick()
        let before = try #require(model.reveal)

        clock.time = 5
        model.handle(.cancelled)
        model.updateLayout(inner)
        model.handle(.environmentChanged(.folded))
        clock.time = 60
        model.tick()

        let after = try #require(model.reveal)
        #expect(after.result == before.result)
        #expect(model.interruption == nil)
        for (id, old) in before.positions {
            let new = try #require(after.positions[id])
            #expect(abs(new.x - old.x * 626 / 466) < 0.001)
            #expect(abs(new.y - old.y * 890 / 678) < 0.001)
        }
    }

    @Test func fiftyFoldCyclesWithoutCrash() {
        let clock = ManualClock()
        let model = GameModel(clock: clock)
        for cycle in 0..<50 {
            clock.time = Double(cycle)
            let finger = NSObject()
            model.handle(.began(key: ObjectIdentifier(finger), location: .zero))
            model.updateLayout(cycle.isMultiple(of: 2) ? inner : outer)
            model.handle(.environmentChanged(.folded))
            #expect(model.touches.isEmpty)
        }
    }

    @Test func idleFoldShowsNoMessage() {
        let model = GameModel(clock: ManualClock())
        model.handle(.environmentChanged(.folded))
        #expect(model.interruption == nil)
    }
}
