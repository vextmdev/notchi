import SwiftUI

@MainActor
final class NotchViewModel: ObservableObject {
    enum Tab {
        case clipboard
        case shelf
    }

    @Published var isExpanded = false
    @Published var notchSize = CGSize(width: 200, height: 32)
    @Published var showsNowPlaying = false
    @Published var selectedTab: Tab = .clipboard
    @Published var isDropTargeted = false
    @Published var previewURL: URL?

    let expandedSize = CGSize(width: 580, height: 190)
    let nowPlayingWingWidth: CGFloat = 34

    var collapsedSize: CGSize {
        guard showsNowPlaying else { return notchSize }
        return CGSize(width: notchSize.width + nowPlayingWingWidth * 2, height: notchSize.height)
    }
}
