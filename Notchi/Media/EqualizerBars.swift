import SwiftUI

struct EqualizerBars: View {
    var isAnimating: Bool
    var barCount = 4
    var maxHeight: CGFloat = 12

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isAnimating)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 2.5, height: maxHeight * level(for: index, at: time))
                }
            }
            .frame(height: maxHeight)
        }
    }

    // each bar gets its own speed so they don't move in sync
    private func level(for index: Int, at time: TimeInterval) -> CGFloat {
        guard isAnimating else { return 0.3 }
        let phase = time * (4.5 + Double(index) * 1.3) + Double(index) * 1.7
        return 0.3 + 0.7 * CGFloat(abs(sin(phase)))
    }
}
