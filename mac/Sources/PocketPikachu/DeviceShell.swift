import AppKit

/// All geometry is in device units, shared with the controls and mouse hit testing.
@MainActor final class DeviceShell {
    static let size = NSSize(width: 76, height: 96)
    static let sprite = NSRect(x: 20, y: 20, width: 36, height: 30)

    static func outline() -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 20, y: 2))
        path.curve(to: NSPoint(x: 56, y: 2), controlPoint1: NSPoint(x: 29, y: 0), controlPoint2: NSPoint(x: 47, y: 0))
        path.curve(to: NSPoint(x: 67, y: 13), controlPoint1: NSPoint(x: 63, y: 3), controlPoint2: NSPoint(x: 66, y: 6))
        path.curve(to: NSPoint(x: 74, y: 76), controlPoint1: NSPoint(x: 70, y: 29), controlPoint2: NSPoint(x: 74, y: 56))
        path.curve(to: NSPoint(x: 58, y: 92), controlPoint1: NSPoint(x: 74, y: 86), controlPoint2: NSPoint(x: 69, y: 91))
        path.curve(to: NSPoint(x: 18, y: 92), controlPoint1: NSPoint(x: 47, y: 95), controlPoint2: NSPoint(x: 29, y: 95))
        path.curve(to: NSPoint(x: 2, y: 76), controlPoint1: NSPoint(x: 7, y: 91), controlPoint2: NSPoint(x: 2, y: 86))
        path.curve(to: NSPoint(x: 9, y: 13), controlPoint1: NSPoint(x: 2, y: 56), controlPoint2: NSPoint(x: 6, y: 29))
        path.curve(to: NSPoint(x: 20, y: 2), controlPoint1: NSPoint(x: 10, y: 6), controlPoint2: NSPoint(x: 13, y: 3))
        path.close()
        return path
    }

    func draw(scale: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
        let body = Self.outline()
        body.addClip()
        NSGradient(colors: [NSColor(red: 1, green: 0.86, blue: 0.23, alpha: 1),
                            NSColor(red: 1, green: 0.74, blue: 0.01, alpha: 1),
                            NSColor(red: 0.84, green: 0.56, blue: 0, alpha: 1)])?.draw(in: body, angle: 75)
        NSColor(red: 0.61, green: 0.40, blue: 0.02, alpha: 1).setStroke()
        body.lineWidth = 1.6; body.stroke()
        let highlight = Self.outline()
        highlight.transform(using: AffineTransform(translationByX: 0, byY: -0.8))
        NSColor(white: 1, alpha: 0.65).setStroke(); highlight.lineWidth = 0.6; highlight.stroke()
        let bezel = NSBezierPath()
        bezel.move(to: NSPoint(x: 19, y: 8))
        bezel.curve(to: NSPoint(x: 57, y: 8), controlPoint1: NSPoint(x: 29, y: 6), controlPoint2: NSPoint(x: 47, y: 6))
        bezel.curve(to: NSPoint(x: 63, y: 14), controlPoint1: NSPoint(x: 61, y: 8), controlPoint2: NSPoint(x: 62, y: 10))
        bezel.line(to: NSPoint(x: 67, y: 52))
        bezel.curve(to: NSPoint(x: 62, y: 58), controlPoint1: NSPoint(x: 68, y: 56), controlPoint2: NSPoint(x: 66, y: 58))
        bezel.line(to: NSPoint(x: 14, y: 58))
        bezel.curve(to: NSPoint(x: 9, y: 52), controlPoint1: NSPoint(x: 10, y: 58), controlPoint2: NSPoint(x: 8, y: 56))
        bezel.line(to: NSPoint(x: 13, y: 14))
        bezel.curve(to: NSPoint(x: 19, y: 8), controlPoint1: NSPoint(x: 14, y: 10), controlPoint2: NSPoint(x: 15, y: 8))
        bezel.close()
        NSGradient(starting: NSColor(red: 0.26, green: 0.29, blue: 0.38, alpha: 1),
                   ending: NSColor(red: 0.12, green: 0.14, blue: 0.21, alpha: 1))?.draw(in: bezel, angle: 90)
        NSColor(white: 0.7, alpha: 1).setStroke(); bezel.lineWidth = 0.6; bezel.stroke()
        let lcd = NSBezierPath(roundedRect: NSRect(x: 18, y: 17, width: 40, height: 35), xRadius: 2, yRadius: 2)
        NSGradient(starting: NSColor(red: 0.65, green: 0.72, blue: 0.56, alpha: 1),
                   ending: NSColor(red: 0.78, green: 0.83, blue: 0.67, alpha: 1))?.draw(in: lcd, angle: 90)
        label("Pokémon Pikachu", rect: NSRect(x: 14, y: 54, width: 48, height: 4), size: 3.4, color: .white)
        label("Nintendo", rect: NSRect(x: 27, y: 60, width: 22, height: 4), size: 3, color: NSColor(red: 0.51, green: 0.34, blue: 0, alpha: 1))
        // Continuous base under the four independently interactive D-pad arms.
        let cross = NSBezierPath(roundedRect: NSRect(x: 10, y: 72, width: 20, height: 7), xRadius: 1, yRadius: 1)
        cross.append(NSBezierPath(roundedRect: NSRect(x: 16.5, y: 65.5, width: 7, height: 20), xRadius: 1, yRadius: 1))
        NSColor(white: 0.12, alpha: 1).setFill(); cross.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func label(_ text: String, rect: NSRect, size: CGFloat, color: NSColor) {
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
        (text as NSString).draw(in: rect, withAttributes: [.font: NSFont(name: "Verdana", size: size)!,
            .foregroundColor: color, .paragraphStyle: paragraph])
    }

    func contains(_ point: NSPoint, scale: CGFloat) -> Bool {
        Self.outline().contains(NSPoint(x: point.x / scale, y: point.y / scale))
    }
}
