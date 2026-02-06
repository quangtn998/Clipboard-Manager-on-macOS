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
    var copiedAt: Date
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        kind: ClipboardKind,
        displayText: String,
        rawDataBase64: String? = nil,
        filePaths: [String]? = nil,
        copiedAt: Date = .now,
        isPinned: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.displayText = displayText
        self.rawDataBase64 = rawDataBase64
        self.filePaths = filePaths
        self.copiedAt = copiedAt
        self.isPinned = isPinned
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
        return "\(kind.displayName) \(displayText) \(files)"
    }

    var previewText: String {
        if kind == .files, let files = filePaths, !files.isEmpty {
            return files.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", ")
        }
        return displayText
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, displayText, rawDataBase64, filePaths, copiedAt, isPinned
        case legacyContent = "content"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        copiedAt = try container.decodeIfPresent(Date.self, forKey: .copiedAt) ?? .now
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false

        if let kind = try container.decodeIfPresent(ClipboardKind.self, forKey: .kind) {
            self.kind = kind
            displayText = try container.decodeIfPresent(String.self, forKey: .displayText) ?? ""
            rawDataBase64 = try container.decodeIfPresent(String.self, forKey: .rawDataBase64)
            filePaths = try container.decodeIfPresent([String].self, forKey: .filePaths)
        } else {
            let legacy = try container.decodeIfPresent(String.self, forKey: .legacyContent) ?? ""
            self.kind = .text
            displayText = legacy
            rawDataBase64 = nil
            filePaths = nil
        }
    }
}
