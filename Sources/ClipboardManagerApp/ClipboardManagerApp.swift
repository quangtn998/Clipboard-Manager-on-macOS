import SwiftUI

@main
struct ClipboardManagerApp: App {
    @StateObject private var store = ClipboardStore(maxItems: 120)

    var body: some Scene {
        WindowGroup("Clipboard Manager") {
            ContentView(store: store)
                .frame(minWidth: 620, minHeight: 420)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra("Clipboard", systemImage: "doc.on.clipboard") {
            MenuBarContent(store: store)
                .frame(width: 360, height: 420)
        }
        .menuBarExtraStyle(.window)
    }
}

struct ContentView: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        VStack(spacing: 12) {
            TextField("Tìm kiếm nội dung clipboard...", text: $store.searchQuery)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("Lịch sử: \(store.filteredItems.count) mục")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Xóa mục không ghim") {
                    store.clearUnpinned()
                }
            }

            List(store.filteredItems) { item in
                ClipboardRow(item: item, store: store)
            }
            .listStyle(.inset)
        }
        .padding()
        .onAppear { store.startMonitoring() }
        .onDisappear { store.stopMonitoring() }
    }
}

struct MenuBarContent: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        VStack(spacing: 8) {
            TextField("Search", text: $store.searchQuery)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            List(store.filteredItems.prefix(25)) { item in
                ClipboardRow(item: item, store: store)
            }
            .listStyle(.plain)

            Button("Clear Unpinned") {
                store.clearUnpinned()
            }
            .padding(.bottom, 8)
        }
        .onAppear { store.startMonitoring() }
    }
}

struct ClipboardRow: View {
    let item: ClipboardItem
    @ObservedObject var store: ClipboardStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.content)
                    .lineLimit(2)
                    .truncationMode(.tail)

                Spacer()

                Button {
                    store.togglePin(item)
                } label: {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                }
                .buttonStyle(.plain)

                Button {
                    store.copyToPasteboard(item)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    store.remove(item)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
            }

            Text(item.copiedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button(item.isPinned ? "Bỏ ghim" : "Ghim") {
                store.togglePin(item)
            }
            Button("Sao chép lại") {
                store.copyToPasteboard(item)
            }
            Button("Xóa", role: .destructive) {
                store.remove(item)
            }
        }
    }
}
