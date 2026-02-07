import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ClipboardStore
    @State private var showingClearAlert = false

    var body: some View {
        Form {
            Section("Storage Management") {
                Stepper(value: $store.maxItemsLimit, in: 1...1000, step: 10) {
                    Text("Max items: \(store.maxItemsLimit)")
                }

                Stepper(value: $store.retentionDays, in: 0...365) {
                    if store.retentionDays == 0 {
                        Text("Auto-delete: Off")
                    } else {
                        Text("Auto-delete after \(store.retentionDays) days")
                    }
                }

                Toggle("Keep pinned items when clearing all", isOn: $store.keepPinnedOnClear)

                HStack {
                    Text("Storage used")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: Int64(store.storageUsageBytes), countStyle: .file))
                        .foregroundStyle(.secondary)
                }

                Button("Clear All Items") {
                    showingClearAlert = true
                }
                .buttonStyle(.borderedProminent)
                .alert("Clear clipboard history?", isPresented: $showingClearAlert) {
                    Button("Clear", role: .destructive) {
                        store.clearAll(keepingPinned: store.keepPinnedOnClear)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text(store.keepPinnedOnClear ? "Pinned items will stay in history." : "This will delete all items, including pinned.")
                }
            }

            Section("Quick Stats") {
                statRow(title: "Copied this week", value: "\(store.stats.copiedThisWeek) items")
                if let kind = store.stats.mostCopiedKind {
                    statRow(title: "Most copied", value: "\(kind.displayName) (\(store.stats.mostCopiedPercentage)%)")
                } else {
                    statRow(title: "Most copied", value: "No data yet")
                }
                if let days = store.stats.oldestItemAgeDays {
                    statRow(title: "Oldest item", value: "\(days) days ago")
                } else {
                    statRow(title: "Oldest item", value: "No data yet")
                }
            }

            Section("Search Tips") {
                Text("Try: type:image, yesterday, from:2024-01-01 to:2024-01-31, or fuzzy matches like \"copd\".")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Paste Queue") {
                Toggle("Auto-remove item after paste", isOn: $store.autoRemoveAfterPaste)
            }
        }
        .frame(minWidth: 420, minHeight: 360)
        .padding()
    }

    @ViewBuilder
    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
