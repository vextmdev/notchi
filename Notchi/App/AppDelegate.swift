import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let model = NotchViewModel()
    private let clipboard = ClipboardMonitor()
    private let media = MediaController()
    private let shelf = ShelfStore()
    private let keepAwake = KeepAwake()

    private var notchController: NotchWindowController?
    private var settingsController: SettingsWindowController?
    private var themeController: ThemeController?
    private var statusItem: NSStatusItem?

    private var launchAtLoginItem: NSMenuItem?
    private var keepAwakeItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Preferences.registerDefaults()

        clipboard.start()
        media.start()

        let settings = SettingsWindowController(clipboard: clipboard, shelf: shelf, keepAwake: keepAwake)
        settingsController = settings
        model.openSettings = { settings.show() }

        let themes = ThemeController()
        themeController = themes
        model.onCollapse = { frame in themes.notchPuff(below: frame) }

        notchController = NotchWindowController(model: model, clipboard: clipboard, media: media, shelf: shelf)
        setUpStatusItem()
    }

    // MARK: - Menu bar

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.topthird.inset.filled",
            accessibilityDescription: "Notchi"
        )

        let menu = NSMenu()
        menu.delegate = self

        menu.addItem(menuItem("Settings…", action: #selector(openSettings), key: ","))
        menu.addItem(.separator())

        let keepAwake = menuItem("Keep Mac Awake", action: #selector(toggleKeepAwake))
        menu.addItem(keepAwake)
        keepAwakeItem = keepAwake

        let launchAtLogin = menuItem("Launch at Login", action: #selector(toggleLaunchAtLogin))
        menu.addItem(launchAtLogin)
        launchAtLoginItem = launchAtLogin

        menu.addItem(menuItem("Clear Clipboard History", action: #selector(clearClipboard)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Notchi", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
    }

    private func menuItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // these can also change from the settings window, so refresh every time the menu opens
    func menuWillOpen(_ menu: NSMenu) {
        keepAwakeItem?.state = keepAwake.isOn ? .on : .off
        launchAtLoginItem?.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func openSettings() {
        settingsController?.show()
    }

    @objc private func toggleKeepAwake() {
        keepAwake.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Notchi: could not change launch at login: \(error.localizedDescription)")
        }
    }

    @objc private func clearClipboard() {
        clipboard.clearUnpinned()
    }
}
