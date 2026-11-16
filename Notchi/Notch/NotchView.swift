import SwiftUI

struct NotchView: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var clipboard: ClipboardMonitor
    @ObservedObject var media: MediaController

    private var currentSize: CGSize {
        model.isExpanded ? model.expandedSize : model.notchSize
    }

    private var cornerRadius: CGFloat {
        model.isExpanded ? 28 : 10
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                NotchShape(bottomRadius: cornerRadius)
                    .fill(Color.black)

                if model.isExpanded {
                    ExpandedContent(clipboard: clipboard, media: media)
                        .padding(.top, model.notchSize.height + 6)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                }
            }
            .frame(width: currentSize.width, height: currentSize.height)
            .clipShape(NotchShape(bottomRadius: cornerRadius))

            Spacer(minLength: 0)
        }
        .frame(width: model.expandedSize.width, height: model.expandedSize.height, alignment: .top)
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: model.isExpanded)
        .environment(\.colorScheme, .dark)
    }
}

private struct ExpandedContent: View {
    @ObservedObject var clipboard: ClipboardMonitor
    @ObservedObject var media: MediaController

    var body: some View {
        HStack(spacing: 16) {
            MediaView(media: media)
                .frame(width: 210)

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1)

            ClipboardView(clipboard: clipboard)
        }
    }
}
