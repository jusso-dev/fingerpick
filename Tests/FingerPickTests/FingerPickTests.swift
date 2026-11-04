import Foundation
import Testing
@testable import FingerPick

@MainActor
struct GameModelTouchTests {
    @Test func cancelledTouchesClearTheRound() {
        let model = GameModel()
        let fingers = (0..<10).map { _ in NSObject() }
        for finger in fingers {
            model.handle(.began(key: ObjectIdentifier(finger), location: .zero))
        }
        #expect(model.touches.count == 10)
        #expect(model.isRoundActive)

        model.handle(.cancelled)
        #expect(model.touches.isEmpty)
        #expect(!model.isRoundActive)
    }

    @Test func liftingOneFingerKeepsTheOthers() {
        let model = GameModel()
        let a = NSObject(), b = NSObject()
        model.handle(.began(key: ObjectIdentifier(a), location: .zero))
        model.handle(.began(key: ObjectIdentifier(b), location: .zero))
        model.handle(.ended(key: ObjectIdentifier(a)))
        #expect(model.touches.count == 1)
    }
}
