import AppKit
import SwiftUI

@MainActor final class CompanionWindow {
    let panel: NSPanel
    private let canvas: PetCanvas
    private let model: CompanionModel
    private let popover = NSPopover()
    private var monitors: [Any] = []
    private var observers: [NSObjectProtocol] = []
    private var currentArrangement = ""
    init(model: CompanionModel) {
        self.model = model
        canvas = PetCanvas(model: model)
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.hidesOnDeactivate = false; panel.isFloatingPanel = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.contentView = canvas
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ActionsView(model: model))
        canvas.clicked = { [weak self] in self?.showActions() }
        canvas.moved = { [weak self] in self?.rememberPosition() }
        canvas.frameChanged = { [weak self] in self?.updateHitTesting() }
        model.onPlacementChange = { [weak self] in self?.configure() }
        let monitor: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.updateHitTesting() }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseUp], handler: monitor) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseUp], handler: { event in monitor(event); return event }) { monitors.append(local) }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.configure() }
        })
        configure()
    }
    private func configure() {
        let scale = CGFloat(model.pet.scale)
        let size = NSSize(width: (model.pet.shell ? DeviceShell.size.width : 36) * scale, height: (model.pet.shell ? DeviceShell.size.height : 30) * scale)
        let key = arrangement
        let position = model.pet.positions[key]
        var origin = panel.frame.origin
        if currentArrangement != key || panel.frame.size == .zero {
            origin = position.map { NSPoint(x: $0[0], y: $0[1]) } ?? NSPoint(x: NSScreen.main?.visibleFrame.minX ?? 20, y: (NSScreen.main?.visibleFrame.minY ?? 20) + 20)
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.level = model.pet.alwaysOnTop ? .floating : NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        currentArrangement = key
        clampToScreen(); updateHitTesting()
        if model.hidden {
            popover.close()
            panel.orderOut(nil)
        } else if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }
    private var arrangement: String {
        NSScreen.screens.map { screen in
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            return "\(number?.stringValue ?? "0"):\(NSStringFromRect(screen.frame))"
        }.sorted().joined(separator: "|")
    }
    private func clampToScreen() {
        let screen = NSScreen.screens.max { a, b in
            let aRect = a.visibleFrame.intersection(panel.frame), bRect = b.visibleFrame.intersection(panel.frame)
            return aRect.width * aRect.height < bRect.width * bRect.height
        } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let origin = NSPoint(x: max(visible.minX, min(panel.frame.minX, visible.maxX - panel.frame.width)),
                             y: max(visible.minY, min(panel.frame.minY, visible.maxY - panel.frame.height)))
        panel.setFrameOrigin(origin)
    }
    private func rememberPosition() {
        clampToScreen()
        model.saved.pet.positions[arrangement] = [panel.frame.minX, panel.frame.minY]
        model.interact()
    }
    private func updateHitTesting() {
        guard NSEvent.pressedMouseButtons == 0 else { return }
        let windowPoint = panel.convertPoint(fromScreen: NSEvent.mouseLocation)
        let local = canvas.convert(windowPoint, from: nil)
        panel.ignoresMouseEvents = !canvas.opaque(at: local)
    }
    func showActions() {
        model.interact()
        panel.ignoresMouseEvents = false
        popover.show(relativeTo: canvas.bounds, of: canvas, preferredEdge: .maxY)
    }
    func show() { model.hidden = false; panel.orderFrontRegardless() }
}
