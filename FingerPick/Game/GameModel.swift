import FingerPickKit
import Observation
import SwiftUI

/// Main-actor model that turns raw touches into game state for the views.
@MainActor
@Observable
final class GameModel {
    private(set) var touches = TouchRegistry<ObjectIdentifier>()

    /// True while any finger is down. Drives system gesture deferral and the home indicator.
    var isRoundActive: Bool { !touches.isEmpty }

    func handle(_ event: TouchEvent) {
        switch event {
        case let .began(key, location):
            touches.begin(key, at: location)
        case let .moved(key, location):
            touches.move(key, to: location)
        case let .ended(key):
            touches.end(key)
        case .cancelled:
            touches.removeAll()
        }
    }
}
