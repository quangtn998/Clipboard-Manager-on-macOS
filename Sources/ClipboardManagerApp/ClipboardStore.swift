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
            $0.content.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    func startMonitoring() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(600))
                await self?.readPasteboardIfNeeded()
            }
        }
    }

    func stopMonitoring() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func copyToPasteboard(_ item: ClipboardItem) {
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
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

        guard let value = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else {
            return
        }

        if let index = items.firstIndex(where: { $0.content == value }) {
            var existing = items.remove(at: index)
            existing.copiedAt = .now
            items.insert(existing, at: 0)
        } else {
            items.insert(ClipboardItem(content: value), at: 0)
        }

        enforceLimit()
        save()
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
