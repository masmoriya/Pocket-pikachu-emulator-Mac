import AppKit
import SwiftUI

@main struct PocketPikachuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("Settings…") { delegate.openSettings() }.keyboardShortcut(",")
                }
                CommandGroup(after: .appInfo) {
                    Button("Pet controls") { delegate.openControls() }.keyboardShortcut("p", modifiers: [.command, .shift])
                    Button("Animation gallery") { delegate.openGallery() }.keyboardShortcut("a", modifiers: [.command, .shift])
                }
            }
    }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: CompanionModel?
    private var companion: CompanionWindow?
    private var item: NSStatusItem?
    private var menuBarPet: MenuBarPet?
    private let actions = NSPopover()
    private var settings: NSWindow?
    private var gallery: NSWindow?
    private var workspaceObservers: [NSObjectProtocol] = []
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        do {
            let model = try CompanionModel()
            self.model = model
            PixelRenderer.shared.configure(model.library.frames)
            companion = CompanionWindow(model: model)
            model.onOpenSettings = { [weak self] in self?.openSettings() }
            model.onOpenGallery = { [weak self] in self?.openGallery() }
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Pocket Pikachu")
            let menu = NSMenu()
            for (label, action) in [("Pet controls…", #selector(openActions)), ("Show desktop widget", #selector(showPet)), ("Menu bar only", #selector(hidePet)),
                                    ("Animations…", #selector(openGallery)), ("Settings…", #selector(openSettings)),
                                    ("Quit", #selector(quit))] {
                let entry = menu.addItem(withTitle: label, action: action, keyEquivalent: "")
                entry.target = self
            }
            item.menu = menu; self.item = item
            menuBarPet = MenuBarPet(model: model, item: item)
            actions.behavior = .transient
            actions.contentViewController = NSHostingController(rootView: ActionsView(model: model))
            let center = NSWorkspace.shared.notificationCenter
            workspaceObservers.append(center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak model] _ in
                MainActor.assumeIsolated { model?.sleepingDisplay = true }
            })
            workspaceObservers.append(center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak model] _ in
                MainActor.assumeIsolated { model?.sleepingDisplay = false; model?.activityStarted = .now }
            })
            model.start()
            if model.saved.ledger.startedAt == nil { openSettings() }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Pocket Pikachu could not start"
            alert.informativeText = error.localizedDescription
            alert.runModal(); NSApp.terminate(nil)
        }
    }
    func applicationWillTerminate(_ notification: Notification) { model?.persist() }
    @objc private func openActions() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let button = self.item?.button else { return }
            self.model?.interact()
            self.actions.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    func openControls() {
        if model?.hidden == true { openActions() }
        else { companion?.showActions() }
    }
    @objc private func showPet() { companion?.show() }
    @objc private func hidePet() { model?.hidden = true }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc func openSettings() {
        guard let model else { return }
        if settings == nil { settings = makeWindow("Pocket Pikachu settings", view: SettingsView(model: model)) }
        settings?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func openGallery() {
        guard let model else { return }
        if gallery == nil { gallery = makeWindow("Animation gallery", view: GalleryView(model: model)) }
        gallery?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    private func makeWindow<V: View>(_ title: String, view: V) -> NSWindow {
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = title; window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false; window.center()
        return window
    }
}
