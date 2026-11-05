import FingerPickKit
import Testing
@testable import FingerPick

struct GameSettingsTests {
    @Test func defaultsGiveASingleWinnerAfterThreeSeconds() {
        let configuration = GameSettings.configuration(
            mode: .single, winnerCount: 2, teamCount: 2, countdownSeconds: 3, minimumFingers: 2
        )
        #expect(configuration == RoundConfiguration())
    }

    @Test func eachModeMapsToItsPickMode() {
        func mode(_ choice: ModeChoice) -> PickMode {
            GameSettings.configuration(mode: choice, winnerCount: 3, teamCount: 4, countdownSeconds: 2, minimumFingers: 2).mode
        }
        #expect(mode(.single) == .single)
        #expect(mode(.winners) == .winners(3))
        #expect(mode(.teams) == .teams(4))
        #expect(mode(.order) == .order)
    }

    @Test func outOfRangeValuesAreClamped() {
        let configuration = GameSettings.configuration(
            mode: .teams, winnerCount: 0, teamCount: 99, countdownSeconds: 30, minimumFingers: 0
        )
        #expect(configuration.mode == .teams(5))
        #expect(configuration.countdownDuration == 5)
        #expect(configuration.minimumPlayers == 2)
    }

    @MainActor
    @Test func modelAppliesNewConfiguration() {
        let model = GameModel(clock: ManualClock())
        model.updateConfiguration(GameSettings.configuration(
            mode: .order, winnerCount: 2, teamCount: 2, countdownSeconds: 5, minimumFingers: 4
        ))
        #expect(model.engine.configuration.mode == .order)
        #expect(model.engine.configuration.requiredPlayers == 4)
        #expect(model.isIdle)
    }
}
