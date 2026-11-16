import AppKit
import QuartzCore

// snow piles on top of every window. they settle once a window sits still and fall off when it moves.
// only window positions are read, never their content
@MainActor
final class WindowSnowCaps {
    struct Target {
        let frame: CGRect
        // bottom of the menu bar, nothing gets placed above this
        let topLimit: CGFloat
        let layer: CALayer
    }

    var decorations = true
    var festive = false

    private struct Window {
        let id: CGWindowID
        let rect: CGRect
    }

    private struct Cap {
        var bounds: CGRect
        var stableSince: Date
        var segments: [ClosedRange<CGFloat>] = []
        var pile: SnowPile?
    }

    // a settled pile this round, used to place the snowman and snowballs
    private struct Settled {
        let window: Window
        let segments: [ClosedRange<CGFloat>]
        let target: Target
        let base: CGFloat
        let cocoaTop: CGFloat
        let settledFor: TimeInterval
        let front: [Window]
    }

    private struct Snowman {
        let windowID: CGWindowID
        let bounds: CGRect
        let x: CGFloat
        let layer: CALayer
    }

    private var caps: [CGWindowID: Cap] = [:]
    private var snowman: Snowman?
    private var nextSnowball = Date().addingTimeInterval(15)

    private let settleDelay: TimeInterval = 1.2
    private let cornerInset: CGFloat = 18
    private let snowmanHeadroom: CGFloat = 80

    func update(targets: [Target]) {
        let windows = visibleWindows()
        let now = Date()
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        var seen = Set<CGWindowID>()
        var settled: [Settled] = []

        for (index, window) in windows.enumerated() {
            seen.insert(window.id)
            let front = Array(windows[..<index])
            let segments = visibleTopEdge(of: window, behind: front)

            var cap = caps[window.id] ?? Cap(bounds: window.rect, stableSince: now)

            if cap.bounds != window.rect {
                cap.bounds = window.rect
                cap.stableSince = now
                cap.pile?.shakeOff()
                cap.pile = nil
            }

            let settledFor = now.timeIntervalSince(cap.stableSince)

            if segments.isEmpty {
                cap.pile?.remove()
                cap.pile = nil
            } else if settledFor >= settleDelay {
                // window list uses top-left origin, AppKit uses bottom-left
                let cocoaTop = primaryHeight - window.rect.minY
                let anchor = CGPoint(x: window.rect.midX, y: cocoaTop - 1)

                if let target = targets.first(where: { $0.frame.contains(anchor) }) {
                    let base = cocoaTop - target.frame.minY
                    let offset = target.frame.minX

                    if let pile = cap.pile {
                        if segments != cap.segments { pile.update(segments, offset: offset) }
                    } else {
                        cap.pile = SnowPile(in: target.layer, base: base, segments: segments, offset: offset)
                    }

                    settled.append(Settled(
                        window: window,
                        segments: segments,
                        target: target,
                        base: base,
                        cocoaTop: cocoaTop,
                        settledFor: settledFor,
                        front: front
                    ))
                }
            }

            cap.segments = segments
            caps[window.id] = cap
        }

        for (id, cap) in caps where !seen.contains(id) {
            cap.pile?.shakeOff()
        }
        caps = caps.filter { seen.contains($0.key) }

        guard decorations else {
            removeSnowman()
            return
        }
        updateSnowman(settled)

        if now >= nextSnowball {
            rollSnowball(settled)
            nextSnowball = now.addingTimeInterval(.random(in: 35...75))
        }
    }

    func reset() {
        caps.values.forEach { $0.pile?.remove() }
        caps.removeAll()
        snowman?.layer.removeFromSuperlayer()
        snowman = nil
    }

    // MARK: - Snowman

    private func updateSnowman(_ settled: [Settled]) {
        if let current = snowman {
            let stillStanding = settled.contains { entry in
                entry.window.id == current.windowID
                    && entry.window.rect == current.bounds
                    && entry.segments.contains { $0.contains(current.x) }
                    && !isBlocked(x: current.x, top: entry.window.rect.minY, by: entry.front)
            }
            if !stillStanding { removeSnowman() }
            return
        }

        // only on windows that have been still for a few seconds and have room above them
        for entry in settled where entry.settledFor > 4 {
            guard entry.target.topLimit - entry.cocoaTop >= snowmanHeadroom,
                  let widest = entry.segments.max(by: { $0.upperBound - $0.lowerBound < $1.upperBound - $1.lowerBound }),
                  widest.upperBound - widest.lowerBound >= 110 else { continue }

            let x = widest.upperBound - 40
            guard !isBlocked(x: x, top: entry.window.rect.minY, by: entry.front) else { continue }

            let layer = SnowDecorations.snowman(festive: festive, scale: entry.target.layer.contentsScale)
            layer.position = CGPoint(x: x - entry.target.frame.minX, y: entry.base + 3)
            entry.target.layer.addSublayer(layer)
            SnowDecorations.popIn(layer)

            snowman = Snowman(windowID: entry.window.id, bounds: entry.window.rect, x: x, layer: layer)
            return
        }
    }

    private func removeSnowman() {
        guard let snowman else { return }
        SnowDecorations.topple(snowman.layer)
        self.snowman = nil
    }

    // is a window in front covering the spot where the snowman would stand
    private func isBlocked(x: CGFloat, top: CGFloat, by front: [Window]) -> Bool {
        let spot = CGRect(x: x - 26, y: top - snowmanHeadroom, width: 52, height: snowmanHeadroom)
        return front.contains { $0.rect.intersects(spot) }
    }

    // MARK: - Snowball

    private func rollSnowball(_ settled: [Settled]) {
        let options = settled.flatMap { entry in
            entry.segments
                .filter { $0.upperBound - $0.lowerBound >= 220 }
                .map { (entry, $0) }
        }
        guard let choice = options.randomElement() else { return }
        let (entry, segment) = choice

        let offset = entry.target.frame.minX
        SnowDecorations.rollSnowball(
            on: entry.target.layer,
            from: segment.lowerBound + 14 - offset,
            to: segment.upperBound - offset,
            baseY: entry.base + 3
        )
    }

    // MARK: - Windows

    // front to back, normal app windows only (Notchi's own settings window included)
    private func visibleWindows() -> [Window] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }

        return list.compactMap { entry in
            guard (entry[kCGWindowLayer as String] as? Int) == 0,
                  (entry[kCGWindowAlpha as String] as? Double ?? 1) > 0.1,
                  let id = entry[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  rect.width > 120, rect.height > 60 else { return nil }
            return Window(id: id, rect: rect)
        }
    }

    // the parts of the top edge that aren't covered by a window in front
    private func visibleTopEdge(of window: Window, behind front: [Window]) -> [ClosedRange<CGFloat>] {
        let minX = window.rect.minX + cornerInset
        let maxX = window.rect.maxX - cornerInset
        guard maxX - minX > 20 else { return [] }

        let top = window.rect.minY
        var segments = [minX...maxX]

        for other in front where other.rect.minY < top + 2 && other.rect.maxY > top - 10 {
            let cut = other.rect.minX...other.rect.maxX
            segments = segments.flatMap { segment -> [ClosedRange<CGFloat>] in
                guard cut.overlaps(segment) else { return [segment] }
                var pieces: [ClosedRange<CGFloat>] = []
                if cut.lowerBound > segment.lowerBound { pieces.append(segment.lowerBound...cut.lowerBound) }
                if cut.upperBound < segment.upperBound { pieces.append(cut.upperBound...segment.upperBound) }
                return pieces
            }
            .filter { $0.upperBound - $0.lowerBound > 24 }
        }
        return segments
    }
}

// one soft snow drift sitting on a window's top edge
@MainActor
final class SnowPile {
    private let root = CALayer()
    private let fill = CAGradientLayer()
    private let shape = CAShapeLayer()

    // the pile is drawn in a thin band around the window edge, `edge` is the window top inside that band
    private let edge: CGFloat = 3

    init(in parent: CALayer, base: CGFloat, segments: [ClosedRange<CGFloat>], offset: CGFloat) {
        root.frame = CGRect(x: 0, y: base - edge, width: parent.bounds.width, height: 18)
        root.contentsScale = parent.contentsScale
        root.shadowColor = NSColor(calibratedRed: 0.15, green: 0.2, blue: 0.3, alpha: 1).cgColor
        root.shadowOpacity = 0.25
        root.shadowRadius = 2
        root.shadowOffset = CGSize(width: 0, height: -1)

        // white on top, a hint of cold blue where it touches the window
        fill.frame = root.bounds
        fill.contentsScale = parent.contentsScale
        fill.colors = [
            NSColor.white.cgColor,
            NSColor(calibratedRed: 0.97, green: 0.98, blue: 1, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.82, green: 0.87, blue: 0.95, alpha: 1).cgColor,
        ]
        fill.locations = [0, 0.45, 1]
        fill.startPoint = CGPoint(x: 0.5, y: 0.75)
        fill.endPoint = CGPoint(x: 0.5, y: 0.1)

        shape.frame = root.bounds
        fill.mask = shape
        root.addSublayer(fill)
        parent.addSublayer(root)

        let full = path(segments, offset: offset, height: 1)
        shape.path = full
        root.shadowPath = full

        // grows from a thin dusting into a full pile
        let flat = path(segments, offset: offset, height: 0.1)
        for (layer, key) in [(shape as CALayer, "path"), (root, "shadowPath")] {
            let grow = CABasicAnimation(keyPath: key)
            grow.fromValue = flat
            grow.toValue = full
            grow.duration = 1.8
            grow.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(grow, forKey: "grow")
        }

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.8
        root.add(fade, forKey: "fade")
    }

    func update(_ segments: [ClosedRange<CGFloat>], offset: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let full = path(segments, offset: offset, height: 1)
        shape.path = full
        root.shadowPath = full
        CATransaction.commit()
    }

    func shakeOff() {
        let root = root
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.3)
        CATransaction.setCompletionBlock { root.removeFromSuperlayer() }
        root.opacity = 0
        root.transform = CATransform3DMakeTranslation(0, -8, 0)
        CATransaction.commit()
    }

    func remove() {
        root.removeFromSuperlayer()
    }

    // smooth drift: thick in the middle, rounded off at the ends, a few gentle waves on top
    private func path(_ segments: [ClosedRange<CGFloat>], offset: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()

        for segment in segments {
            let x0 = segment.lowerBound - offset
            let x1 = segment.upperBound - offset

            var points: [CGPoint] = []
            var x = x0
            while x < x1 {
                points.append(CGPoint(x: x, y: edge + pileHeight(at: x, from: x0, to: x1) * height))
                x += 10
            }
            points.append(CGPoint(x: x1, y: edge))

            path.move(to: CGPoint(x: x0, y: edge - 1))
            path.addLine(to: points[0])
            // curve through the midpoints, keeps the outline smooth without sharp bumps
            for i in 1..<points.count {
                let mid = CGPoint(x: (points[i - 1].x + points[i].x) / 2, y: (points[i - 1].y + points[i].y) / 2)
                path.addQuadCurve(to: mid, control: points[i - 1])
            }
            path.addLine(to: points[points.count - 1])
            path.addLine(to: CGPoint(x: x1, y: edge - 1))
            path.closeSubpath()
        }
        return path
    }

    private func pileHeight(at x: CGFloat, from x0: CGFloat, to x1: CGFloat) -> CGFloat {
        let t = min(1, max(0, min(x - x0, x1 - x) / 18))
        let taper = t * t * (3 - 2 * t)
        let waves = 0.82 + 0.18 * sin(x * 0.045) + 0.1 * sin(x * 0.13 + 1.3)
        return 6 * taper * waves
    }
}
