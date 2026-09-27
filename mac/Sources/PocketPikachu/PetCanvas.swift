import AppKit
import Combine
import PocketCore

@MainActor final class PetCanvas: NSView {
    let model: CompanionModel
    var clicked: (() -> Void)?
    var moved: (() -> Void)?
    var frameChanged: (() -> Void)?
    private let shell = DeviceShell()
    private var shellButtons: [ShellButton] = []
    private var subscriptions = Set<AnyCancellable>()
    private var timer: Timer?
    private var down: NSPoint?
    private var origin: NSPoint?
    private var dragged = false
    private(set) var frameID = "standLove.tailRightUp"
    override var isFlipped: Bool { true }
    var spriteRect: NSRect {
        let scale = CGFloat(model.pet.scale)
        return NSRect(x: model.pet.shell ? DeviceShell.sprite.minX * scale : 0, y: model.pet.shell ? DeviceShell.sprite.minY * scale : 0,
                      width: 36 * scale, height: 30 * scale)
    }
    init(model: CompanionModel) {
        self.model = model
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Pikachu · open pet controls")
        model.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.refresh() }
        }.store(in: &subscriptions)
        shellButtons = ShellButton.Action.allCases.map { command in
            let button = ShellButton(command) { [weak self] in self?.perform($0) }
            addSubview(button)
            return button
        }
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    private func refresh() {
        timer?.invalidate(); timer = nil
        needsDisplay = true
        setAccessibilityRole(model.pet.shell ? .group : .button)
        setAccessibilityLabel(model.pet.shell ? "Pocket Pikachu" : "Pikachu · open pet controls")
        for button in shellButtons { button.isHidden = !model.pet.shell }
        needsLayout = true
        guard model.animating else { return }
        scheduleFrame()
    }
    override func layout() {
        super.layout()
        let scale = CGFloat(model.pet.scale)
        for button in shellButtons {
            let rect = button.command.rect
            button.frame = NSRect(x: rect.minX * scale, y: rect.minY * scale,
                                  width: rect.width * scale, height: rect.height * scale)
        }
    }
    private func perform(_ command: ShellButton.Action) {
        switch command {
        case .previous, .next:
            let clips = model.library.clips
            guard !clips.isEmpty else { return }
            let current = clips.firstIndex { $0.id == model.activity } ?? 0
            let next = (current + (command == .next ? 1 : clips.count - 1)) % clips.count
            model.select(clips[next].id)
        case .pet: model.react("hearts")
        case .feed: model.react("toast", seconds: 12)
        case .controls, .status: clicked?()
        case .live: model.select(nil)
        case .gallery: model.onOpenGallery?()
        case .settings: model.onOpenSettings?()
        }
    }
    private func clickPet() {
        guard model.pet.cycleActivitiesOnClick ?? true else { clicked?(); return }
        let clips = model.library.clips
        guard !clips.isEmpty else { return }
        guard let current = clips.firstIndex(where: { $0.id == model.activity }) else {
            model.select(clips[0].id)
            return
        }
        if current == clips.count - 1 { model.select(nil) }
        else { model.select(clips[current + 1].id) }
    }
    private func scheduleFrame() {
        guard let clip = model.currentClip else { return }
        let elapsed = Date.now.timeIntervalSince(model.activityStarted)
        let sample = clip.sample(at: elapsed, repeatFinite: model.pet.selectedActivity != nil)
        frameID = sample.frame
        frameChanged?()
        needsDisplay = true
        // Original animation cadence, including 125ms blocks; no 60fps idle loop.
        timer = Timer.scheduledTimer(withTimeInterval: max(0.01, sample.remaining), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleFrame() }
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let frame = model.frames[frameID] else { return }
        if model.pet.shell { shell.draw(scale: CGFloat(model.pet.scale)) }
        NSGraphicsContext.current?.imageInterpolation = .none
        PixelRenderer.shared.image(frame, colored: model.pet.colored)
            .draw(in: spriteRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }
    func opaque(at point: NSPoint) -> Bool {
        if model.pet.shell { return shell.contains(point, scale: CGFloat(model.pet.scale)) }
        guard spriteRect.contains(point), let frame = model.frames[frameID] else { return false }
        let x = Int((point.x - spriteRect.minX) / CGFloat(model.pet.scale))
        let y = Int((point.y - spriteRect.minY) / CGFloat(model.pet.scale))
        return PixelRenderer.shared.opaque(frame, colored: model.pet.colored, x: x, y: y)
    }
    override func accessibilityPerformPress() -> Bool { clickPet(); return true }
    override func mouseDown(with event: NSEvent) {
        down = NSEvent.mouseLocation; origin = window?.frame.origin; dragged = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard let down, let origin else { return }
        let cursor = NSEvent.mouseLocation
        if hypot(cursor.x - down.x, cursor.y - down.y) > 3 { dragged = true }
        if dragged { window?.setFrameOrigin(NSPoint(x: origin.x + cursor.x - down.x, y: origin.y + cursor.y - down.y)) }
    }
    override func mouseUp(with event: NSEvent) {
        if dragged { moved?() } else { clickPet() }
        down = nil; origin = nil
    }
    override func rightMouseDown(with event: NSEvent) { clicked?() }
}
