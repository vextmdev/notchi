import SwiftUI

// fixed square box, the image gets cropped to fit and never spills out
struct ArtworkView: View {
    let url: URL?
    var size: CGFloat = 64
    var cornerRadius: CGFloat = 12
    var symbolSize: CGFloat = 22

    var body: some View {
        ZStack {
            Color.white.opacity(0.08)

            if let url {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    note
                }
            } else {
                note
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var note: some View {
        Image(systemName: "music.note")
            .font(.system(size: symbolSize))
            .foregroundStyle(.white.opacity(0.5))
    }
}
