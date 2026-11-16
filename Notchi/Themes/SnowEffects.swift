import AppKit
import QuartzCore

// particle effects run on the GPU through CAEmitterLayer, so they cost almost no CPU
enum SnowEffects {
    static let flake: CGImage = makeSoftDot(size: 32)

    static func snowfall(in bounds: CGRect, amount: SnowAmount, scale: CGFloat) -> CAEmitterLayer {
        let emitter = CAEmitterLayer()
        emitter.frame = bounds
        emitter.contentsScale = scale
        emitter.emitterShape = .line
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.maxY + 10)
        emitter.emitterSize = CGSize(width: bounds.width * 1.3, height: 1)

        // small slow flakes in the back, bigger faster ones in front, gives a bit of depth
        let rate = amount.birthRate
        emitter.emitterCells = [
            fallingCell(birthRate: rate, velocity: 32, scale: 0.12, alpha: 0.55, distance: bounds.height),
            fallingCell(birthRate: rate * 0.45, velocity: 60, scale: 0.22, alpha: 0.9, distance: bounds.height),
        ]
        return emitter
    }

    static func puff(on host: CALayer, at point: CGPoint, width: CGFloat, festive: Bool, amount: Float = 1) {
        let emitter = CAEmitterLayer()
        emitter.frame = host.bounds
        emitter.contentsScale = host.contentsScale
        emitter.emitterShape = .line
        emitter.emitterPosition = point
        emitter.emitterSize = CGSize(width: width, height: 1)

        var cells = [burstCell(color: .white, birthRate: 90 * amount, scale: 0.18)]
        if festive {
            cells += [NSColor.systemRed, .systemGreen, .systemYellow].map {
                burstCell(color: $0, birthRate: 14 * amount, scale: 0.12)
            }
        }
        emitter.emitterCells = cells
        host.addSublayer(emitter)

        // short burst, then let the flakes finish falling before cleaning up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { emitter.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { emitter.removeFromSuperlayer() }
    }

    // MARK: - Cells

    private static func fallingCell(birthRate: Float, velocity: CGFloat, scale: CGFloat, alpha: CGFloat, distance: CGFloat) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = flake
        cell.birthRate = birthRate
        cell.lifetime = Float(distance / velocity) * 1.4
        cell.velocity = velocity
        cell.velocityRange = velocity * 0.35
        cell.emissionLongitude = -.pi / 2
        cell.emissionRange = .pi / 10
        cell.yAcceleration = -6
        cell.xAcceleration = 3
        cell.scale = scale
        cell.scaleRange = scale * 0.5
        cell.alphaRange = 0.25
        cell.spinRange = 1.5
        cell.color = NSColor(white: 1, alpha: alpha).cgColor
        return cell
    }

    private static func burstCell(color: NSColor, birthRate: Float, scale: CGFloat) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = flake
        cell.birthRate = birthRate
        cell.lifetime = 3
        cell.lifetimeRange = 1
        cell.velocity = 50
        cell.velocityRange = 35
        cell.emissionLongitude = -.pi / 2
        cell.emissionRange = .pi / 3
        cell.yAcceleration = -45
        cell.scale = scale
        cell.scaleRange = scale * 0.5
        cell.alphaSpeed = -0.3
        cell.spinRange = 2
        cell.color = color.cgColor
        return cell
    }

    private static func makeSoftDot(size: Int) -> CGImage {
        let space = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let colors = [
            CGColor(red: 1, green: 1, blue: 1, alpha: 1),
            CGColor(red: 1, green: 1, blue: 1, alpha: 0),
        ] as CFArray
        let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0.4, 1])!
        let center = CGPoint(x: CGFloat(size) / 2, y: CGFloat(size) / 2)
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: CGFloat(size) / 2,
            options: []
        )
        return context.makeImage()!
    }
}
