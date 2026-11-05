import Testing
@testable import FingerPickKit

struct PickerTests {
    private func ids(_ count: Int) -> [PlayerID] { (0..<count).map(PlayerID.init) }

    /// Chi-square goodness of fit against a uniform distribution.
    private func chiSquare(_ counts: [Int], total: Int) -> Double {
        let expected = Double(total) / Double(counts.count)
        return counts.reduce(0) { $0 + pow2(Double($1) - expected) / expected }
    }

    private func pow2(_ x: Double) -> Double { x * x }

    /// Chi-square critical values at p = 0.001 for 1...9 degrees of freedom. Nine player counts are
    /// tested, so p = 0.001 each (Bonferroni) keeps the family-wise threshold under p = 0.01.
    private let critical: [Int: Double] = [
        1: 10.828, 2: 13.816, 3: 16.266, 4: 18.467, 5: 20.515, 6: 22.458, 7: 24.322, 8: 26.124, 9: 27.877,
    ]

    @Test(arguments: 2...10)
    func singleWinnerIsUniform(players: Int) {
        var picker = FairPicker(generator: SeededGenerator(seed: UInt64(players) * 7_919))
        let rounds = 100_000
        var counts = [Int](repeating: 0, count: players)
        for _ in 0..<rounds {
            guard case let .winners(winners) = picker.pick(from: ids(players), mode: .single) else {
                Issue.record("Unexpected result")
                return
            }
            counts[winners[0].rawValue] += 1
        }
        #expect(chiSquare(counts, total: rounds) < critical[players - 1]!)
    }

    @Test func systemGeneratorIsUniform() {
        // Loose bound (p > 0.000001) so the CSPRNG test is not flaky.
        var picker = FairPicker()
        let rounds = 100_000
        var counts = [Int](repeating: 0, count: 5)
        for _ in 0..<rounds {
            counts[picker.pick(from: ids(5), mode: .single).pickedPlayers[0].rawValue] += 1
        }
        #expect(chiSquare(counts, total: rounds) < 33.4)
    }

    @Test func resultDoesNotDependOnTouchOrder() {
        let players = ids(8)
        for seed in UInt64(0)..<50 {
            var a = FairPicker(generator: SeededGenerator(seed: seed))
            var b = FairPicker(generator: SeededGenerator(seed: seed))
            #expect(a.pick(from: players, mode: .single) == b.pick(from: players.reversed(), mode: .single))
        }
    }

    @Test func seededPicksAreDeterministic() {
        var a = FairPicker(generator: SeededGenerator(seed: 42))
        var b = FairPicker(generator: SeededGenerator(seed: 42))
        for _ in 0..<20 {
            #expect(a.pick(from: ids(6), mode: .single) == b.pick(from: ids(6), mode: .single))
        }
    }

    @Test func winnerIsAlwaysOneOfThePlayers() {
        var picker = FairPicker(generator: SeededGenerator(seed: 1))
        let players = [PlayerID(4), PlayerID(9), PlayerID(17)]
        for _ in 0..<100 {
            #expect(players.contains(picker.pick(from: players, mode: .single).pickedPlayers[0]))
        }
    }
}
