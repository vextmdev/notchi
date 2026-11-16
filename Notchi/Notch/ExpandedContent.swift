import SwiftUI

struct ExpandedContent: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var clipboard: ClipboardMonitor
    @ObservedObject var media: MediaController
    @ObservedObject var shelf: ShelfStore

    @State private var query = ""

    var body: some View {
        HStack(spacing: 16) {
            MediaView(media: media)
                .frame(width: 210)

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1)

            // fixed heights so switching tabs never shifts anything around
            VStack(alignment: .leading, spacing: 8) {
                header
                    .frame(height: 22)

                Group {
                    switch model.selectedTab {
                    case .clipboard:
                        ClipboardView(clipboard: clipboard, query: query)
                    case .shelf:
                        ShelfView(shelf: shelf, previewURL: $model.previewURL)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 92, maxHeight: 92, alignment: .topLeading)
                .clipped()
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .overlay {
            if model.isDropTargeted {
                DropHint().transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: model.isDropTargeted)
        .contentShape(Rectangle())
        .dropDestination(for: URL.self) { urls, _ in
            let files = urls.filter(\.isFileURL)
            guard !files.isEmpty else { return false }
            shelf.add(files)
            model.selectedTab = .shelf
            return true
        } isTargeted: { isTargeted in
            model.isDropTargeted = isTargeted
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            TabButton(
                title: "Clipboard",
                symbol: "doc.on.clipboard",
                isSelected: model.selectedTab == .clipboard
            ) { model.selectedTab = .clipboard }

            TabButton(
                title: shelf.items.isEmpty ? "Shelf" : "Shelf \(shelf.items.count)",
                symbol: "tray",
                isSelected: model.selectedTab == .shelf
            ) { model.selectedTab = .shelf }

            Spacer()

            if model.selectedTab == .clipboard {
                TextField("Search", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .frame(width: 110)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08), in: Capsule())
            } else if !shelf.items.isEmpty {
                Button("Clear") { shelf.clear() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Button(action: model.openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
    }
}

private struct TabButton: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(isSelected ? 0.95 : 0.45))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(isSelected ? 0.1 : 0), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct DropHint: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        shape
            .fill(Color.black.opacity(0.8))
            .overlay(shape.strokeBorder(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
            .overlay(
                Label("Drop to add to shelf", systemImage: "tray.and.arrow.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}
