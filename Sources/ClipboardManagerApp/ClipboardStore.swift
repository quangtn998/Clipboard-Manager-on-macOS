import AppKit
import Combine
import Foundation
import LinkPresentation
import UniformTypeIdentifiers

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = [] {
        didSet {
            updateDerivedData()
        }
    }
    @Published var searchQuery: String = ""

    @Published var maxItemsLimit: Int {
        didSet { handleSettingsChange() }
    }
    @Published var retentionDays: Int {
        didSet { handleSettingsChange() }
    }
    @Published var keepPinnedOnClear: Bool {
        didSet { handleSettingsChange() }
    }
    @Published private(set) var storageUsageBytes: Int = 0
    @Published private(set) var stats: ClipboardStats = ClipboardStats.empty

    private let pasteboard = NSPasteboard.general
    private var changeCount: Int
    private var pollingTask: Task<Void, Never>?
    private var metadataTasks: [UUID: Task<Void, Never>] = [:]
    private let defaults = UserDefaults.standard
    private let maxLimit = 1000

    private var persistenceURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = appSupport.appendingPathComponent("ClipboardManagerApp", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("history.json")
    }

    init(maxItems: Int = 100) {
        let storedMax = defaults.integer(forKey: SettingsKey.maxItemsLimit)
        let storedRetention = defaults.integer(forKey: SettingsKey.retentionDays)
        let storedKeepPinned = defaults.object(forKey: SettingsKey.keepPinnedOnClear) as? Bool
        let initialMax = storedMax == 0 ? maxItems : storedMax
        self.maxItemsLimit = min(max(initialMax, 1), maxLimit)
        self.retentionDays = max(storedRetention, 0)
        self.keepPinnedOnClear = storedKeepPinned ?? true
        self.changeCount = pasteboard.changeCount
        load()
        applyRetentionPolicy()
        updateDerivedData()
    }

    deinit {
        pollingTask?.cancel()
        metadataTasks.values.forEach { $0.cancel() }
    }

    var filteredItems: [ClipboardItem] {
        let criteria = SearchCriteria.parse(from: searchQuery)
        let sortedItems = ordered(items)
        guard !criteria.isEmpty else { return sortedItems }

        return sortedItems.filter { item in
            criteria.matches(item: item)
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

    func clearAll(keepingPinned: Bool) {
        if keepingPinned {
            clearUnpinned()
        } else {
            items.removeAll()
            save()
        }
    }

    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        if items[index].isPinned {
            items[index].pinnedOrder = nextPinnedOrder()
        } else {
            items[index].pinnedOrder = nil
        }
        save()
    }

    func reorderPinned(from offsets: IndexSet, to destination: Int) {
        var pinned = ordered(items).filter(\.isPinned)
        pinned.move(fromOffsets: offsets, toOffset: destination)
        for (index, id) in pinned.map(\.id).enumerated() {
            if let itemIndex = items.firstIndex(where: { $0.id == id }) {
                items[itemIndex].pinnedOrder = index
            }
        }
        save()
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                    guard let self, let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor in
                        self.addFileItem(urls: [url])
                    }
                }
                handled = true
            } else if provider.canLoadObject(ofClass: NSURL.self) {
                _ = provider.loadObject(ofClass: NSURL.self) { [weak self] item, _ in
                    guard let self, let url = item as? URL else { return }
                    Task { @MainActor in
                        self.addFileItem(urls: [url])
                    }
                }
                handled = true
            } else if provider.canLoadObject(ofClass: NSString.self) {
                _ = provider.loadObject(ofClass: NSString.self) { [weak self] item, _ in
                    guard let self, let string = item as? String else { return }
                    Task { @MainActor in
                        self.addTextItem(text: string)
                    }
                }
                handled = true
            } else if provider.canLoadObject(ofClass: NSImage.self) {
                _ = provider.loadObject(ofClass: NSImage.self) { [weak self] item, _ in
                    guard let self, let image = item as? NSImage,
                          let tiff = image.tiffRepresentation else { return }
                    Task { @MainActor in
                        self.addImageItem(tiffData: tiff, size: image.size)
                    }
                }
                handled = true
            }
        }
        return handled
    }

    func itemProvider(for item: ClipboardItem) -> NSItemProvider {
        switch item.kind {
        case .text:
            return NSItemProvider(object: item.displayText as NSString)
        case .url:
            if let url = URL(string: item.displayText) {
                return NSItemProvider(object: url as NSURL)
            }
            return NSItemProvider(object: item.displayText as NSString)
        case .rtf:
            if let base64 = item.rawDataBase64, let data = Data(base64Encoded: base64) {
                return NSItemProvider(item: data as NSSecureCoding, typeIdentifier: UTType.rtf.identifier)
            }
            return NSItemProvider(object: item.displayText as NSString)
        case .html:
            if let base64 = item.rawDataBase64, let data = Data(base64Encoded: base64) {
                return NSItemProvider(item: data as NSSecureCoding, typeIdentifier: UTType.html.identifier)
            }
            return NSItemProvider(object: item.displayText as NSString)
        case .image:
            if let base64 = item.rawDataBase64, let data = Data(base64Encoded: base64), let image = NSImage(data: data) {
                return NSItemProvider(object: image)
            }
            return NSItemProvider(object: item.displayText as NSString)
        case .files:
            if let path = item.filePaths?.first {
                return NSItemProvider(object: URL(fileURLWithPath: path) as NSURL)
            }
            return NSItemProvider(object: item.displayText as NSString)
        }
    }

    private func addTextItem(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = ClipboardItem(kind: .text, displayText: trimmed)
        items.insert(item, at: 0)
        applyRetentionPolicy()
        enforceLimit()
        save()
    }

    private func addFileItem(urls: [URL]) {
        guard !urls.isEmpty else { return }
        let paths = urls.map(\.path)
        let item = ClipboardItem(kind: .files, displayText: "\(paths.count) file(s)", filePaths: paths)
        items.insert(item, at: 0)
        applyRetentionPolicy()
        enforceLimit()
        save()
    }

    private func addImageItem(tiffData: Data, size: CGSize) {
        let preview = "Image \(Int(size.width))x\(Int(size.height))"
        let item = ClipboardItem(kind: .image, displayText: preview, rawDataBase64: tiffData.base64EncodedString())
        items.insert(item, at: 0)
        applyRetentionPolicy()
        enforceLimit()
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
            if newItem.kind == .url {
                fetchURLMetadata(for: newItem)
            }
        }

        applyRetentionPolicy()
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
        let maxItems = min(max(maxItemsLimit, 1), maxLimit)
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
            sortPinnedFirst($0, $1)
        }
    }

    private func ordered(_ input: [ClipboardItem]) -> [ClipboardItem] {
        input.sorted {
            sortPinnedFirst($0, $1)
        }
    }

    private func sortPinnedFirst(_ lhs: ClipboardItem, _ rhs: ClipboardItem) -> Bool {
        if lhs.isPinned != rhs.isPinned {
            return lhs.isPinned && !rhs.isPinned
        }
        if lhs.isPinned, rhs.isPinned {
            let leftOrder = lhs.pinnedOrder ?? 0
            let rightOrder = rhs.pinnedOrder ?? 0
            if leftOrder != rightOrder {
                return leftOrder < rightOrder
            }
        }
        return lhs.copiedAt > rhs.copiedAt
    }

    private func nextPinnedOrder() -> Int {
        let maxOrder = items.compactMap(\.pinnedOrder).max() ?? -1
        return maxOrder + 1
    }

    private func load() {
        guard let data = try? Data(contentsOf: persistenceURL) else { return }
        guard let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else { return }
        items = decoded
        ensurePinnedOrder()
        fetchMissingURLMetadata()
        enforceLimit()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: persistenceURL, options: .atomic)
    }

    private func handleSettingsChange() {
        let normalizedMax = min(max(maxItemsLimit, 1), maxLimit)
        if normalizedMax != maxItemsLimit {
            maxItemsLimit = normalizedMax
            return
        }
        let normalizedRetention = max(retentionDays, 0)
        if normalizedRetention != retentionDays {
            retentionDays = normalizedRetention
            return
        }
        defaults.set(maxItemsLimit, forKey: SettingsKey.maxItemsLimit)
        defaults.set(retentionDays, forKey: SettingsKey.retentionDays)
        defaults.set(keepPinnedOnClear, forKey: SettingsKey.keepPinnedOnClear)
        applyRetentionPolicy()
        enforceLimit()
        save()
    }

    private func applyRetentionPolicy() {
        guard retentionDays > 0 else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: .now) ?? .distantPast
        items.removeAll { !$0.isPinned && $0.copiedAt < cutoff }
    }

    private func updateDerivedData() {
        storageUsageBytes = items.reduce(0) { partial, item in
            partial + item.estimatedStorageBytes
        }
        stats = ClipboardStats(items: items)
    }

    private func ensurePinnedOrder() {
        var order = 0
        for index in items.indices {
            if items[index].isPinned {
                if items[index].pinnedOrder == nil {
                    items[index].pinnedOrder = order
                }
                order += 1
            }
        }
    }

    private func fetchURLMetadata(for item: ClipboardItem) {
        guard let url = URL(string: item.displayText) else { return }
        metadataTasks[item.id]?.cancel()
        metadataTasks[item.id] = Task { [weak self] in
            guard let self else { return }
            let provider = LPMetadataProvider()
            do {
                let metadata = try await provider.startFetchingMetadata(for: url)
                await MainActor.run {
                    self.applyMetadata(metadata, for: item.id)
                }
            } catch {
                await MainActor.run {
                    self.metadataTasks[item.id] = nil
                }
            }
        }
    }

    private func fetchMissingURLMetadata() {
        for item in items where item.kind == .url && item.urlTitle == nil {
            fetchURLMetadata(for: item)
        }
    }

    private func applyMetadata(_ metadata: LPLinkMetadata, for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if let title = metadata.title, !title.isEmpty {
            items[index].urlTitle = title
        }
        if let provider = metadata.imageProvider {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.png.identifier) { [weak self] data, _ in
                guard let self, let data else { return }
                Task { @MainActor in
                    guard let index = self.items.firstIndex(where: { $0.id == id }) else { return }
                    self.items[index].urlThumbnailBase64 = data.base64EncodedString()
                    self.save()
                }
            }
        }
        metadataTasks[id] = nil
        save()
    }
}

private enum SettingsKey {
    static let maxItemsLimit = "settings.maxItemsLimit"
    static let retentionDays = "settings.retentionDays"
    static let keepPinnedOnClear = "settings.keepPinnedOnClear"
}

struct ClipboardStats: Equatable {
    let copiedThisWeek: Int
    let mostCopiedKind: ClipboardKind?
    let mostCopiedPercentage: Int
    let oldestItemAgeDays: Int?

    static let empty = ClipboardStats(copiedThisWeek: 0, mostCopiedKind: nil, mostCopiedPercentage: 0, oldestItemAgeDays: nil)

    init(copiedThisWeek: Int, mostCopiedKind: ClipboardKind?, mostCopiedPercentage: Int, oldestItemAgeDays: Int?) {
        self.copiedThisWeek = copiedThisWeek
        self.mostCopiedKind = mostCopiedKind
        self.mostCopiedPercentage = mostCopiedPercentage
        self.oldestItemAgeDays = oldestItemAgeDays
    }

    init(items: [ClipboardItem]) {
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        copiedThisWeek = items.filter { $0.copiedAt >= weekStart }.count

        let total = items.count
        let grouped = Dictionary(grouping: items, by: \.kind)
        if let (kind, group) = grouped.max(by: { $0.value.count < $1.value.count }) {
            mostCopiedKind = kind
            mostCopiedPercentage = total == 0 ? 0 : Int((Double(group.count) / Double(total)) * 100.0)
        } else {
            mostCopiedKind = nil
            mostCopiedPercentage = 0
        }

        if let oldest = items.min(by: { $0.copiedAt < $1.copiedAt }) {
            let days = Calendar.current.dateComponents([.day], from: oldest.copiedAt, to: .now).day ?? 0
            oldestItemAgeDays = max(days, 0)
        } else {
            oldestItemAgeDays = nil
        }
    }
}

private struct SearchCriteria {
    let text: String
    let typeFilter: ClipboardKind?
    let dateRange: DateInterval?

    var isEmpty: Bool {
        text.isEmpty && typeFilter == nil && dateRange == nil
    }

    static func parse(from query: String) -> SearchCriteria {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return SearchCriteria(text: "", typeFilter: nil, dateRange: nil)
        }

        let tokens = normalized.split(separator: " ").map(String.init)
        var remainingTokens: [String] = []
        var typeFilter: ClipboardKind?
        var startDate: Date?
        var endDate: Date?

        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.dateFormat = "yyyy-MM-dd"

        for token in tokens {
            let lower = token.lowercased()
            if lower.hasPrefix("type:") {
                let value = lower.replacingOccurrences(of: "type:", with: "")
                typeFilter = ClipboardKind.searchable(from: value) ?? typeFilter
                continue
            }
            if lower.hasPrefix("from:"), let date = formatter.date(from: String(lower.dropFirst(5))) {
                startDate = date
                continue
            }
            if lower.hasPrefix("to:"), let date = formatter.date(from: String(lower.dropFirst(3))) {
                endDate = date
                continue
            }
            switch lower {
            case "yesterday":
                let start = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now))
                let end = Calendar.current.startOfDay(for: .now)
                startDate = start
                endDate = end
            case "today":
                let start = Calendar.current.startOfDay(for: .now)
                let end = Calendar.current.date(byAdding: .day, value: 1, to: start)
                startDate = start
                endDate = end
            case "last7days":
                let start = Calendar.current.date(byAdding: .day, value: -7, to: .now)
                startDate = start
                endDate = .now
            case "last30days":
                let start = Calendar.current.date(byAdding: .day, value: -30, to: .now)
                startDate = start
                endDate = .now
            default:
                if typeFilter == nil, let kind = ClipboardKind.searchable(from: lower) {
                    typeFilter = kind
                } else {
                    remainingTokens.append(token)
                }
            }
        }

        let dateRange: DateInterval?
        if let startDate {
            dateRange = DateInterval(start: startDate, end: endDate ?? .now)
        } else {
            dateRange = nil
        }

        return SearchCriteria(text: remainingTokens.joined(separator: " "), typeFilter: typeFilter, dateRange: dateRange)
    }

    func matches(item: ClipboardItem) -> Bool {
        if let typeFilter, item.kind != typeFilter {
            return false
        }
        if let dateRange, !dateRange.contains(item.copiedAt) {
            return false
        }
        guard !text.isEmpty else { return true }
        let haystack = item.searchableText.lowercased()
        let needle = text.lowercased()
        if haystack.localizedCaseInsensitiveContains(needle) {
            return true
        }
        return haystack.fuzzyContains(needle)
    }
}

private extension ClipboardKind {
    static func searchable(from token: String) -> ClipboardKind? {
        switch token.lowercased() {
        case "text": return .text
        case "url", "urls", "link", "links": return .url
        case "rtf": return .rtf
        case "html": return .html
        case "image", "images", "img": return .image
        case "file", "files": return .files
        default: return nil
        }
    }
}

private extension String {
    func fuzzyContains(_ query: String, maxDistance: Int = 2) -> Bool {
        guard !query.isEmpty else { return true }
        let words = split(whereSeparator: \.isWhitespace).map(String.init)
        for word in words {
            if word.localizedCaseInsensitiveContains(query) {
                return true
            }
            if word.levenshteinDistance(to: query) <= maxDistance {
                return true
            }
            if word.isSubsequence(of: query) || query.isSubsequence(of: word) {
                return true
            }
        }
        return false
    }

    func levenshteinDistance(to target: String) -> Int {
        let source = Array(lowercased())
        let target = Array(target.lowercased())
        guard !source.isEmpty else { return target.count }
        guard !target.isEmpty else { return source.count }

        var previousRow = Array(0...target.count)
        for (i, sourceChar) in source.enumerated() {
            var currentRow = [i + 1]
            for (j, targetChar) in target.enumerated() {
                let cost = sourceChar == targetChar ? 0 : 1
                let insertion = currentRow[j] + 1
                let deletion = previousRow[j + 1] + 1
                let substitution = previousRow[j] + cost
                currentRow.append(Swift.min(insertion, deletion, substitution))
            }
            previousRow = currentRow
        }
        return previousRow[target.count]
    }

    func isSubsequence(of other: String) -> Bool {
        var otherIterator = other.lowercased().makeIterator()
        for char in lowercased() {
            var matched = false
            while let next = otherIterator.next() {
                if next == char {
                    matched = true
                    break
                }
            }
            if !matched { return false }
        }
        return true
    }
}

private extension ClipboardItem {
    var estimatedStorageBytes: Int {
        var total = displayText.utf8.count
        if let rawDataBase64, let data = Data(base64Encoded: rawDataBase64) {
            total += data.count
        }
        if let urlTitle {
            total += urlTitle.utf8.count
        }
        if let urlThumbnailBase64, let data = Data(base64Encoded: urlThumbnailBase64) {
            total += data.count
        }
        if let filePaths {
            total += filePaths.reduce(0) { $0 + $1.utf8.count }
        }
        return total
    }
}
