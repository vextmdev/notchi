import AppKit

struct ClipboardItem: Identifiable {
    enum Content {
        case text(String)
        case image(NSImage)
    }

    let id: UUID
    let content: Content
    var date: Date
    var isPinned: Bool

    init(id: UUID = UUID(), content: Content, date: Date, isPinned: Bool = false) {
        self.id = id
        self.content = content
        self.date = date
        self.isPinned = isPinned
    }

    var text: String? {
        if case .text(let value) = content { return value }
        return nil
    }
}
