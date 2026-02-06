import AppKit
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
            ClipboardCommands()
        }

        MenuBarExtra("Clipboard", systemImage: "doc.on.clipboard") {
            MenuBarContent(store: store)
                .frame(width: 360, height: 420)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("About Clipboard Manager", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        VStack(spacing: 16) {
            header
            searchBar

            List(store.filteredItems) { item in
                ClipboardRow(item: item, store: store)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(NSColor.windowBackgroundColor), Color(NSColor.controlBackgroundColor)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear { store.startMonitoring() }
        .onDisappear { store.stopMonitoring() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Clipboard Manager")
                    .font(.title2.weight(.semibold))
                Text("Lưu trữ & tìm kiếm nhanh nội dung đã sao chép")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(store.filteredItems.count) mục")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule())

            Button {
                store.clearUnpinned()
            } label: {
                Label("Xóa không ghim", systemImage: "trash")
            }
            .buttonStyle(.bordered)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Tìm kiếm nội dung clipboard...", text: $store.searchQuery)
                .textFieldStyle(.plain)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct MenuBarContent: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $store.searchQuery)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal)

            List(store.filteredItems.prefix(25)) { item in
                ClipboardRow(item: item, store: store)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            Button {
                store.clearUnpinned()
            } label: {
                Label("Clear Unpinned", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .padding(.bottom, 8)

            Divider()

            HStack {
                Text("Version \(Bundle.main.shortVersionString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Check for Updates…") {
                    openReleaseURL()
                }
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.bottom, 6)
        }
        .padding(.top, 8)
        .onAppear { store.startMonitoring() }
    }

    private func openReleaseURL() {
        guard let url = URL(string: "https://github.com/quangtn998/Clipboard-Manager-on-macOS/releases/latest") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

struct ClipboardCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("About Clipboard Manager") {
                openWindow(id: "about")
            }
        }
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") {
                openReleaseURL()
            }
        }
    }

    private func openReleaseURL() {
        guard let url = URL(string: "https://github.com/quangtn998/Clipboard-Manager-on-macOS/releases/latest") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

struct ClipboardRow: View {
    let item: ClipboardItem
    @ObservedObject var store: ClipboardStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                    Image(systemName: iconName)
                        .foregroundStyle(Color.accentColor)
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(item.kind.displayName.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(item.copiedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(item.previewText)
                        .font(.body)
                        .lineLimit(3)
                        .truncationMode(.tail)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        store.togglePin(item)
                    } label: {
                        Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    }

                    Button {
                        store.copyToPasteboard(item)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }

                    Button(role: .destructive) {
                        store.remove(item)
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
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

    private var iconName: String {
        switch item.kind {
        case .text:
            return "text.justify"
        case .url:
            return "link"
        case .rtf:
            return "doc.richtext"
        case .html:
            return "chevron.left.slash.chevron.right"
        case .image:
            return "photo"
        case .files:
            return "folder"
        }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Clipboard Manager")
                .font(.title2.weight(.semibold))
            Text("Version \(Bundle.main.shortVersionString)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Link("View latest release", destination: URL(string: "https://github.com/quangtn998/Clipboard-Manager-on-macOS/releases/latest")!)
        }
        .padding(24)
        .frame(minWidth: 320)
    }
}

private extension Bundle {
    var shortVersionString: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
}
