#if canImport(ActivityKit)
import ActivityKit
import Foundation

/// Live Activity showing the last result in the Dynamic Island and on the Lock Screen (#29).
/// Shared by the app and the widget extension. No network: started and ended locally.
struct ResultActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// For example "Orange circle 1 picked".
        var headline: String
        /// SF Symbol of the winner's shape, if there is a single winner.
        var symbol: String?
        /// Winner's palette index (0-9), for the colour.
        var colourIndex: Int?
    }

    var pickedAt: Date
}
#endif
