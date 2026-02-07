import AppKit
import SwiftUI
import UniformTypeIdentifiers

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
            ClipboardCommands(store: store)
        }

        Settings {
            SettingsView(store: store)
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
    @State private var isQueuePresented = false

    var body: some View {
        VStack(spacing: 16) {
            header
            searchBar

            List {
                if !pinnedItems.isEmpty {
                    Section("Pinned") {
                        ForEach(pinnedItems) { item in
                            ClipboardRow(item: item, store: store)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                        .onMove { offsets, destination in
                            store.reorderPinned(from: offsets, to: destination)
                        }
                    }
                }

                Section("History") {
                    ForEach(unpinnedItems) { item in
                        ClipboardRow(item: item, store: store)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onDrop(of: [UTType.fileURL, UTType.url, UTType.text, UTType.image], isTargeted: nil) { providers in
                store.handleDrop(providers: providers)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(NSColor.windowBackgroundColor), Color(NSColor.controlBackgroundColor)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .sheet(isPresented: $isQueuePresented) {
            PasteQueueView(store: store)
        }
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
                isQueuePresented = true
            } label: {
                Label("Queue (\(store.pasteQueue.count))", systemImage: "tray.full")
            }
            .buttonStyle(.bordered)

            Menu {
                Button("Clear All") {
                    store.clearAll(keepingPinned: false)
                }
                Button("Clear All (Keep Pinned)") {
                    store.clearAll(keepingPinned: true)
                }
                Divider()
                Button("Clear Unpinned") {
                    store.clearUnpinned()
                }
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
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

    private var pinnedItems: [ClipboardItem] {
        store.filteredItems.filter(\.isPinned)
    }

    private var unpinnedItems: [ClipboardItem] {
        store.filteredItems.filter { !$0.isPinned }
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

            Menu {
                Button("Clear All") {
                    store.clearAll(keepingPinned: false)
                }
                Button("Clear All (Keep Pinned)") {
                    store.clearAll(keepingPinned: true)
                }
                Divider()
                Button("Clear Unpinned") {
                    store.clearUnpinned()
                }
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .padding(.bottom, 8)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Paste Queue", systemImage: "tray.full")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(store.pasteQueue.count)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Button("Paste Next") {
                        store.pasteNextFromQueue()
                    }
                    .keyboardShortcut("n", modifiers: [.control, .option])
                    .buttonStyle(.borderedProminent)
                    Button("Clear Queue") {
                        store.clearQueue()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 6)

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
    @ObservedObject var store: ClipboardStore
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
        CommandGroup(after: .pasteboard) {
            Button("Paste Next from Queue") {
                store.pasteNextFromQueue()
            }
            .keyboardShortcut("n", modifiers: [.control, .option])
            Button("Clear Paste Queue") {
                store.clearQueue()
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

                    previewContent
                }

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        store.togglePin(item)
                    } label: {
                        Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    }

                    Button {
                        store.addToQueue(item)
                    } label: {
                        Image(systemName: "tray.and.arrow.down")
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
        .onDrag {
            store.itemProvider(for: item)
        }
        .contextMenu {
            Button(item.isPinned ? "Bỏ ghim" : "Ghim") {
                store.togglePin(item)
            }
            Button("Add to Paste Queue") {
                store.addToQueue(item)
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

    @ViewBuilder
    private var previewContent: some View {
        switch item.kind {
        case .url:
            URLPreviewView(item: item)
        case .image:
            ImagePreviewView(item: item)
        case .files:
            FilePreviewList(item: item)
        case .rtf, .html, .text:
            if item.previewText.isLikelyCode {
                Text(SyntaxHighlighter.attributedString(for: item.previewText))
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .lineLimit(3)
                    .truncationMode(.tail)
            } else {
                Text(item.previewText)
                    .font(.body)
                    .lineLimit(3)
                    .truncationMode(.tail)
            }
        }
    }
}

private struct URLPreviewView: View {
    let item: ClipboardItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let thumbnail = item.urlThumbnailImage {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 56, height: 56)
                    .overlay(Image(systemName: "link").foregroundStyle(Color.accentColor))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.urlTitle ?? item.urlHost ?? item.displayText)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                Text(item.displayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct ImagePreviewView: View {
    let item: ClipboardItem

    var body: some View {
        if let image = item.previewImage {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            Text(item.previewText)
                .font(.body)
                .lineLimit(2)
        }
    }
}

private struct FilePreviewList: View {
    let item: ClipboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if filePreviewRows.isEmpty {
                Text(item.previewText)
                    .font(.body)
                    .lineLimit(2)
            } else {
                ForEach(filePreviewRows.prefix(3), id: \.path) { row in
                    HStack(spacing: 8) {
                        Image(nsImage: row.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.name)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Text("\(row.size) • \(row.modified)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let extra = extraCount {
                    Text("and \(extra) more files")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var filePreviewRows: [FilePreviewRow] {
        let paths = item.filePaths ?? []
        return paths.compactMap { path in
            FilePreviewRow(path: path)
        }
    }

    private var extraCount: Int? {
        let count = (item.filePaths ?? []).count
        return count > 3 ? count - 3 : nil
    }
}

private struct FilePreviewRow {
    let path: String
    let name: String
    let size: String
    let modified: String
    let icon: NSImage

    init?(path: String) {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        let fileSize = attributes?[.size] as? Int64 ?? 0
        let modifiedDate = attributes?[.modificationDate] as? Date ?? .now
        name = url.lastPathComponent
        size = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        modified = modifiedDate.formatted(date: .abbreviated, time: .shortened)
        icon = NSWorkspace.shared.icon(forFile: path)
        self.path = path
    }
}

private extension ClipboardItem {
    var urlHost: String? {
        URL(string: displayText)?.host
    }

    var previewImage: NSImage? {
        guard let rawDataBase64, let data = Data(base64Encoded: rawDataBase64) else { return nil }
        return NSImage(data: data)
    }

    var urlThumbnailImage: NSImage? {
        guard let urlThumbnailBase64, let data = Data(base64Encoded: urlThumbnailBase64) else { return nil }
        return NSImage(data: data)
    }
}

private extension String {
    var isLikelyCode: Bool {
        let codeTokens = ["{", "}", ";", "func ", "class ", "struct ", "let ", "var ", "import ", "->"]
        if codeTokens.contains(where: { contains($0) }) {
            return true
        }
        return contains("\n") && count > 80
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
