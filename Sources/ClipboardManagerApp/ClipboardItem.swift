import Foundation

enum ClipboardKind: String, Codable {
    case text
    case url
    case rtf
    case html
    case image
    case files

    var displayName: String {
        switch self {
        case .text: "Text"
        case .url: "URL"
        case .rtf: "RTF"
        case .html: "HTML"
        case .image: "Image"
        case .files: "Files"
        }
    }
}

struct ClipboardItem: Identifiable, Equatable, Codable {
    let id: UUID
    var kind: ClipboardKind
    var displayText: String
    var rawDataBase64: String?
    var filePaths: [String]?
    var urlTitle: String?
    var urlThumbnailBase64: String?
    var copiedAt: Date
    var isPinned: Bool
    var pinnedOrder: Int?

    init(
        id: UUID = UUID(),
        kind: ClipboardKind,
        displayText: String,
        rawDataBase64: String? = nil,
        filePaths: [String]? = nil,
        urlTitle: String? = nil,
        urlThumbnailBase64: String? = nil,
        copiedAt: Date = .now,
        isPinned: Bool = false,
        pinnedOrder: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.displayText = displayText
        self.rawDataBase64 = rawDataBase64
        self.filePaths = filePaths
        self.urlTitle = urlTitle
        self.urlThumbnailBase64 = urlThumbnailBase64
        self.copiedAt = copiedAt
        self.isPinned = isPinned
        self.pinnedOrder = pinnedOrder
    }

    var dedupeKey: String {
        switch kind {
        case .files:
            return "\(kind.rawValue):\((filePaths ?? []).joined(separator: "|"))"
        default:
            return "\(kind.rawValue):\(rawDataBase64 ?? displayText)"
        }
    }

    var searchableText: String {
        let files = filePaths?.joined(separator: " ") ?? ""
        let title = urlTitle ?? ""
        return "\(kind.displayName) \(displayText) \(title) \(files)"
    }

    var previewText: String {
        if kind == .files, let files = filePaths, !files.isEmpty {
            return files.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", ")
        }
        return displayText
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, displayText, rawDataBase64, filePaths, urlTitle, urlThumbnailBase64, copiedAt, isPinned, pinnedOrder
        case legacyContent = "content"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(displayText, forKey: .displayText)
        try container.encodeIfPresent(rawDataBase64, forKey: .rawDataBase64)
        try container.encodeIfPresent(filePaths, forKey: .filePaths)
        try container.encodeIfPresent(urlTitle, forKey: .urlTitle)
        try container.encodeIfPresent(urlThumbnailBase64, forKey: .urlThumbnailBase64)
        try container.encode(copiedAt, forKey: .copiedAt)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encodeIfPresent(pinnedOrder, forKey: .pinnedOrder)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        copiedAt = try container.decodeIfPresent(Date.self, forKey: .copiedAt) ?? .now
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        pinnedOrder = try container.decodeIfPresent(Int.self, forKey: .pinnedOrder)

        if let kind = try container.decodeIfPresent(ClipboardKind.self, forKey: .kind) {
            self.kind = kind
            displayText = try container.decodeIfPresent(String.self, forKey: .displayText) ?? ""
            rawDataBase64 = try container.decodeIfPresent(String.self, forKey: .rawDataBase64)
            filePaths = try container.decodeIfPresent([String].self, forKey: .filePaths)
            urlTitle = try container.decodeIfPresent(String.self, forKey: .urlTitle)
            urlThumbnailBase64 = try container.decodeIfPresent(String.self, forKey: .urlThumbnailBase64)
        } else {
            let legacy = try container.decodeIfPresent(String.self, forKey: .legacyContent) ?? ""
            self.kind = .text
            displayText = legacy
            rawDataBase64 = nil
            filePaths = nil
            urlTitle = nil
            urlThumbnailBase64 = nil
        }
    }
}
