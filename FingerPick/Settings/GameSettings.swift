import FingerPickKit
import Foundation

/// Mode choice as stored in `@AppStorage`.
enum ModeChoice: String, CaseIterable, Identifiable {
    case single, winners, teams, order

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .single: "One winner"
        case .winners: "Several winners"
        case .teams: "Teams"
        case .order: "Turn order"
        }
    }
}

/// `@AppStorage` keys and defaults, and the mapping to a round configuration.
enum GameSettings {
    static let modeKey = "mode"
    static let winnerCountKey = "winnerCount"
    static let teamCountKey = "teamCount"
    static let countdownKey = "countdownSeconds"
    static let minimumFingersKey = "minimumFingers"

    static let defaultWinnerCount = 2
    static let defaultTeamCount = 2
    static let defaultCountdown = 3
    static let defaultMinimumFingers = 2
    static let minimumFingersRange = 2...20

    static func configuration(
        mode: ModeChoice, winnerCount: Int, teamCount: Int, countdownSeconds: Int, minimumFingers: Int
    ) -> RoundConfiguration {
        let pickMode: PickMode = switch mode {
        case .single: .single
        case .winners: .winners(winnerCount.clamped(to: PickMode.winnerRange))
        case .teams: .teams(teamCount.clamped(to: PickMode.teamRange))
        case .order: .order
        }
        return RoundConfiguration(
            minimumPlayers: minimumFingers.clamped(to: minimumFingersRange),
            countdownDuration: TimeInterval(countdownSeconds),
            mode: pickMode
        )
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
