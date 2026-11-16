import SwiftUI

struct MediaView: View {
    @ObservedObject var media: MediaController

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: media.artworkURL)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                MarqueeText(
                    text: media.title ?? "Nothing playing",
                    font: .system(size: 13, weight: .semibold)
                )

                Text(media.artist ?? "Open Spotify or Music")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)

                HStack(spacing: 16) {
                    ControlButton(symbol: "backward.fill", size: 13) { media.previous() }
                    ControlButton(symbol: media.isPlaying ? "pause.fill" : "play.fill", size: 17) { media.playPause() }
                    ControlButton(symbol: "forward.fill", size: 13) { media.next() }
                }
                .padding(.top, 4)
                .disabled(media.activePlayer == nil)
                .opacity(media.activePlayer == nil ? 0.35 : 1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
    }
}

private struct ControlButton: View {
    let symbol: String
    let size: CGFloat
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white.opacity(isHovered ? 1 : 0.85))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
