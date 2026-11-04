import Testing
@testable import FingerPickKit

struct SlotAllocatorTests {
    @Test func coloursAreUniqueForTenFingers() {
        var allocator = SlotAllocator()
        let markers = (0..<10).map { allocator.assign(PlayerID($0)) }
        #expect(Set(markers.map(\.colourIndex)).count == 10)
        #expect(Set(markers.map(\.shapeIndex)).count == 10)
    }

    @Test func freedColourIsReusedBeforeCycling() {
        var allocator = SlotAllocator()
        for id in 0..<3 { allocator.assign(PlayerID(id)) }
        allocator.release(PlayerID(1))
        #expect(allocator.assign(PlayerID(7)).slot == 1)
    }

    @Test func assigningTwiceKeepsTheSameSlot() {
        var allocator = SlotAllocator()
        let first = allocator.assign(PlayerID(0))
        #expect(allocator.assign(PlayerID(0)) == first)
        #expect(allocator.marker(for: PlayerID(0)) == first)
        #expect(allocator.marker(for: PlayerID(5)) == nil)
    }

    /// Unlimited fingers: numbers stay unique and colour + shape stay unique for 100 players.
    @Test func supportsMoreFingersThanThePalette() {
        var allocator = SlotAllocator()
        let markers = (0..<100).map { allocator.assign(PlayerID($0)) }
        #expect(Set(markers.map(\.number)).count == 100)
        #expect(Set(markers.map { [$0.colourIndex, $0.shapeIndex] }).count == 100)
        #expect(markers.allSatisfy { (0..<PlayerMarker.paletteSize).contains($0.colourIndex) })

        let many = (100..<1_100).map { allocator.assign(PlayerID($0)) }
        #expect(Set(many.map(\.number)).count == 1_000)
    }

    @Test func deprioritisedColourGoesLast() {
        var allocator = SlotAllocator()
        allocator.deprioritise(colours: [0, 99])
        #expect(allocator.assign(PlayerID(0)).slot == 1)
        for id in 1..<9 { allocator.assign(PlayerID(id)) }
        #expect(allocator.assign(PlayerID(9)).slot == 0)
    }

    @Test func releaseAllEmptiesSlots() {
        var allocator = SlotAllocator()
        allocator.assign(PlayerID(0))
        allocator.releaseAll()
        #expect(allocator.slots.isEmpty)
    }
}
