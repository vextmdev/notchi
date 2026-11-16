import AppKit
import SwiftUI

// the SwiftUI Settings scene is hard to open from a menu bar app, so we manage our own window
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
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
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }

        // a menu bar app can't reliably bring windows to the front,
        // so act like a normal app while settings are open
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
