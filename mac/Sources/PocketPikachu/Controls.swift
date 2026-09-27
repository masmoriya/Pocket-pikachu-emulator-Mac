import SwiftUI
import ServiceManagement
import PocketCore

struct ActionsView: View {
    @ObservedObject var model: CompanionModel
    @State private var gift = 50
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(model.pet.progression.steps) steps")
                Spacer()
                Text("\(model.pet.progression.watts) W").foregroundStyle(.secondary)
            }
            HStack {
                Button("Pet") { model.react("hearts") }
                Button("Feed") { model.react("toast", seconds: 12) }
                Button("Live freely") { model.select(nil) }
            }
            Picker("Friendship", selection: Binding(get: { model.pet.friendship }, set: model.friendship)) {
                ForEach(Friendship.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            Picker("Activity", selection: Binding(get: { model.pet.selectedActivity ?? "auto" }, set: { model.select($0 == "auto" ? nil : $0) })) {
                Text("Live freely").tag("auto")
                ForEach(model.library.clips) { Text($0.label).tag($0.id) }
            }
            HStack {
                Stepper("Gift: \(gift) W", value: $gift, in: 0...999)
                Button("Give") { model.give(Int64(gift)) }.disabled(Int64(gift) > model.pet.progression.watts)
            }
            HStack {
                Button("Animations…") { model.onOpenGallery?() }
                Spacer()
                Button("Settings…") { model.onOpenSettings?() }
            }
        }.padding(16).frame(width: 310).font(.custom("Verdana", size: 12))
    }
}
struct SettingsView: View {
    @ObservedObject var model: CompanionModel
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?
    private func binding<T>(_ key: WritableKeyPath<PetState, T>) -> Binding<T> {
        Binding(get: { model.pet[keyPath: key] }, set: { value in model.update { $0[keyPath: key] = value } })
    }
    var body: some View {
        Form {
            Section("Appearance") {
                Toggle("Click Pikachu to cycle activities", isOn: Binding(
                    get: { model.pet.cycleActivitiesOnClick ?? true },
                    set: { value in model.update { $0.cycleActivitiesOnClick = value } }
                ))
                Toggle("Menu bar only", isOn: Binding(get: { model.hidden }, set: { model.hidden = $0 }))
                Picker("Menu bar", selection: Binding(get: { model.pet.menuBarStyle ?? .paw }, set: { value in
                    model.update { $0.menuBarStyle = value }
                })) {
                    ForEach(MenuBarStyle.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Toggle("Color", isOn: binding(\.colored))
                Toggle("Pocket Pikachu shell", isOn: binding(\.shell))
                Toggle("Always on top", isOn: binding(\.alwaysOnTop))
                Picker("Pixel scale", selection: binding(\.scale)) {
                    ForEach(2...8, id: \.self) { Text("\($0)×").tag($0) }
                }
            }
            Section("Local Codex usage") {
                Text(model.status).foregroundStyle(.secondary)
                HStack {
                    Text(model.pet.codexHome.replacingOccurrences(of: NSHomeDirectory(), with: "~")).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Choose folder…") { chooseFolder() }
                }
                Picker("Tokens per step", selection: Binding(get: { model.pet.progression.tokensPerStep }, set: { value in model.update { $0.progression.tokensPerStep = value } })) {
                    ForEach([100, 1000, 10000, 100000], id: \.self) { Text($0.formatted()).tag(Int64($0)) }
                }
                Text("\(model.pet.progression.tokens.formatted()) tokens since setup").foregroundStyle(.secondary)
                Text("Input + output, including cached input once. No model requests or conversation uploads.")
                    .font(.custom("Verdana", size: 11)).foregroundStyle(.secondary)
                Button("Check now") { Task { await model.scan() } }
            }
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin).onChange(of: launchAtLogin) { _, value in
                    do {
                        if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        launchError = nil
                    } catch { launchError = error.localizedDescription }
                }
                if let launchError { Text(launchError).foregroundStyle(.red) }
                if let error = model.error { Text(error).foregroundStyle(.red) }
            }
        }.formStyle(.grouped).frame(width: 470, height: 500).font(.custom("Verdana", size: 12))
    }
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.showsHiddenFiles = true; panel.allowsMultipleSelection = false
        panel.message = "Choose the Codex home containing your sessions folder."
        if panel.runModal() == .OK, let url = panel.url { model.chooseHome(url.path) }
    }
}
