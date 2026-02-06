import SwiftUI

struct PasteQueueView: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        VStack(spacing: 16) {
            header
            Toggle("Auto-remove after paste", isOn: $store.autoRemoveAfterPaste)
                .toggleStyle(.switch)
                .frame(maxWidth: .infinity, alignment: .leading)

            if store.pasteQueue.isEmpty {
                ContentUnavailableView("Queue trống", systemImage: "tray", description: Text("Thêm items từ history để paste lần lượt."))
            } else {
                List {
                    ForEach(Array(store.pasteQueue.enumerated()), id: \.element.id) { index, entry in
                        PasteQueueRow(entry: entry, index: index, store: store)
                    }
                    .onMove(perform: store.moveQueueItems)
                }
                .listStyle(.inset)
            }

            footer
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 420)
        .toolbar {
            EditButton()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Paste Queue")
                    .font(.title2.weight(.semibold))
                Text("\(store.pasteQueue.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Clear All") {
                store.clearQueue()
            }
            .buttonStyle(.bordered)
            .disabled(store.pasteQueue.isEmpty)
        }
    }

    private var footer: some View {
        HStack {
            Button("Paste Next") {
                store.pasteNextFromQueue()
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.pasteQueue.isEmpty)

            Spacer()

            Text(store.autoRemoveAfterPaste ? "Items sẽ tự xóa sau khi paste." : "Items sẽ giữ lại sau khi paste.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PasteQueueRow: View {
    let entry: PasteQueueEntry
    let index: Int
    @ObservedObject var store: ClipboardStore

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(index == 0 ? Color.accentColor : Color.accentColor.opacity(0.2))
                Text("\(index + 1)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(index == 0 ? .white : .accentColor)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.item.previewText)
                    .font(.body)
                    .lineLimit(2)
                Text(entry.item.kind.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if index == 0 {
                Label("Next", systemImage: "play.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }

            Button(role: .destructive) {
                store.removeFromQueue(entry)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .contextMenu {
            Button("Paste Next") {
                store.pasteNextFromQueue()
            }
            Button("Remove from Queue", role: .destructive) {
                store.removeFromQueue(entry)
            }
        }
    }
}
