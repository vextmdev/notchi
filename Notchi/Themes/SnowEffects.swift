import AppKit
import QuartzCore

// particle effects run on the GPU through CAEmitterLayer, so they cost almost no CPU
enum SnowEffects {
    static let softDot: CGImage = makeSoftDot(size: 32)
    static let crystal: CGImage = makeCrystal(size: 48) ?? softDot

    static func snowfall(size: CGSize, amount: SnowAmount, scale: CGFloat) -> CAEmitterLayer {
        let bounds = CGRect(origin: .zero, size: size)

        let emitter = CAEmitterLayer()
        emitter.frame = bounds
        emitter.contentsScale = scale
        emitter.emitterShape = .line
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.maxY + 20)
        emitter.emitterSize = CGSize(width: bounds.width * 1.4, height: 1)

        // three depths: tiny soft flakes far away, bigger ones closer, real crystals up front
        let rate = amount.birthRate
        let far = fallingCell("far", image: softDot, birthRate: rate, velocity: 26, scale: 0.1, alpha: 0.45, distance: size.height)
        let mid = fallingCell("mid", image: softDot, birthRate: rate * 0.5, velocity: 45, scale: 0.19, alpha: 0.75, distance: size.height)
        let near = fallingCell("near", image: crystal, birthRate: rate * 0.14, velocity: 65, scale: 0.3, alpha: 0.95, distance: size.height)
        near.spinRange = 1.2
        emitter.emitterCells = [far, mid, near]

        emitter.add(windGusts(for: ["far", "mid", "near"]), forKey: "wind")

        // start the simulation in the past so the screen is already full of snow
        emitter.beginTime = CACurrentMediaTime() - 25
        return emitter
    }

    static func puff(on host: CALayer, at point: CGPoint, width: CGFloat, festive: Bool, amount: Float = 1) {
        let emitter = CAEmitterLayer()
        emitter.frame = host.bounds
        emitter.contentsScale = host.contentsScale
        emitter.emitterShape = .line
        emitter.emitterPosition = point
        emitter.emitterSize = CGSize(width: width, height: 1)

        var cells = [
            burstCell(image: softDot, color: .white, birthRate: 80 * amount, scale: 0.17),
            burstCell(image: crystal, color: .white, birthRate: 10 * amount, scale: 0.22),
        ]
        if festive {
            cells += [NSColor.systemRed, .systemGreen, .systemYellow].map {
                burstCell(image: softDot, color: $0, birthRate: 12 * amount, scale: 0.12)
            }
        }
        emitter.emitterCells = cells
        host.addSublayer(emitter)

        // short burst, then let the flakes finish falling before cleaning up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { emitter.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { emitter.removeFromSuperlayer() }
    }

    // MARK: - Cells

    private static func fallingCell(_ name: String, image: CGImage, birthRate: Float, velocity: CGFloat, scale: CGFloat, alpha: CGFloat, distance: CGFloat) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.name = name
        cell.contents = image
        cell.birthRate = birthRate
        cell.lifetime = Float(distance / velocity) * 1.3
        cell.velocity = velocity
        cell.velocityRange = velocity * 0.3
        cell.emissionLongitude = -.pi / 2
        cell.emissionRange = .pi / 12
        cell.yAcceleration = -4
        cell.xAcceleration = 3
        cell.scale = scale
        cell.scaleRange = scale * 0.4
        cell.alphaRange = 0.2
        cell.spinRange = 0.6
        cell.color = NSColor(white: 1, alpha: alpha).cgColor
        return cell
    }

    private static func burstCell(image: CGImage, color: NSColor, birthRate: Float, scale: CGFloat) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = image
        cell.birthRate = birthRate
        cell.lifetime = 3
        cell.lifetimeRange = 1
        cell.velocity = 45
        cell.velocityRange = 30
        cell.emissionLongitude = -.pi / 2
        cell.emissionRange = .pi / 3
        cell.yAcceleration = -40
        cell.scale = scale
        cell.scaleRange = scale * 0.5
        cell.alphaSpeed = -0.3
        cell.spinRange = 2
        cell.color = color.cgColor
        return cell
    }

    // slowly changing sideways push, makes the snow drift instead of falling straight down
    private static func windGusts(for cells: [String]) -> CAAnimationGroup {
        let values: [CGFloat] = [3, 10, -2, 14, 5, -4, 8, 3]
        let animations = cells.map { name -> CAKeyframeAnimation in
            let gust = CAKeyframeAnimation(keyPath: "emitterCells.\(name).xAcceleration")
            gust.values = values
            gust.calculationMode = .cubic
            return gust
        }
        let group = CAAnimationGroup()
        group.animations = animations
        group.duration = 48
        group.repeatCount = .infinity
        return group
    }

    // MARK: - Images

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

    // the ❄ symbol drawn white, used for the big flakes in front
    private static func makeCrystal(size: CGFloat) -> CGImage? {
        let config = NSImage.SymbolConfiguration(pointSize: size * 0.75, weight: .light)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        guard let symbol = NSImage(systemSymbolName: "snowflake", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return nil }

        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let symbolSize = symbol.size
            symbol.draw(in: NSRect(
                x: (rect.width - symbolSize.width) / 2,
                y: (rect.height - symbolSize.height) / 2,
                width: symbolSize.width,
                height: symbolSize.height
            ))
            return true
        }
        var rect = CGRect(x: 0, y: 0, width: size, height: size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
