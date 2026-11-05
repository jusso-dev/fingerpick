import Foundation

/// When to stop the screen from auto-locking (#21).
public enum IdleTimerPolicy {
    /// How long the waiting screen keeps the display awake after the last touch.
    public static let idleTimeout: TimeInterval = 120

    /// Keep the screen awake in the foreground while fingers are down, a result shows, or the
    /// last touch was less than `idleTimeout` ago. Auto-lock always works in the background.
    public static func keepsScreenAwake(
        isForeground: Bool, hasFingers: Bool, isShowingResult: Bool, lastActivity: TimeInterval?, now: TimeInterval
    ) -> Bool {
        guard isForeground else { return false }
        if hasFingers || isShowingResult { return true }
        guard let lastActivity else { return false }
        return now - lastActivity < idleTimeout
    }

    /// When to check again if the screen is awake only because of recent activity.
    public static func nextCheck(lastActivity: TimeInterval?, now: TimeInterval) -> TimeInterval? {
        guard let lastActivity, now - lastActivity < idleTimeout else { return nil }
        return lastActivity + idleTimeout
    }
}
