import AppKit
import QuartzCore

// little piles of snow on top of every window. they settle once a window sits still
// and fall off when it moves. only window positions are read, never their content
@MainActor
final class WindowSnowCaps {
    struct Target {
        let frame: CGRect
        let layer: CALayer
    }

    private struct Window {
        let id: CGWindowID
        let rect: CGRect
    }

    private struct Cap {
        var bounds: CGRect
        var stableSince: Date
        var segments: [ClosedRange<CGFloat>] = []
        var layer: CAShapeLayer?
    }

    private var caps: [CGWindowID: Cap] = [:]
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private let settleDelay: TimeInterval = 1.2
    private let cornerInset: CGFloat = 14

    func update(targets: [Target]) {
        let windows = visibleWindows()
        let now = Date()
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        var seen = Set<CGWindowID>()

        for (index, window) in windows.enumerated() {
            seen.insert(window.id)
            let top = window.rect.minY
            let segments = visibleTopEdge(of: window, behind: windows[..<index])

            var cap = caps[window.id] ?? Cap(bounds: window.rect, stableSince: now)

            if cap.bounds != window.rect {
                cap.bounds = window.rect
                cap.stableSince = now
                if let layer = cap.layer { shakeOff(layer) }
                cap.layer = nil
            }

            let isSettled = now.timeIntervalSince(cap.stableSince) >= settleDelay

            if segments.isEmpty {
                cap.layer?.removeFromSuperlayer()
                cap.layer = nil
            } else if isSettled {
                // window list uses top-left origin, AppKit uses bottom-left
                let cocoaTop = primaryHeight - top
                let center = CGPoint(x: window.rect.midX, y: cocoaTop - 1)

                if let target = targets.first(where: { $0.frame.contains(center) }) {
                    let base = cocoaTop - target.frame.minY
                    let offset = target.frame.minX

                    if let layer = cap.layer {
                        if segments != cap.segments {
                            CATransaction.begin()
                            CATransaction.setDisableActions(true)
                            layer.path = Self.path(segments, base: base, offset: offset, height: 1)
                            CATransaction.commit()
                        }
                    } else {
                        cap.layer = settle(segments, base: base, offset: offset, in: target.layer)
                    }
                }
            }

            cap.segments = segments
            caps[window.id] = cap
        }

        for (id, cap) in caps where !seen.contains(id) {
            if let layer = cap.layer { shakeOff(layer) }
        }
        caps = caps.filter { seen.contains($0.key) }
    }

    func reset() {
        caps.values.forEach { $0.layer?.removeFromSuperlayer() }
        caps.removeAll()
    }

    // MARK: - Windows

    // front to back, normal app windows only
    private func visibleWindows() -> [Window] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }

        return list.compactMap { entry in
            guard (entry[kCGWindowLayer as String] as? Int) == 0,
                  (entry[kCGWindowOwnerPID as String] as? pid_t) != ownPID,
                  (entry[kCGWindowAlpha as String] as? Double ?? 1) > 0.1,
                  let id = entry[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  rect.width > 120, rect.height > 60 else { return nil }
            return Window(id: id, rect: rect)
        }
    }

    // the parts of the top edge that aren't covered by a window in front
    private func visibleTopEdge(of window: Window, behind front: ArraySlice<Window>) -> [ClosedRange<CGFloat>] {
        let minX = window.rect.minX + cornerInset
        let maxX = window.rect.maxX - cornerInset
        guard maxX - minX > 20 else { return [] }

        let top = window.rect.minY
        var segments = [minX...maxX]

        for other in front where other.rect.minY < top + 2 && other.rect.maxY > top - 8 {
            segments = segments.flatMap { segment -> [ClosedRange<CGFloat>] in
                let cut = other.rect.minX...other.rect.maxX
                guard cut.overlaps(segment) else { return [segment] }
                var pieces: [ClosedRange<CGFloat>] = []
                if cut.lowerBound > segment.lowerBound { pieces.append(segment.lowerBound...cut.lowerBound) }
                if cut.upperBound < segment.upperBound { pieces.append(cut.upperBound...segment.upperBound) }
                return pieces
            }
            .filter { $0.upperBound - $0.lowerBound > 20 }
        }
        return segments
    }

    // MARK: - Drawing

    private func settle(_ segments: [ClosedRange<CGFloat>], base: CGFloat, offset: CGFloat, in parent: CALayer) -> CAShapeLayer {
        let full = Self.path(segments, base: base, offset: offset, height: 1)

        let layer = CAShapeLayer()
        layer.frame = parent.bounds
        layer.contentsScale = parent.contentsScale
        layer.path = full
        layer.fillColor = NSColor(white: 0.98, alpha: 1).cgColor
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 1.5
        layer.shadowOffset = CGSize(width: 0, height: -0.5)
        parent.addSublayer(layer)

        let grow = CABasicAnimation(keyPath: "path")
        grow.fromValue = Self.path(segments, base: base, offset: offset, height: 0.1)
        grow.toValue = full
        grow.duration = 1.6
        grow.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(grow, forKey: "grow")

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.8
        layer.add(fade, forKey: "fade")

        return layer
    }

    private func shakeOff(_ layer: CAShapeLayer) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.3)
        CATransaction.setCompletionBlock { layer.removeFromSuperlayer() }
        layer.opacity = 0
        layer.transform = CATransform3DMakeTranslation(0, -8, 0)
        CATransaction.commit()
    }

    // bumpy snow line, tapers off at both ends
    private static func path(_ segments: [ClosedRange<CGFloat>], base: CGFloat, offset: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()

        for segment in segments {
            let x0 = segment.lowerBound - offset
            let x1 = segment.upperBound - offset
            let y = base - 1

            path.move(to: CGPoint(x: x0, y: y))
            var x = x0
            while x < x1 {
                let next = min(x + 9, x1)
                let taper = min(1, min(next - x0, x1 - next) / 18)
                let bump = (3.2 + 1.4 * sin(next * 0.23) + 0.9 * sin(next * 0.61)) * height * taper
                path.addQuadCurve(
                    to: CGPoint(x: next, y: y + bump),
                    control: CGPoint(x: (x + next) / 2, y: y + bump + 1.2 * height * taper)
                )
                x = next
            }
            path.addLine(to: CGPoint(x: x1, y: y))
            path.closeSubpath()
        }
        return path
    }
}
