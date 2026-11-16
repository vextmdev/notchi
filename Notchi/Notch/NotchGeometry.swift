import AppKit

// falls back to a small pill on screens without a notch
struct NotchGeometry {
    let screen: NSScreen
    let notchSize: CGSize
    let hasNotch: Bool

    static func current() -> NotchGeometry? {
        let notchScreen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
        guard let screen = notchScreen ?? NSScreen.main else { return nil }

        let topInset = screen.safeAreaInsets.top
        if topInset > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let width = screen.frame.width - left.width - right.width
            return NotchGeometry(
                screen: screen,
                notchSize: CGSize(width: width, height: topInset),
                hasNotch: true
            )
        }

        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        return NotchGeometry(
            screen: screen,
            notchSize: CGSize(width: 200, height: max(menuBarHeight, 24)),
            hasNotch: false
        )
    }
}
