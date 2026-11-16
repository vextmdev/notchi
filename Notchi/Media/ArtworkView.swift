import SwiftUI

struct ArtworkView: View {
    let url: URL?
    var cornerRadius: CGFloat = 12
    var symbolSize: CGFloat = 22

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            Color.white.opacity(0.08)
            Image(systemName: "music.note")
                .font(.system(size: symbolSize))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}
