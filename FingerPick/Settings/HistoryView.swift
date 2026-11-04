import FingerPickKit
import SwiftUI

/// Last ten results, with a clear button (#30).
struct HistoryView: View {
    let store: HistoryStore
    @State private var confirmsClear = false

    var body: some View {
        List {
            if store.history.entries.isEmpty {
                ContentUnavailableView(
                    "No rounds yet", systemImage: "clock", description: Text("Results from your last 10 rounds show here.")
                )
            }
            ForEach(store.history.entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.headline)
                        .font(.headline)
                    if entry.detail != entry.headline {
                        Text(entry.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(entry.date, format: .relative(presentation: .named)) · \(entry.playerCount) players")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .navigationTitle("History")
        .toolbar {
            if !store.history.entries.isEmpty {
                Button("Clear", role: .destructive) { confirmsClear = true }
                    .accessibilityIdentifier("history.clear")
            }
        }
        .confirmationDialog("Clear history?", isPresented: $confirmsClear, titleVisibility: .visible) {
            Button("Clear History", role: .destructive) { store.clear() }
        } message: {
            Text("History is stored only on this iPhone.")
        }
    }
}
