import Testing
@testable import FingerPickKit

struct ModeTests {
    private func ids(_ count: Int) -> [PlayerID] { (0..<count).map(PlayerID.init) }

    // MARK: Pick N winners (#12)

    @Test(arguments: 1...9)
    func winnersNeedAtLeastOneLoser(count: Int) {
        #expect(PickMode.winners(count).minimumPlayers == max(2, count + 1))
    }

    @Test(arguments: 2...10)
    func winnersAreDistinctAndFromThePlayers(players: Int) {
        var picker = FairPicker(generator: SeededGenerator(seed: UInt64(players)))
        for count in 1..<players {
            guard case let .winners(winners) = picker.pick(from: ids(players), mode: .winners(count)) else {
                Issue.record("Wrong result kind")
                return
            }
            #expect(winners.count == count)
            #expect(Set(winners).count == count)
            #expect(Set(winners).isSubset(of: ids(players)))
        }
    }

    @Test func eachPlayerIsEquallyLikelyToBeAWinner() {
        var picker = FairPicker(generator: SeededGenerator(seed: 99))
        var counts = [Int](repeating: 0, count: 6)
        let rounds = 60_000
        for _ in 0..<rounds {
            for id in picker.pick(from: ids(6), mode: .winners(2)).pickedPlayers { counts[id.rawValue] += 1 }
        }
        let expected = Double(rounds * 2) / 6
        let chi = counts.reduce(0.0) { $0 + (Double($1) - expected) * (Double($1) - expected) / expected }
        #expect(chi < 20.515) // df 5, p = 0.001
    }

    @Test func engineWaitsForEnoughFingersForWinners() {
        var engine = RoundEngine(
            configuration: RoundConfiguration(mode: .winners(3)), picker: FairPicker(generator: SeededGenerator(seed: 1))
        )
        for id in 0..<3 { _ = engine.fingerDown(PlayerID(id), at: 0) }
        #expect(engine.configuration.requiredPlayers == 4)
        #expect(engine.tick(at: 50).isEmpty)
        _ = engine.fingerDown(PlayerID(3), at: 50)
        _ = engine.tick(at: 51)
        #expect(engine.tick(at: 54).last.map { if case .selected(.winners(let w)) = $0 { w.count == 3 } else { false } } == true)
    }

    // MARK: Teams (#13)

    @Test(arguments: 2...5)
    func teamsAreBalancedForEveryFingerCount(teamCount: Int) {
        var picker = FairPicker(generator: SeededGenerator(seed: UInt64(teamCount)))
        for players in max(2, teamCount)...10 {
            let result = picker.pick(from: ids(players), mode: .teams(teamCount))
            guard case let .teams(teams) = result else {
                Issue.record("Wrong result kind")
                return
            }
            let sizes = teams.map(\.count)
            #expect(teams.count == teamCount)
            #expect(sizes.max()! - sizes.min()! <= 1, "\(players) players, \(teamCount) teams: \(sizes)")
            #expect(sizes.min()! >= 1)
            #expect(Set(result.pickedPlayers) == Set(ids(players)))
            #expect(result.pickedPlayers.count == players)
            for id in ids(players) { #expect(result.team(of: id) != nil) }
        }
    }

    @Test func teamsNeedOnePlayerPerTeam() {
        #expect(PickMode.teams(2).minimumPlayers == 2)
        #expect(PickMode.teams(5).minimumPlayers == 5)
        #expect(RoundResult.winners([PlayerID(0)]).team(of: PlayerID(0)) == nil)
    }

    // MARK: Order (#14)

    @Test(arguments: 2...10)
    func ranksAreUniqueAndComplete(players: Int) {
        var picker = FairPicker(generator: SeededGenerator(seed: UInt64(players) + 50))
        let result = picker.pick(from: ids(players), mode: .order)
        let ranks = ids(players).compactMap { result.rank(of: $0) }
        #expect(ranks.sorted() == Array(1...players))
        #expect(result.leaders.count == 1)
        #expect(result.rank(of: result.leaders[0]) == 1)
        #expect(RoundResult.teams([[PlayerID(0)]]).rank(of: PlayerID(0)) == nil)
    }

    @Test func firstPlaceIsUniform() {
        var picker = FairPicker(generator: SeededGenerator(seed: 5))
        var counts = [Int](repeating: 0, count: 4)
        for _ in 0..<40_000 { counts[picker.pick(from: ids(4), mode: .order).leaders[0].rawValue] += 1 }
        let expected = 10_000.0
        let chi = counts.reduce(0.0) { $0 + (Double($1) - expected) * (Double($1) - expected) / expected }
        #expect(chi < 16.266) // df 3, p = 0.001
    }

    @Test func leadersByMode() {
        #expect(RoundResult.teams([[PlayerID(0)], [PlayerID(1)]]).leaders.isEmpty)
        #expect(RoundResult.winners([PlayerID(2), PlayerID(3)]).leaders == [PlayerID(2), PlayerID(3)])
    }
}
