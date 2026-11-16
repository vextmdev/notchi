import SwiftUI

struct MediaView: View {
    @ObservedObject var media: MediaController

    var body: some View {
        HStack(spacing: 12) {
            artwork
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(media.title ?? "Nothing playing")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

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

    @ViewBuilder
    private var artwork: some View {
        if let url = media.artworkURL {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                placeholder
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.white.opacity(0.08)
            Image(systemName: "music.note")
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.5))
        }
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
