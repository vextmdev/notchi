import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchWindowController {
    private let model: NotchViewModel
    private let panel: NotchPanel
    private var geometry: NotchGeometry?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var expandWorkItem: DispatchWorkItem?
    private var collapseWorkItem: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    private var dragChangeCount = NSPasteboard(name: .drag).changeCount
    private var mouseDownInPanel = false

    private let hoverPadding: CGFloat = 10
    private let dragPadding: CGFloat = 40
    private let collapseDelay: TimeInterval = 0.3

    private var expandDelay: TimeInterval {
        UserDefaults.standard.double(forKey: Preferences.hoverDelay)
    }

    init(model: NotchViewModel, clipboard: ClipboardMonitor, media: MediaController, shelf: ShelfStore) {
        self.model = model
        self.panel = NotchPanel(contentRect: NSRect(origin: .zero, size: model.expandedSize))

        let rootView = NotchView(model: model, clipboard: clipboard, media: media, shelf: shelf)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.sizingOptions = []
        panel.contentView = hostingView

        media.$isPlaying
            .removeDuplicates()
            .sink { [weak model] isPlaying in model?.showsNowPlaying = isPlaying }
            .store(in: &cancellables)

        layout()
        panel.orderFrontRegardless()
        startMonitoring()
    }

    // MARK: - Layout

    func layout() {
        guard let geometry = NotchGeometry.current() else { return }
        self.geometry = geometry
        model.notchSize = geometry.notchSize

        let size = model.expandedSize
        let screenFrame = geometry.screen.frame
        let frame = NSRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        panel.setFrame(frame, display: true)
    }

    // MARK: - Mouse

    private func startMonitoring() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] event in
            let type = event.type
            Task { @MainActor in self?.handleMouse(type) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
            let type = event.type
            Task { @MainActor in self?.handleMouse(type) }
            return event
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.layout() }
        }
    }

    private func handleMouse(_ type: NSEvent.EventType) {
        let mouse = NSEvent.mouseLocation

        if type == .leftMouseDown {
            dragChangeCount = NSPasteboard(name: .drag).changeCount
            mouseDownInPanel = model.isExpanded && panel.frame.contains(mouse)
        }

        let isButtonDown = NSEvent.pressedMouseButtons & 1 != 0
        let isDraggingFiles = isButtonDown && dragHasFiles()

        if model.isExpanded {
            let isInside = panel.frame.insetBy(dx: -hoverPadding, dy: -hoverPadding).contains(mouse)
            // stay open mid-drag so you can drop files in or drag them out
            let isDragging = isButtonDown && (mouseDownInPanel || isDraggingFiles)
            if isInside || isDragging {
                cancelCollapse()
            } else {
                scheduleCollapse()
            }
        } else if isDraggingFiles, isInHotZone(mouse, padding: dragPadding) {
            model.selectedTab = .shelf
            expand()
        } else if !isButtonDown, isInHotZone(mouse, padding: hoverPadding) {
            scheduleExpand()
        } else {
            cancelExpand()
        }
    }

    // the drag pasteboard changes when a new drag starts, so compare against the last mouse down
    private func dragHasFiles() -> Bool {
        let pasteboard = NSPasteboard(name: .drag)
        guard pasteboard.changeCount != dragChangeCount else { return false }
        return pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
    }

    private func isInHotZone(_ point: NSPoint, padding: CGFloat) -> Bool {
        guard let geometry else { return false }
        let screenFrame = geometry.screen.frame
        let size = model.collapsedSize
        let zone = NSRect(
            x: screenFrame.midX - size.width / 2 - padding,
            y: screenFrame.maxY - size.height - padding / 2,
            width: size.width + padding * 2,
            height: size.height + padding / 2 + 4 // extra so the top pixel row counts
        )
        return zone.contains(point)
    }

    private func expand() {
        cancelExpand()
        cancelCollapse()
        guard !model.isExpanded else { return }
        model.isExpanded = true
        panel.ignoresMouseEvents = false
        if UserDefaults.standard.bool(forKey: Preferences.hapticsEnabled) {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
    }

    private func collapse() {
        guard model.isExpanded else { return }
        model.isExpanded = false
        model.isDropTargeted = false
        panel.ignoresMouseEvents = true
        if panel.isKeyWindow {
            panel.resignKey()
        }
    }

    // short delay so it doesn't pop open when you just pass by
    private func scheduleExpand() {
        guard expandWorkItem == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.expandWorkItem = nil
                if self.isInHotZone(NSEvent.mouseLocation, padding: self.hoverPadding) {
                    self.expand()
                }
            }
        }
        expandWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + expandDelay, execute: work)
    }

    private func cancelExpand() {
        expandWorkItem?.cancel()
        expandWorkItem = nil
    }

    private func scheduleCollapse() {
        guard collapseWorkItem == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.collapseWorkItem = nil
                self?.collapse()
            }
        }
        collapseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + collapseDelay, execute: work)
    }

    private func cancelCollapse() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
    }
}
