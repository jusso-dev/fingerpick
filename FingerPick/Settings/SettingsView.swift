import FingerPickKit
import SwiftUI

/// Native settings sheet (#15). Values persist with `@AppStorage`.
struct SettingsView: View {
    @AppStorage(GameSettings.modeKey) private var mode = ModeChoice.single
    @AppStorage(GameSettings.winnerCountKey) private var winnerCount = GameSettings.defaultWinnerCount
    @AppStorage(GameSettings.teamCountKey) private var teamCount = GameSettings.defaultTeamCount
    @AppStorage(GameSettings.countdownKey) private var countdownSeconds = GameSettings.defaultCountdown
    @AppStorage(GameSettings.minimumFingersKey) private var minimumFingers = GameSettings.defaultMinimumFingers
    @AppStorage(Haptics.enabledKey) private var hapticsEnabled = true
    @AppStorage(LiveActivityController.enabledKey) private var liveActivityEnabled = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(ModeChoice.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .accessibilityIdentifier("settings.mode")
                    switch mode {
                    case .winners:
                        Stepper(value: $winnerCount, in: PickMode.winnerRange) {
                            Text("Winners: \(winnerCount)")
                        }
                        .accessibilityIdentifier("settings.winners")
                    case .teams:
                        Stepper(value: $teamCount, in: PickMode.teamRange) {
                            Text("Teams: \(teamCount)")
                        }
                        .accessibilityIdentifier("settings.teams")
                    case .single, .order:
                        EmptyView()
                    }
                } header: {
                    Text("Pick")
                } footer: {
                    Text(modeFooter)
                }

                Section("Round") {
                    Stepper(value: $countdownSeconds, in: 1...5) {
                        Text("Countdown: \(countdownSeconds) s")
                    }
                    .accessibilityIdentifier("settings.countdown")
                    Stepper(value: $minimumFingers, in: GameSettings.minimumFingersRange) {
                        Text("Minimum fingers: \(minimumFingers)")
                    }
                    .accessibilityIdentifier("settings.minimumFingers")
                }

                Section {
                    Toggle("Haptics", isOn: $hapticsEnabled)
                        .accessibilityIdentifier("settings.haptics")
                    Toggle("Show result in Dynamic Island", isOn: $liveActivityEnabled)
                        .accessibilityIdentifier("settings.liveActivity")
                } footer: {
                    Text("After a round, the result stays in the Dynamic Island and on the Lock Screen until you come back.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settings.done")
                }
            }
        }
    }

    private var modeFooter: LocalizedStringKey {
        switch mode {
        case .single: "One person is picked."
        case .winners: "Needs at least \(winnerCount + 1) fingers, so someone is left out."
        case .teams: "Teams differ in size by one at most."
        case .order: "Everyone gets a turn number."
        }
    }
}

#Preview {
    SettingsView()
}
