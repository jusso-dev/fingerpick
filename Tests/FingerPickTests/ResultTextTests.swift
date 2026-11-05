import FingerPickKit
import Testing
@testable import FingerPick

struct ResultTextTests {
    private let ids = (0..<4).map(PlayerID.init)

    private func reveal(_ result: RoundResult) -> Reveal {
        Reveal(
            result: result,
            markers: Dictionary(uniqueKeysWithValues: ids.map { ($0, PlayerMarker(slot: $0.rawValue)) }),
            positions: [:],
            startedAt: 0
        )
    }

    @Test func singleAndMultipleWinners() {
        #expect(ResultText.headline(for: reveal(.winners([ids[0]]))) == "Orange circle 1 picked")
        #expect(ResultText.headline(for: reveal(.winners([ids[0], ids[1]]))) == "Orange circle 1 and Sky blue triangle 2 picked")
    }

    @Test func teamsListEveryMemberWhenSpoken() {
        let result = reveal(.teams([[ids[0], ids[2]], [ids[1], ids[3]]]))
        #expect(ResultText.headline(for: result) == "Split into 2 teams")
        #expect(ResultText.spoken(for: result).contains("Team 1: Orange circle 1 and Green square 3"))
        #expect(ResultText.spoken(for: result).contains("Team 2: Sky blue triangle 2 and Yellow diamond 4"))
    }

    @Test func orderIsSpokenInRankOrder() {
        let result = reveal(.order([ids[2], ids[0], ids[1]]))
        #expect(ResultText.headline(for: result) == "Green square 3 goes first")
        #expect(ResultText.spoken(for: result) == "1: Green square 3. 2: Orange circle 1. 3: Sky blue triangle 2")
    }

    @Test func ringOutcomesFollowTheResult() {
        let teams = RoundResult.teams([[ids[0]], [ids[1]]])
        #expect(RingFrame.outcome(of: ids[1], in: teams) == .team(1))
        #expect(RingFrame.outcome(of: ids[3], in: .order([ids[3], ids[0]])) == .rank(1))
        #expect(RingFrame.outcome(of: ids[2], in: .winners([ids[0]])) == .loser)
    }
}
