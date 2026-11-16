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

    private let hoverPadding: CGFloat = 10
    private let expandDelay: TimeInterval = 0.12
    private let collapseDelay: TimeInterval = 0.3

    init(model: NotchViewModel, clipboard: ClipboardMonitor, media: MediaController) {
        self.model = model
        self.panel = NotchPanel(contentRect: NSRect(origin: .zero, size: model.expandedSize))

        let rootView = NotchView(model: model, clipboard: clipboard, media: media)
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

    // MARK: - Hover

    private func startMonitoring() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            Task { @MainActor in self?.handleMouseMoved() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            Task { @MainActor in self?.handleMouseMoved() }
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

    private func handleMouseMoved() {
        let mouse = NSEvent.mouseLocation

        if model.isExpanded {
            if panel.frame.insetBy(dx: -hoverPadding, dy: -hoverPadding).contains(mouse) {
                cancelCollapse()
            } else {
                scheduleCollapse()
            }
        } else if isInHotZone(mouse) {
            scheduleExpand()
        } else {
            cancelExpand()
        }
    }

    private func isInHotZone(_ point: NSPoint) -> Bool {
        guard let geometry else { return false }
        let screenFrame = geometry.screen.frame
        let size = model.collapsedSize
        let zone = NSRect(
            x: screenFrame.midX - size.width / 2 - hoverPadding,
            y: screenFrame.maxY - size.height - 4,
            width: size.width + hoverPadding * 2,
            height: size.height + 8 // extra so the top pixel row counts
        )
        return zone.contains(point)
    }

    private func expand() {
        cancelCollapse()
        guard !model.isExpanded else { return }
        model.isExpanded = true
        panel.ignoresMouseEvents = false
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    private func collapse() {
        guard model.isExpanded else { return }
        model.isExpanded = false
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
                if self.isInHotZone(NSEvent.mouseLocation) {
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
