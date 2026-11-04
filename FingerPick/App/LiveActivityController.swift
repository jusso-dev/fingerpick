import ActivityKit
import FingerPickKit
import Foundation

/// Prototype (#29): shows the last result as a Live Activity, so it appears in the Dynamic Island
/// once the app is in the background. Off by default; local only (no push updates).
@MainActor
final class LiveActivityController {
    static let enabledKey = "liveActivityEnabled"

    /// Starts an activity for a new result. Live Activities can only start in the foreground,
    /// so this happens at the reveal; the system shows it in the Dynamic Island when the app leaves.
    func resultShown(_ reveal: Reveal, enabled: Bool) {
        endAll()
        guard enabled, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let single = reveal.result.leaders.count == 1 ? reveal.result.leaders.first.flatMap { reveal.markers[$0] } : nil
        let state = ResultActivityAttributes.ContentState(
            headline: ResultText.headline(for: reveal),
            symbol: single.map(Palette.symbol),
            colourIndex: single?.colourIndex
        )
        _ = try? Activity.request(
            attributes: ResultActivityAttributes(pickedAt: .now),
            content: ActivityContent(state: state, staleDate: .now.addingTimeInterval(15 * 60)),
            pushType: nil
        )
    }

    /// Ends every result activity: a new round started, or the app is back in the foreground.
    func endAll() {
        // Capture IDs now, so an activity started straight after this call isn't ended too.
        let ids = Set(Activity<ResultActivityAttributes>.activities.map(\.id))
        guard !ids.isEmpty else { return }
        Task {
            for activity in Activity<ResultActivityAttributes>.activities where ids.contains(activity.id) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
