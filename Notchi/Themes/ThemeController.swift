import AppKit

@MainActor
final class ThemeController {
    private struct Overlay {
        let screen: NSScreen
        let front: OverlayWindow
        let back: OverlayWindow?
    }

    private var overlays: [Overlay] = []
    private var config: ThemeConfig?
    private let windowCaps = WindowSnowCaps()

    private var capsTimer: Timer?
    private var flurryWorkItem: DispatchWorkItem?
    private var clickMonitor: Any?
    private var lastClickPuff = Date.distantPast
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observe(center, UserDefaults.didChangeNotification) { $0.apply() }
        observe(center, .NSProcessInfoPowerStateDidChange) { $0.apply() }
        observe(center, NSApplication.didChangeScreenParametersNotification) { $0.apply(force: true) }
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.accessibilityDisplayOptionsDidChangeNotification) { $0.apply() }

        apply(force: true)
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ handler: @escaping @MainActor (ThemeController) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                handler(self)
            }
        }
        observers.append(token)
    }

    // MARK: - Building

    func apply(force: Bool = false) {
        let next = ThemeConfig.current
        guard force || next != config else { return }
        config = next

        tearDown()
        guard next.theme != .off else { return }

        let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)

        for screen in NSScreen.screens {
            let front = OverlayWindow(screen: screen, level: .floating)
            var back: OverlayWindow?
            let scale = screen.backingScaleFactor

            if next.showsSnowfall {
                if next.placement == .desktop {
                    let window = OverlayWindow(screen: screen, level: desktopLevel)
                    window.host.addSublayer(SnowEffects.snowfall(in: window.host.bounds, amount: next.amount, scale: scale))
                    back = window
                } else {
                    front.host.addSublayer(SnowEffects.snowfall(in: front.host.bounds, amount: next.amount, scale: scale))
                }
            }

            if next.showsLights {
                let hangY = front.host.bounds.height - Self.menuBarHeight(of: screen)
                front.host.addSublayer(FairyLights.make(in: front.host.bounds, hangY: hangY, scale: scale))
            }

            overlays.append(Overlay(screen: screen, front: front, back: back))
        }

        if next.showsWindowSnow {
            updateCaps()
            capsTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.updateCaps() }
            }
        }

        if next.showsPuffs {
            scheduleFlurry()
            clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
                Task { @MainActor in self?.handleClick() }
            }
        }
    }

    private func tearDown() {
        capsTimer?.invalidate()
        capsTimer = nil
        flurryWorkItem?.cancel()
        flurryWorkItem = nil
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
        }
        clickMonitor = nil

        windowCaps.reset()
        for overlay in overlays {
            overlay.front.orderOut(nil)
            overlay.back?.orderOut(nil)
        }
        overlays.removeAll()
    }

    private func updateCaps() {
        windowCaps.update(targets: overlays.map { .init(frame: $0.screen.frame, layer: $0.front.host) })
    }

    // MARK: - Puffs

    // called when the notch closes, the snow gets shaken off its bottom edge
    func notchPuff(below rect: CGRect) {
        guard let config, config.showsPuffs else { return }
        let bottom = CGPoint(x: rect.midX, y: rect.minY)
        guard let overlay = overlays.first(where: { $0.screen.frame.contains(bottom) }) else { return }

        let frame = overlay.screen.frame
        SnowEffects.puff(
            on: overlay.front.host,
            at: CGPoint(x: bottom.x - frame.minX, y: bottom.y - frame.minY),
            width: rect.width * 0.7,
            festive: config.isFestive
        )
    }

    private func handleClick() {
        guard let config, config.showsPuffs, Date().timeIntervalSince(lastClickPuff) > 1.2 else { return }

        let mouse = NSEvent.mouseLocation
        guard let overlay = overlays.first(where: { $0.screen.frame.contains(mouse) }) else { return }

        let menuBar = Self.menuBarHeight(of: overlay.screen)
        guard mouse.y >= overlay.screen.frame.maxY - menuBar else { return }

        lastClickPuff = Date()
        SnowEffects.puff(
            on: overlay.front.host,
            at: CGPoint(x: mouse.x - overlay.screen.frame.minX, y: overlay.front.host.bounds.height - menuBar),
            width: 60,
            festive: config.isFestive,
            amount: 0.6
        )
    }

    // every now and then a bit of snow drifts down from the menu bar on its own
    private func scheduleFlurry() {
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.config?.showsPuffs == true else { return }
                self.ambientFlurry()
                self.scheduleFlurry()
            }
        }
        flurryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 20...50), execute: work)
    }

    private func ambientFlurry() {
        guard let config, let overlay = overlays.randomElement() else { return }
        let bounds = overlay.front.host.bounds
        SnowEffects.puff(
            on: overlay.front.host,
            at: CGPoint(
                x: .random(in: bounds.width * 0.1...bounds.width * 0.9),
                y: bounds.height - Self.menuBarHeight(of: overlay.screen)
            ),
            width: 120,
            festive: config.isFestive,
            amount: 0.4
        )
    }

    // MARK: - Helpers

    static func menuBarHeight(of screen: NSScreen) -> CGFloat {
        let height = max(screen.frame.maxY - screen.visibleFrame.maxY, screen.safeAreaInsets.top)
        return height > 0 ? height : 24
    }
}
