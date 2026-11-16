import Foundation

@MainActor
final class ShelfStore: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []

    private let defaultsKey = "shelfBookmarks"

    init() {
        load()
    }

    func add(_ urls: [URL]) {
        var known = Set(items.map { $0.url.standardizedFileURL })
        for url in urls where url.isFileURL {
            let url = url.standardizedFileURL
            guard !known.contains(url) else { continue }
            known.insert(url)
            items.append(ShelfItem(url: url))
        }
        save()
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    // files might get deleted or moved to the trash while they're on the shelf
    func removeMissing() {
        let before = items.count
        items.removeAll { !FileManager.default.fileExists(atPath: $0.url.path) }
        if items.count != before { save() }
    }

    // MARK: - Persistence

    // bookmarks instead of paths so files still resolve after being renamed or moved
    private func save() {
        let bookmarks = items.compactMap { try? $0.url.bookmarkData() }
        UserDefaults.standard.set(bookmarks, forKey: defaultsKey)
    }

    private func load() {
        guard let bookmarks = UserDefaults.standard.array(forKey: defaultsKey) as? [Data] else { return }
        items = bookmarks.compactMap { data in
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale),
                  FileManager.default.fileExists(atPath: url.path) else { return nil }
            return ShelfItem(url: url)
        }
    }
}
