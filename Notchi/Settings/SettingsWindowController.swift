import AppKit
import SwiftUI

// the SwiftUI Settings scene is hard to open from a menu bar app, so we manage our own window
@MainActor
final class SettingsWindowController {
    private let clipboard: ClipboardMonitor
    private let shelf: ShelfStore
    private let keepAwake: KeepAwake
    private var window: NSWindow?

    init(clipboard: ClipboardMonitor, shelf: ShelfStore, keepAwake: KeepAwake) {
        self.clipboard = clipboard
        self.shelf = shelf
        self.keepAwake = keepAwake
    }

    func show() {
        if window == nil {
            let view = SettingsView(clipboard: clipboard, shelf: shelf, keepAwake: keepAwake)
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Notchi Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
