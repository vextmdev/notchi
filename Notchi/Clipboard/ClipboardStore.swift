import AppKit

// history lives in ~/Library/Application Support/Notchi/Clipboard
// text goes into history.json, images get their own png next to it
final class ClipboardStore {
    private struct Record: Codable {
        let id: UUID
        var text: String?
        var image: String?
        var date: Date
        var isPinned: Bool
    }

    private let folder: URL
    private let imagesFolder: URL
    private let historyFile: URL
    private let queue = DispatchQueue(label: "notchi.clipboard-store", qos: .utility)

    // images already on disk, so we don't re-encode them on every save
    private var savedImages: Set<UUID> = []

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        folder = support.appendingPathComponent("Notchi/Clipboard", isDirectory: true)
        imagesFolder = folder.appendingPathComponent("Images", isDirectory: true)
        historyFile = folder.appendingPathComponent("history.json")
    }

    func load() -> [ClipboardItem] {
        guard let data = try? Data(contentsOf: historyFile),
              let records = try? JSONDecoder().decode([Record].self, from: data)
        else { return [] }

        return records.compactMap { record in
            let content: ClipboardItem.Content
            if let text = record.text {
                content = .text(text)
            } else if let name = record.image,
                      let image = NSImage(contentsOf: imagesFolder.appendingPathComponent(name)) {
                content = .image(image)
                savedImages.insert(record.id)
            } else {
                return nil // image file is gone, skip it
            }
            return ClipboardItem(id: record.id, content: content, date: record.date, isPinned: record.isPinned)
        }
    }

    func save(_ items: [ClipboardItem], wait: Bool = false) {
        var records: [Record] = []
        var newImages: [(name: String, tiff: Data)] = []

        for item in items {
            var record = Record(id: item.id, date: item.date, isPinned: item.isPinned)
            switch item.content {
            case .text(let text):
                record.text = text
            case .image(let image):
                let name = "\(item.id.uuidString).png"
                record.image = name
                if !savedImages.contains(item.id) {
                    guard let tiff = image.tiffRepresentation else { continue }
                    newImages.append((name, tiff))
                    savedImages.insert(item.id)
                }
            }
            records.append(record)
        }

        let keep = Set(records.compactMap(\.image))
        savedImages = Set(items.map(\.id)).intersection(savedImages)

        let work = { [imagesFolder, historyFile] in
            let fm = FileManager.default
            try? fm.createDirectory(at: imagesFolder, withIntermediateDirectories: true)

            // png encoding is the slow part, that's why this runs off the main thread
            for image in newImages {
                guard let png = NSBitmapImageRep(data: image.tiff)?.representation(using: .png, properties: [:]) else { continue }
                try? png.write(to: imagesFolder.appendingPathComponent(image.name), options: .atomic)
            }

            if let data = try? JSONEncoder().encode(records) {
                try? data.write(to: historyFile, options: .atomic)
            }

            // clean up images of deleted items
            let files = (try? fm.contentsOfDirectory(atPath: imagesFolder.path)) ?? []
            for file in files where !keep.contains(file) {
                try? fm.removeItem(at: imagesFolder.appendingPathComponent(file))
            }
        }

        if wait { queue.sync(execute: work) } else { queue.async(execute: work) }
    }

    func clear() {
        savedImages.removeAll()
        queue.async { [folder] in
            try? FileManager.default.removeItem(at: folder)
        }
    }
}
