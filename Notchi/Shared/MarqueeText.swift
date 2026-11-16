import SwiftUI

// scrolls the text when it doesn't fit, otherwise just shows it
struct MarqueeText: View {
    let text: String
    let font: Font
    var color: Color = .white

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var startDate = Date()

    private let gap: CGFloat = 30
    private let speed: Double = 28
    private let pause: Double = 1.5

    private var overflows: Bool { textWidth > containerWidth + 1 }

    var body: some View {
        // invisible line that only gives us the height, the width comes from the parent
        Text(text)
            .font(font)
            .lineLimit(1)
            .opacity(0)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .background(widthReader { containerWidth = $0 })
            .overlay(alignment: .leading) {
                TimelineView(.animation(paused: !overflows)) { context in
                    HStack(spacing: gap) {
                        label.background(widthReader { textWidth = $0 })
                        if overflows { label }
                    }
                    .offset(x: overflows ? -offset(at: context.date) : 0)
                }
            }
            .clipped()
            .mask { edgeFade }
            .onChange(of: text) { startDate = Date() }
    }

    private var label: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
    }

    // pause at the start, then scroll one full loop
    private func offset(at date: Date) -> CGFloat {
        let distance = textWidth + gap
        let cycle = pause + Double(distance) / speed
        let t = date.timeIntervalSince(startDate).truncatingRemainder(dividingBy: cycle)
        return t < pause ? 0 : CGFloat((t - pause) * speed)
    }

    private var edgeFade: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: overflows ? 6 : 0)
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: overflows ? 12 : 0)
        }
    }

    private func widthReader(_ update: @escaping (CGFloat) -> Void) -> some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { update(proxy.size.width) }
                .onChange(of: proxy.size.width) { _, width in update(width) }
        }
    }
}
