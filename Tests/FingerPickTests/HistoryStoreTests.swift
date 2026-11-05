import FingerPickKit
import Foundation
import Testing
@testable import FingerPick

@MainActor
struct HistoryStoreTests {
    private let reveal = Reveal(
        result: .winners([PlayerID(0)]),
        markers: [PlayerID(0): PlayerMarker(slot: 0), PlayerID(1): PlayerMarker(slot: 1)],
        positions: [:], startedAt: 0
    )

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("history-\(UUID().uuidString).json")
    }

    @Test func recordsPersistAcrossLaunches() {
        let url = tempURL()
        let store = HistoryStore(fileURL: url)
        store.record(reveal)
        let reloaded = HistoryStore(fileURL: url)
        #expect(reloaded.history.entries.first?.headline == "Orange circle 1 picked")
        #expect(reloaded.history.entries.first?.playerCount == 2)
    }

    @Test func clearRemovesSavedHistory() {
        let url = tempURL()
        let store = HistoryStore(fileURL: url)
        store.record(reveal)
        store.clear()
        #expect(HistoryStore(fileURL: url).history.entries.isEmpty)
    }

    @Test func savedFileIsExcludedFromBackup() throws {
        let url = tempURL()
        HistoryStore(fileURL: url).record(reveal)
        let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }

    @Test func keepsOnlyTen() {
        let store = HistoryStore(fileURL: tempURL())
        for _ in 0..<12 { store.record(reveal) }
        #expect(store.history.entries.count == 10)
    }
}
