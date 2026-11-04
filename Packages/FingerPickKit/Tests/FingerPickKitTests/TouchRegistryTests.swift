import CoreGraphics
import Testing
@testable import FingerPickKit

struct TouchRegistryTests {
    @Test func tracksTouchesIndependently() {
        var registry = TouchRegistry<Int>()
        let a = registry.begin(1, at: CGPoint(x: 10, y: 10))
        let b = registry.begin(2, at: CGPoint(x: 20, y: 20))
        #expect(a != nil && b != nil && a != b)
        #expect(registry.count == 2)

        registry.move(1, to: CGPoint(x: 15, y: 15))
        #expect(registry.positions[a!] == CGPoint(x: 15, y: 15))
        #expect(registry.positions[b!] == CGPoint(x: 20, y: 20))
    }

    @Test func liftingOneFingerRemovesOnlyThatFinger() {
        var registry = TouchRegistry<Int>()
        let a = registry.begin(1, at: .zero)!
        let b = registry.begin(2, at: .zero)!
        #expect(registry.end(1) == a)
        #expect(registry.players == [b])
    }

    @Test func duplicateAndUnknownKeysAreIgnored() {
        var registry = TouchRegistry<Int>()
        _ = registry.begin(1, at: .zero)
        #expect(registry.begin(1, at: .zero) == nil)
        #expect(registry.move(9, to: .zero) == nil)
        #expect(registry.end(9) == nil)
        #expect(registry.count == 1)
    }

    @Test func cancelClearsEverything() {
        var registry = TouchRegistry<Int>()
        for key in 0..<5 { _ = registry.begin(key, at: .zero) }
        #expect(registry.removeAll().count == 5)
        #expect(registry.isEmpty)
    }

    @Test func idsAreNeverReused() {
        var registry = TouchRegistry<Int>()
        let first = registry.begin(1, at: .zero)!
        registry.end(1)
        let second = registry.begin(1, at: .zero)!
        #expect(first != second)
    }

    /// No software cap: the registry accepts as many touches as the hardware delivers.
    @Test(arguments: [2, 5, 10, 11, 20, 100, 1_000])
    func supportsAnyNumberOfTouches(count: Int) {
        var registry = TouchRegistry<Int>()
        for key in 0..<count { _ = registry.begin(key, at: CGPoint(x: key, y: key)) }
        #expect(registry.count == count)
        #expect(Set(registry.players).count == count)
    }
}
