import AppKit
import QuartzCore

// snowman and snowball, built from plain layers so they stay sharp at any size
enum SnowDecorations {
    private static let snowShade = NSColor(calibratedRed: 0.82, green: 0.87, blue: 0.94, alpha: 1)
    private static let coal = NSColor(white: 0.12, alpha: 1)
    private static let carrot = NSColor(calibratedRed: 0.96, green: 0.5, blue: 0.15, alpha: 1)
    private static let wood = NSColor(calibratedRed: 0.4, green: 0.26, blue: 0.16, alpha: 1)
    private static let santaRed = NSColor(calibratedRed: 0.85, green: 0.12, blue: 0.16, alpha: 1)
    private static let winterBlue = NSColor(calibratedRed: 0.25, green: 0.5, blue: 0.95, alpha: 1)

    // MARK: - Snowman

    // anchored at the bottom center, so `position` is where he stands
    static func snowman(festive: Bool, scale: CGFloat) -> CALayer {
        let root = CALayer()
        root.bounds = CGRect(x: 0, y: 0, width: 44, height: 72)
        root.anchorPoint = CGPoint(x: 0.5, y: 0)
        root.contentsScale = scale
        root.shadowColor = NSColor.black.cgColor
        root.shadowOpacity = 0.22
        root.shadowRadius = 2
        root.shadowOffset = CGSize(width: 0, height: -1)

        // arms first so they sit behind the body
        root.addSublayer(stroke([CGPoint(x: 14, y: 36), CGPoint(x: 4, y: 43)], color: wood, width: 1.5))
        root.addSublayer(stroke([CGPoint(x: 7, y: 41), CGPoint(x: 5, y: 46)], color: wood, width: 1.2))
        root.addSublayer(stroke([CGPoint(x: 30, y: 36), CGPoint(x: 40, y: 44)], color: wood, width: 1.5))
        root.addSublayer(stroke([CGPoint(x: 37, y: 42), CGPoint(x: 41, y: 40)], color: wood, width: 1.2))

        root.addSublayer(snowBall(center: CGPoint(x: 22, y: 13), radius: 13))
        root.addSublayer(snowBall(center: CGPoint(x: 22, y: 33), radius: 9.5))
        root.addSublayer(snowBall(center: CGPoint(x: 22, y: 49), radius: 7))

        for y in [17, 31, 36] as [CGFloat] {
            root.addSublayer(dot(center: CGPoint(x: 22, y: y), radius: 1.1, color: coal))
        }
        root.addSublayer(dot(center: CGPoint(x: 19.6, y: 50.8), radius: 1.1, color: coal))
        root.addSublayer(dot(center: CGPoint(x: 24.4, y: 50.8), radius: 1.1, color: coal))
        root.addSublayer(fill([CGPoint(x: 22.5, y: 47.6), CGPoint(x: 22.5, y: 49.6), CGPoint(x: 29.5, y: 48.2)], color: carrot))

        let scarfColor = festive ? santaRed : winterBlue
        root.addSublayer(roundedRect(CGRect(x: 15, y: 40.5, width: 14, height: 3.6), color: scarfColor))
        root.addSublayer(roundedRect(CGRect(x: 24.5, y: 33.5, width: 3.6, height: 8), color: scarfColor))

        if festive {
            root.addSublayer(fill([CGPoint(x: 15, y: 54.5), CGPoint(x: 29, y: 54.5), CGPoint(x: 32, y: 66)], color: santaRed))
            root.addSublayer(roundedRect(CGRect(x: 13.5, y: 53, width: 17, height: 3.6), color: .white))
            root.addSublayer(dot(center: CGPoint(x: 32, y: 66.5), radius: 2.4, color: .white))
        }
        return root
    }

    static func popIn(_ layer: CALayer) {
        let spring = CASpringAnimation(keyPath: "transform.scale")
        spring.fromValue = 0.01
        spring.toValue = 1
        spring.damping = 9
        spring.stiffness = 160
        spring.mass = 1
        spring.duration = spring.settlingDuration
        layer.add(spring, forKey: "pop")

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.25
        layer.add(fade, forKey: "fade")
    }

    static func topple(_ layer: CALayer) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.5)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
        CATransaction.setCompletionBlock { layer.removeFromSuperlayer() }
        var transform = CATransform3DMakeTranslation(10, -30, 0)
        transform = CATransform3DRotate(transform, -0.9, 0, 0, 1)
        layer.transform = transform
        layer.opacity = 0
        CATransaction.commit()
    }

    // MARK: - Snowball

    // rolls along a window's snow, grows a bit, then drops off the end
    static func rollSnowball(on parent: CALayer, from startX: CGFloat, to endX: CGFloat, baseY: CGFloat) {
        let radius: CGFloat = 7
        let size = CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2)

        let mover = CALayer()
        mover.bounds = size
        mover.anchorPoint = CGPoint(x: 0.5, y: 0)
        mover.position = CGPoint(x: startX, y: baseY)
        mover.contentsScale = parent.contentsScale
        mover.shadowColor = NSColor.black.cgColor
        mover.shadowOpacity = 0.22
        mover.shadowRadius = 1.5
        mover.shadowOffset = CGSize(width: 0, height: -1)
        mover.shadowPath = CGPath(ellipseIn: size, transform: nil)

        let ball = snowBall(center: CGPoint(x: radius, y: radius), radius: radius)
        // a few darker spots so you can actually see it rolling
        for (x, y, r) in [(4.5, 9.0, 1.6), (9.5, 4.5, 1.2), (10.5, 10.5, 1.0)] as [(CGFloat, CGFloat, CGFloat)] {
            ball.addSublayer(dot(center: CGPoint(x: x, y: y), radius: r, color: snowShade.withAlphaComponent(0.9)))
        }
        mover.addSublayer(ball)
        parent.addSublayer(mover)

        let distance = endX - startX
        let duration = CFTimeInterval(distance / 60)
        let timing = CAMediaTimingFunction(controlPoints: 0.4, 0, 0.8, 1)

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            dropOff(mover, ball: ball, from: CGPoint(x: endX, y: baseY))
        }

        let move = CABasicAnimation(keyPath: "position.x")
        move.fromValue = startX
        move.toValue = endX

        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = 0.5
        grow.toValue = 1.3

        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0
        fadeIn.toValue = 1
        fadeIn.duration = 0.4

        let roll = CAAnimationGroup()
        roll.animations = [move, grow, fadeIn]
        roll.duration = duration
        roll.timingFunction = timing
        roll.fillMode = .forwards
        roll.isRemovedOnCompletion = false
        mover.add(roll, forKey: "roll")

        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.byValue = -(distance / radius)
        spin.duration = duration
        spin.timingFunction = timing
        spin.fillMode = .forwards
        spin.isRemovedOnCompletion = false
        ball.add(spin, forKey: "spin")

        CATransaction.commit()
    }

    private static func dropOff(_ mover: CALayer, ball: CALayer, from point: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mover.position = point
        mover.transform = CATransform3DMakeScale(1.3, 1.3, 1)
        mover.removeAnimation(forKey: "roll")
        CATransaction.commit()

        CATransaction.begin()
        CATransaction.setCompletionBlock { mover.removeFromSuperlayer() }

        let drop = CABasicAnimation(keyPath: "position")
        drop.fromValue = NSValue(point: point)
        drop.toValue = NSValue(point: CGPoint(x: point.x + 40, y: point.y - 220))
        drop.timingFunction = CAMediaTimingFunction(name: .easeIn)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.beginTime = 0.4
        fade.duration = 0.35
        fade.fillMode = .both

        let fall = CAAnimationGroup()
        fall.animations = [drop, fade]
        fall.duration = 0.75
        fall.fillMode = .forwards
        fall.isRemovedOnCompletion = false
        mover.add(fall, forKey: "fall")

        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.byValue = -5
        spin.duration = 0.75
        spin.isAdditive = true
        ball.add(spin, forKey: "fallSpin")

        CATransaction.commit()
    }

    // MARK: - Shapes

    // white ball with a soft blue-grey shade on the bottom right
    private static func snowBall(center: CGPoint, radius: CGFloat) -> CALayer {
        let ball = CAGradientLayer()
        ball.type = .radial
        ball.frame = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        ball.colors = [NSColor.white.cgColor, NSColor.white.cgColor, snowShade.cgColor]
        ball.locations = [0, 0.45, 1]
        ball.startPoint = CGPoint(x: 0.35, y: 0.68)
        ball.endPoint = CGPoint(x: 1.05, y: -0.05)
        ball.cornerRadius = radius
        ball.masksToBounds = true
        return ball
    }

    private static func dot(center: CGPoint, radius: CGFloat, color: NSColor) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        layer.cornerRadius = radius
        layer.backgroundColor = color.cgColor
        return layer
    }

    private static func roundedRect(_ rect: CGRect, color: NSColor) -> CALayer {
        let layer = CALayer()
        layer.frame = rect
        layer.cornerRadius = min(rect.width, rect.height) / 2
        layer.backgroundColor = color.cgColor
        return layer
    }

    private static func fill(_ points: [CGPoint], color: NSColor) -> CAShapeLayer {
        let path = CGMutablePath()
        path.addLines(between: points)
        path.closeSubpath()
        let layer = CAShapeLayer()
        layer.path = path
        layer.fillColor = color.cgColor
        layer.lineJoin = .round
        return layer
    }

    private static func stroke(_ points: [CGPoint], color: NSColor, width: CGFloat) -> CAShapeLayer {
        let path = CGMutablePath()
        path.addLines(between: points)
        let layer = CAShapeLayer()
        layer.path = path
        layer.strokeColor = color.cgColor
        layer.fillColor = nil
        layer.lineWidth = width
        layer.lineCap = .round
        return layer
    }
}
