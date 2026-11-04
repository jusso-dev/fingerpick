import FingerPickKit
import Foundation
import Observation

/// Recent rounds, saved as JSON in Application Support. Stays on this device: excluded from
/// backups and never synced (#30).
@MainActor
@Observable
final class HistoryStore {
    private(set) var history: RoundHistory
    @ObservationIgnored private let fileURL: URL?

    init(fileURL: URL? = HistoryStore.defaultURL) {
        self.fileURL = fileURL
        history = fileURL
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(RoundHistory.self, from: $0) }
            ?? RoundHistory()
    }

    static var defaultURL: URL? {
        try? FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("history.json")
    }

    func record(_ reveal: Reveal, at date: Date = .now) {
        history.record(HistoryEntry(
            date: date,
            headline: ResultText.headline(for: reveal),
            detail: ResultText.spoken(for: reveal),
            playerCount: reveal.markers.count
        ))
        save()
    }

    func clear() {
        history.clear()
        save()
    }

    private func save() {
        guard var url = fileURL, let data = try? JSONEncoder().encode(history) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
}
