import AppKit

enum MenuBarIcon {
    static func make(progress: Double) -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let outerRadius: CGFloat = 6.5
            let strokeWidth: CGFloat = 1.5
            let fillRadius: CGFloat = outerRadius - strokeWidth

            NSColor.black.setStroke()
            NSColor.black.setFill()

            let circleRect = CGRect(
                x: center.x - outerRadius, y: center.y - outerRadius,
                width: outerRadius * 2, height: outerRadius * 2
            )
            let circle = NSBezierPath(ovalIn: circleRect)
            circle.lineWidth = strokeWidth
            circle.stroke()

            let clamped = min(1.0, max(0.0, progress))
            guard clamped > 0.005 else { return true }

            if clamped >= 0.995 {
                let fillRect = CGRect(
                    x: center.x - fillRadius, y: center.y - fillRadius,
                    width: fillRadius * 2, height: fillRadius * 2
                )
                NSBezierPath(ovalIn: fillRect).fill()
            } else {
                let startAngle: CGFloat = 90
                let endAngle = 90 - 360 * clamped
                let sector = NSBezierPath()
                sector.move(to: center)
                sector.appendArc(
                    withCenter: center, radius: fillRadius,
                    startAngle: startAngle, endAngle: endAngle,
                    clockwise: true
                )
                sector.close()
                sector.fill()
            }

            return true
        }
        image.isTemplate = true
        return image
    }
}
