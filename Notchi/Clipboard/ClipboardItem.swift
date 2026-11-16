import AppKit

struct ClipboardItem: Identifiable {
    enum Content {
        case text(String)
        case image(NSImage)
    }

    let id = UUID()
    let content: Content
    var date: Date
    var isPinned = false

    var text: String? {
        if case .text(let value) = content { return value }
        return nil
    }
}
