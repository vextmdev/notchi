import AppKit

// transparent, click-through window covering a whole screen, effects get drawn into `host`
final class OverlayWindow: NSWindow {
    let host: CALayer

    init(screen: NSScreen, level: NSWindow.Level) {
        let size = screen.frame.size

        // the layer needs its size set by hand, otherwise it starts at 0x0 and nothing shows up
        let layer = CALayer()
        layer.frame = CGRect(origin: .zero, size: size)
        layer.contentsScale = screen.backingScaleFactor

        let view = NSView(frame: CGRect(origin: .zero, size: size))
        view.layer = layer
        view.wantsLayer = true
        host = layer

        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)

        self.level = level
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        animationBehavior = .none
        contentView = view

        setFrame(screen.frame, display: false)
        orderFrontRegardless()
    }

    // let it cover the menu bar area too
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
