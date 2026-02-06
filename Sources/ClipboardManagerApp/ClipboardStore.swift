import AppKit
import Combine
import Foundation

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []
    @Published var searchQuery: String = ""

    let maxItems: Int

    private let pasteboard = NSPasteboard.general
    private var changeCount: Int
    private var pollingTask: Task<Void, Never>?

    private var persistenceURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = appSupport.appendingPathComponent("ClipboardManagerApp", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("history.json")
    }

    init(maxItems: Int = 100) {
        self.maxItems = maxItems
        self.changeCount = pasteboard.changeCount
        load()
    }

    deinit {
        pollingTask?.cancel()
    }

    var filteredItems: [ClipboardItem] {
        let normalizedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return ordered(items)
        }

        return ordered(items).filter {
            $0.searchableText.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    func startMonitoring() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(600))
                self?.readPasteboardIfNeeded()
            }
        }
    }

    func stopMonitoring() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func copyToPasteboard(_ item: ClipboardItem) {
        pasteboard.clearContents()

        switch item.kind {
        case .text:
            pasteboard.setString(item.displayText, forType: .string)
        case .url:
            pasteboard.setString(item.displayText, forType: .string)
            pasteboard.setString(item.displayText, forType: .URL)
        case .rtf:
            if let base64 = item.rawDataBase64, let data = Data(base64Encoded: base64) {
                pasteboard.setData(data, forType: .rtf)
            }
        case .html:
            if let base64 = item.rawDataBase64, let data = Data(base64Encoded: base64) {
                pasteboard.setData(data, forType: .html)
            }
        case .image:
            if let base64 = item.rawDataBase64, let data = Data(base64Encoded: base64) {
                pasteboard.setData(data, forType: .tiff)
            }
        case .files:
            let urls = (item.filePaths ?? []).map { URL(fileURLWithPath: $0) }
            if !urls.isEmpty {
                pasteboard.writeObjects(urls as [NSURL])
            }
        }

        changeCount = pasteboard.changeCount
    }

    func remove(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clearUnpinned() {
        items.removeAll { !$0.isPinned }
        save()
    }

    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        save()
    }

    private func readPasteboardIfNeeded() {
        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount

        guard let newItem = makeItemFromPasteboard() else { return }

        if let index = items.firstIndex(where: { $0.dedupeKey == newItem.dedupeKey }) {
            var existing = items.remove(at: index)
            existing.copiedAt = .now
            items.insert(existing, at: 0)
        } else {
            items.insert(newItem, at: 0)
        }

        enforceLimit()
        save()
    }

    private func makeItemFromPasteboard() -> ClipboardItem? {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            let paths = urls.map(\.path)
            return ClipboardItem(
                kind: .files,
                displayText: "\(paths.count) file(s)",
                filePaths: paths
            )
        }

        if let string = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !string.isEmpty {
            if URL(string: string)?.scheme != nil {
                return ClipboardItem(kind: .url, displayText: string)
            }
            return ClipboardItem(kind: .text, displayText: string)
        }

        if let rtf = pasteboard.data(forType: .rtf),
           let attributed = NSAttributedString(rtf: rtf, documentAttributes: nil) {
            let preview = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
            return ClipboardItem(
                kind: .rtf,
                displayText: preview.isEmpty ? "Rich Text" : preview,
                rawDataBase64: rtf.base64EncodedString()
            )
        }

        if let html = pasteboard.data(forType: .html) {
            let preview = String(data: html, encoding: .utf8)?
                .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "HTML"
            return ClipboardItem(
                kind: .html,
                displayText: preview.isEmpty ? "HTML" : preview,
                rawDataBase64: html.base64EncodedString()
            )
        }

        if let tiff = pasteboard.data(forType: .tiff), let image = NSImage(data: tiff) {
            let size = image.size
            let preview = "Image \(Int(size.width))x\(Int(size.height))"
            return ClipboardItem(
                kind: .image,
                displayText: preview,
                rawDataBase64: tiff.base64EncodedString()
            )
        }

        return nil
    }

    private func enforceLimit() {
        guard items.count > maxItems else { return }

        var pinned = items.filter(\.isPinned)
        let unpinned = items.filter { !$0.isPinned }
        let allowedUnpinned = max(maxItems - pinned.count, 0)

        let trimmedUnpinned = Array(unpinned.prefix(allowedUnpinned))
        if pinned.count > maxItems {
            pinned = Array(pinned.prefix(maxItems))
        }

        items = pinned + trimmedUnpinned
        items.sort {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.copiedAt > $1.copiedAt
        }
    }

    private func ordered(_ input: [ClipboardItem]) -> [ClipboardItem] {
        input.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.copiedAt > $1.copiedAt
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: persistenceURL) else { return }
        guard let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else { return }
        items = decoded
        enforceLimit()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: persistenceURL, options: .atomic)
    }
}
