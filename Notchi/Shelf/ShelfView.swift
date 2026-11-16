import AppKit
import QuickLookThumbnailing
import SwiftUI

struct ShelfView: View {
    @ObservedObject var shelf: ShelfStore
    @Binding var previewURL: URL?

    var body: some View {
        Group {
            if shelf.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 20))
                    Text("Drag files here to keep them handy")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(shelf.items) { item in
                            ShelfCard(item: item)
                                .onDrag { NSItemProvider(object: item.url as NSURL) }
                                .onTapGesture(count: 2) { NSWorkspace.shared.open(item.url) }
                                .onTapGesture { preview(item) }
                                .contextMenu { menu(for: item) }
                        }
                    }
                }
            }
        }
        .onAppear { shelf.removeMissing() }
    }

    @ViewBuilder
    private func menu(for item: ShelfItem) -> some View {
        Button("Quick Look") { preview(item) }
        Button("Open") { NSWorkspace.shared.open(item.url) }
        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
        Divider()
        Button("Remove from Shelf", role: .destructive) { shelf.remove(item) }
    }

    private func preview(_ item: ShelfItem) {
        NSApp.activate()
        previewURL = item.url
    }
}

private struct ShelfCard: View {
    let item: ShelfItem
    @State private var thumbnail: NSImage?
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: thumbnail ?? NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 44, height: 44)

            Text(item.name)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .padding(8)
        .frame(width: 92, height: 92)
        .background(Color.white.opacity(isHovered ? 0.14 : 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
        .task(id: item.url) { thumbnail = await loadThumbnail() }
    }

    private func loadThumbnail() async -> NSImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: item.url,
            size: CGSize(width: 88, height: 88),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .all
        )
        let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
        return representation?.nsImage
    }
}
