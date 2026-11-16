import SwiftUI

struct ClipboardView: View {
    @ObservedObject var clipboard: ClipboardMonitor
    let query: String
    @State private var copiedID: UUID?

    private var visibleItems: [ClipboardItem] {
        let filtered = clipboard.items.filter { item in
            guard !query.isEmpty else { return true }
            return item.text?.localizedCaseInsensitiveContains(query) ?? false
        }
        return filtered.filter(\.isPinned) + filtered.filter { !$0.isPinned }
    }

    var body: some View {
        if visibleItems.isEmpty {
            Text(query.isEmpty ? "Copy something to see it here" : "No matches")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 8) {
                    ForEach(visibleItems) { item in
                        ClipboardCard(item: item, isCopied: copiedID == item.id)
                            .onTapGesture { copy(item) }
                            .contextMenu {
                                Button(item.isPinned ? "Unpin" : "Pin") { clipboard.togglePin(item) }
                                Button("Delete", role: .destructive) { clipboard.remove(item) }
                            }
                    }
                }
            }
        }
    }

    private func copy(_ item: ClipboardItem) {
        clipboard.copy(item)
        copiedID = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedID == item.id { copiedID = nil }
        }
    }
}

private struct ClipboardCard: View {
    let item: ClipboardItem
    let isCopied: Bool
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
                .frame(width: 110, height: 92, alignment: .topLeading)
                .background(Color.white.opacity(isHovered ? 0.14 : 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.yellow)
                    .padding(6)
            }

            if isCopied {
                Text("Copied")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white, in: Capsule())
                    .frame(width: 110, height: 92)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.easeOut(duration: 0.15), value: isCopied)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var content: some View {
        switch item.content {
        case .text(let text):
            Text(preview(of: text))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
                .lineLimit(5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(8)
        case .image(let image):
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 110, height: 92)
                .clipped()
        }
    }

    // big copies (code, logs) are slow to lay out and look messy, so only show a cleaned up start
    private func preview(of text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.prefix(300)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.joined(separator: "\n")
    }
}
