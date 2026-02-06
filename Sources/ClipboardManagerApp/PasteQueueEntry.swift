import Foundation

struct PasteQueueEntry: Identifiable, Equatable, Codable {
    let id: UUID
    var item: ClipboardItem
    var addedAt: Date
    var sourceItemID: UUID?

    init(id: UUID = UUID(), item: ClipboardItem, addedAt: Date = .now, sourceItemID: UUID? = nil) {
        self.id = id
        self.item = item
        self.addedAt = addedAt
        self.sourceItemID = sourceItemID
    }
}
