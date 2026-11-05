import Foundation

/// One finished round, as shown in History (#30).
public struct HistoryEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    /// Short result, for example "Orange circle 1 picked".
    public var headline: String
    /// Full result, for example every team or rank.
    public var detail: String
    public var playerCount: Int

    public init(id: UUID = UUID(), date: Date, headline: String, detail: String, playerCount: Int) {
        self.id = id
        self.date = date
        self.headline = headline
        self.detail = detail
        self.playerCount = playerCount
    }
}

/// The most recent rounds, newest first, capped at `limit`.
public struct RoundHistory: Codable, Equatable, Sendable {
    public static let limit = 10

    public private(set) var entries: [HistoryEntry] = []

    public init(entries: [HistoryEntry] = []) {
        self.entries = Array(entries.prefix(Self.limit))
    }

    public mutating func record(_ entry: HistoryEntry) {
        entries.insert(entry, at: 0)
        if entries.count > Self.limit { entries.removeLast(entries.count - Self.limit) }
    }

    public mutating func clear() {
        entries.removeAll()
    }
}
