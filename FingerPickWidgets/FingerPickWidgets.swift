import ActivityKit
import SwiftUI
import WidgetKit

@main
struct FingerPickWidgets: WidgetBundle {
    var body: some Widget {
        ResultLiveActivity()
    }
}

/// Last result in the Dynamic Island and on the Lock Screen.
struct ResultLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ResultActivityAttributes.self) { context in
            HStack(spacing: 12) {
                marker(context.state)
                    .font(.title2)
                Text(context.state.headline)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
            }
            .padding()
            .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    marker(context.state)
                        .font(.title)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.headline)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.pickedAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                marker(context.state)
            } compactTrailing: {
                Text("Picked")
                    .font(.caption2)
            } minimal: {
                marker(context.state)
            }
            .keylineTint(colour(context.state))
        }
    }

    private func marker(_ state: ResultActivityAttributes.ContentState) -> some View {
        Image(systemName: state.symbol ?? "hand.point.up.left.fill")
            .foregroundStyle(colour(state))
            .accessibilityHidden(true)
    }

    private func colour(_ state: ResultActivityAttributes.ContentState) -> Color {
        state.colourIndex.map { Color("Players/Player\($0)") } ?? .accentColor
    }
}
