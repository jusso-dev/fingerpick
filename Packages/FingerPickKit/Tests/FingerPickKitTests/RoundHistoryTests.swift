import Foundation
import Testing
@testable import FingerPickKit

struct RoundHistoryTests {
    private func entry(_ n: Int) -> HistoryEntry {
        HistoryEntry(date: Date(timeIntervalSince1970: TimeInterval(n)), headline: "Round \(n)", detail: "", playerCount: 2)
    }

    @Test func keepsTheLastTenNewestFirst() {
        var history = RoundHistory()
        for n in 1...15 { history.record(entry(n)) }
        #expect(history.entries.count == 10)
        #expect(history.entries.first?.headline == "Round 15")
        #expect(history.entries.last?.headline == "Round 6")
    }

    @Test func clearEmptiesHistory() {
        var history = RoundHistory()
        history.record(entry(1))
        history.clear()
        #expect(history.entries.isEmpty)
    }

    @Test func roundTripsThroughJSON() throws {
        var history = RoundHistory()
        for n in 1...3 { history.record(entry(n)) }
        let decoded = try JSONDecoder().decode(RoundHistory.self, from: JSONEncoder().encode(history))
        #expect(decoded == history)
    }

    @Test func initialiserCapsEntries() {
        #expect(RoundHistory(entries: (1...20).map(entry)).entries.count == 10)
    }
}
