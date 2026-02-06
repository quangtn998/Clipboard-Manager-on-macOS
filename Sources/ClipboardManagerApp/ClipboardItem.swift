import Foundation

struct ClipboardItem: Identifiable, Equatable, Codable {
    let id: UUID
    var content: String
    var copiedAt: Date
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        content: String,
        copiedAt: Date = .now,
        isPinned: Bool = false
    ) {
        self.id = id
        self.content = content
        self.copiedAt = copiedAt
        self.isPinned = isPinned
    }
}
