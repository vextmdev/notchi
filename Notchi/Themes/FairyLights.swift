import AppKit
import QuartzCore

// a light string hanging under the menu bar, every bulb twinkles on its own timing
enum FairyLights {
    private static let colors: [NSColor] = [.systemRed, .systemGreen, .systemYellow, .systemBlue, .systemOrange]

    static func make(in bounds: CGRect, hangY: CGFloat, scale: CGFloat) -> CALayer {
        let container = CALayer()
        container.frame = bounds
        container.contentsScale = scale

        let spacing: CGFloat = 170
        let sag: CGFloat = 9
        let count = max(1, Int((bounds.width / spacing).rounded()))
        let step = bounds.width / CGFloat(count)

        let wire = CGMutablePath()
        var bulbPositions: [CGPoint] = []

        for index in 0..<count {
            let start = CGPoint(x: CGFloat(index) * step, y: hangY)
            let end = CGPoint(x: CGFloat(index + 1) * step, y: hangY)
            let control = CGPoint(x: (start.x + end.x) / 2, y: hangY - sag * 2)

            if index == 0 { wire.move(to: start) }
            wire.addQuadCurve(to: end, control: control)

            for t in stride(from: 0.125, to: 1.0, by: 0.25) {
                bulbPositions.append(point(from: start, control: control, to: end, t: CGFloat(t)))
            }
        }

        let wireLayer = CAShapeLayer()
        wireLayer.frame = bounds
        wireLayer.path = wire
        wireLayer.strokeColor = NSColor(white: 0.12, alpha: 0.85).cgColor
        wireLayer.fillColor = nil
        wireLayer.lineWidth = 1.2
        wireLayer.contentsScale = scale
        container.addSublayer(wireLayer)

        for (index, position) in bulbPositions.enumerated() {
            container.addSublayer(bulb(at: position, color: colors[index % colors.count], scale: scale))
        }

        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0
        fadeIn.toValue = 1
        fadeIn.duration = 1.2
        container.add(fadeIn, forKey: "fadeIn")

        return container
    }

    private static func bulb(at position: CGPoint, color: NSColor, scale: CGFloat) -> CALayer {
        let bounds = CGRect(x: 0, y: 0, width: 5, height: 7)
        let bulb = CALayer()
        bulb.bounds = bounds
        bulb.position = CGPoint(x: position.x, y: position.y - 4)
        bulb.cornerRadius = 2.5
        bulb.backgroundColor = color.cgColor
        bulb.contentsScale = scale

        bulb.shadowColor = color.cgColor
        bulb.shadowOpacity = 1
        bulb.shadowRadius = 5
        bulb.shadowOffset = .zero
        bulb.shadowPath = CGPath(roundedRect: bounds, cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)

        let twinkle = CABasicAnimation(keyPath: "opacity")
        twinkle.fromValue = 1
        twinkle.toValue = 0.3
        twinkle.duration = Double.random(in: 0.9...2.4)
        twinkle.beginTime = CACurrentMediaTime() + Double.random(in: 0...2)
        twinkle.autoreverses = true
        twinkle.repeatCount = .infinity
        twinkle.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        bulb.add(twinkle, forKey: "twinkle")

        return bulb
    }

    private static func point(from start: CGPoint, control: CGPoint, to end: CGPoint, t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u * u * start.x + 2 * u * t * control.x + t * t * end.x,
            y: u * u * start.y + 2 * u * t * control.y + t * t * end.y
        )
    }
}
