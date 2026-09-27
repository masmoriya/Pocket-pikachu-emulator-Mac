import AppKit
import Combine
import PocketCore

/// Uses the companion's activity clock even when its desktop window is hidden.
@MainActor final class MenuBarPet {
    private let model: CompanionModel
    private let item: NSStatusItem
    private var subscription: AnyCancellable?
    private var timer: Timer?
    private var images: [String: NSImage] = [:]

    init(model: CompanionModel, item: NSStatusItem) {
        self.model = model
        self.item = item
        subscription = model.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.refresh() }
        }
        refresh()
    }

    private func refresh() {
        timer?.invalidate()
        timer = nil
        let style = model.pet.menuBarStyle ?? .paw
        guard style != .paw else {
            item.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Pocket Pikachu")
            item.button?.toolTip = "Pocket Pikachu"
            return
        }
        let sample = model.sample()
        if let frame = model.frames[sample.frame] {
            item.button?.image = image(frame, style: style)
        }
        item.button?.toolTip = "Pocket Pikachu · \(model.activityLabel) · \(model.pet.progression.steps) steps · \(model.pet.progression.watts) W"
        guard !model.sleepingDisplay else { return }
        let timer = Timer(timeInterval: max(0.01, sample.remaining), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        self.timer = timer
        // Keep animating while the status menu is open, at the original frame cadence.
        RunLoop.main.add(timer, forMode: .common)
    }

    private func image(_ frame: PixelFrame, style: MenuBarStyle) -> NSImage {
        let key = "\(frame.id)-\(style.rawValue)"
        if let cached = images[key] { return cached }
        let source = PixelRenderer.shared.image(frame, colored: style == .color)
        let size = NSSize(width: 24, height: 20)
        let image = NSImage(size: size, flipped: false) { rect in
            NSGraphicsContext.current?.imageInterpolation = .none
            source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        // macOS tints the transparent monochrome sprite for the current menu bar.
        image.isTemplate = style == .monochrome
        image.accessibilityDescription = "Pocket Pikachu"
        images[key] = image
        return image
    }
}
