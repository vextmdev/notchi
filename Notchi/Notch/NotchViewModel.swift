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

    var openSettings: () -> Void = {}

    // height follows the notch, so taller notches don't squash the content
    var expandedSize: CGSize {
        CGSize(width: 580, height: notchSize.height + 152)
    }
    let nowPlayingWingWidth: CGFloat = 34

    var isNowPlayingVisible: Bool {
        showsNowPlaying && UserDefaults.standard.bool(forKey: Preferences.showNowPlaying)
    }

    var collapsedSize: CGSize {
        guard isNowPlayingVisible else { return notchSize }
        return CGSize(width: notchSize.width + nowPlayingWingWidth * 2, height: notchSize.height)
    }
}
