import QuickLook
import SwiftUI

struct NotchView: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var clipboard: ClipboardMonitor
    @ObservedObject var media: MediaController
    @ObservedObject var shelf: ShelfStore

    // only here so the view redraws when the setting changes
    @AppStorage(Preferences.showNowPlaying) private var showNowPlayingSetting = true

    private var currentSize: CGSize {
        model.isExpanded ? model.expandedSize : model.collapsedSize
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
                    ExpandedContent(model: model, clipboard: clipboard, media: media, shelf: shelf)
                        .padding(.top, model.notchSize.height + 6)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                } else if model.isNowPlayingVisible {
                    NowPlayingWings(
                        media: media,
                        wingWidth: model.nowPlayingWingWidth,
                        height: model.notchSize.height
                    )
                    .transition(.opacity)
                }
            }
            .frame(width: currentSize.width, height: currentSize.height)
            .clipShape(NotchShape(bottomRadius: cornerRadius))

            Spacer(minLength: 0)
        }
        .frame(width: model.expandedSize.width, height: model.expandedSize.height, alignment: .top)
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: model.isExpanded)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: model.isNowPlayingVisible)
        .environment(\.colorScheme, .dark)
        // lives up here so the preview stays open when the notch collapses
        .quickLookPreview($model.previewURL)
    }
}

// artwork on the left of the notch, bars on the right
private struct NowPlayingWings: View {
    @ObservedObject var media: MediaController
    let wingWidth: CGFloat
    let height: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ArtworkView(url: media.artworkURL, cornerRadius: 5, symbolSize: 10)
                .frame(width: 20, height: 20)
                .frame(width: wingWidth)

            Spacer(minLength: 0)

            EqualizerBars(isAnimating: media.isPlaying)
                .frame(width: wingWidth)
        }
        .frame(height: height)
    }
}
