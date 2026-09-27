import AppKit

@MainActor final class ShellButton: NSButton {
    enum Action: CaseIterable {
        case previous, next, pet, feed, controls, live, status, gallery, settings
        var label: String {
            switch self {
            case .previous: return "Previous activity"
            case .next: return "Next activity"
            case .pet: return "Pet Pikachu"
            case .feed: return "Feed Pikachu"
            case .controls: return "Open pet controls"
            case .live: return "Live freely"
            case .status: return "Steps, watts, and gifts"
            case .gallery: return "Animation gallery"
            case .settings: return "Settings"
            }
        }
        var rect: NSRect {
            switch self {
            case .previous: return NSRect(x: 10, y: 72, width: 7, height: 7)
            case .next: return NSRect(x: 23, y: 72, width: 7, height: 7)
            case .pet: return NSRect(x: 16.5, y: 65.5, width: 7, height: 7)
            case .feed: return NSRect(x: 16.5, y: 78.5, width: 7, height: 7)
            case .controls: return NSRect(x: 59, y: 65, width: 9, height: 9)
            case .live: return NSRect(x: 44, y: 72, width: 9, height: 9)
            case .status: return NSRect(x: 28, y: 86, width: 10, height: 5)
            case .gallery: return NSRect(x: 45, y: 86, width: 10, height: 5)
            case .settings: return NSRect(x: 59, y: 81, width: 6, height: 6)
            }
        }
        var direction: Int? {
            switch self {
            case .pet: return 0
            case .next: return 1
            case .feed: return 2
            case .previous: return 3
            default: return nil
            }
        }
    }
    let command: Action
    private let perform: (Action) -> Void
    init(_ command: Action, perform: @escaping (Action) -> Void) {
        self.command = command; self.perform = perform
        super.init(frame: .zero)
        title = ""; isBordered = false; setButtonType(.momentaryChange)
        target = self; action = #selector(activate)
        toolTip = command.label; setAccessibilityLabel(command.label)
        focusRingType = .exterior
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    @objc private func activate() { perform(command) }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        Self.paint(command, in: bounds, pressed: isHighlighted)
    }
    static func paint(_ command: Action, in bounds: NSRect, pressed: Bool = false) {
        let scale = bounds.width / command.rect.width
        let rect = bounds.insetBy(dx: scale * 0.4, dy: scale * 0.4)
        let shape = command.direction == nil ? NSBezierPath(ovalIn: rect) : NSBezierPath(roundedRect: rect, xRadius: scale, yRadius: scale)
        NSGradient(starting: NSColor(white: pressed ? 0.14 : 0.36, alpha: 1),
                   ending: NSColor(white: 0.10, alpha: 1))?.draw(in: shape, angle: 70)
        NSColor(white: 0.06, alpha: 1).setStroke(); shape.lineWidth = scale * 0.5; shape.stroke()
        if let direction = command.direction {
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: bounds.midX, yBy: bounds.midY)
            transform.rotate(byDegrees: CGFloat(direction) * 90); transform.concat()
            let arrow = NSBezierPath()
            arrow.move(to: NSPoint(x: 0, y: -1.5 * scale))
            arrow.line(to: NSPoint(x: 1.4 * scale, y: scale))
            arrow.line(to: NSPoint(x: -1.4 * scale, y: scale)); arrow.close()
            NSColor(white: pressed ? 0.6 : 0.16, alpha: 1).setFill(); arrow.fill()
            NSGraphicsContext.restoreGraphicsState()
        }
    }
}
