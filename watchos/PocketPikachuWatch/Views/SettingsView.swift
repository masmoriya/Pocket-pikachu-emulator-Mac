import SwiftUI
import WatchCore

struct SettingsView: View {
    @ObservedObject var model: CompanionModel
    var body: some View {
        List {
            Toggle("Color", isOn: setting(\.colored))
            Picker("Clock", selection: setting(\.clockFormat)) {
                Text("System").tag(GameSettings.ClockFormat.system)
                Text("12-hour").tag(GameSettings.ClockFormat.twelveHour)
                Text("24-hour").tag(GameSettings.ClockFormat.twentyFourHour)
            }
            Toggle("Haptics", isOn: setting(\.hapticsEnabled))
            Toggle("Steps", isOn: setting(\.showSteps))
            Toggle("Watts", isOn: setting(\.showWatts))
            Toggle("Reduce animation", isOn: setting(\.reducedAnimation))
            HealthConnectionView(model: model, steps: model.steps)
            Section("About") {
                Text("20 steps earn 1 watt. Gifts build friendship. All progress stays on this watch.")
                Text("Return to Clock is controlled in watch Settings → General → Return to Clock.")
                Text("Personal fan project. Pokémon artwork belongs to its respective owners.")
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
            }.font(.footnote)
        }.navigationTitle("Settings")
    }

    private func setting<Value>(_ keyPath: WritableKeyPath<GameSettings, Value>) -> Binding<Value> {
        Binding(get: { model.state.settings[keyPath: keyPath] }, set: { value in
            var settings = model.state.settings
            settings[keyPath: keyPath] = value
            model.updateSettings(settings)
        })
    }
}

private struct HealthConnectionView: View {
    @ObservedObject var model: CompanionModel
    @ObservedObject var steps: StepManager
    var body: some View {
        Section("Steps") {
            Button("Connect Health") { Task { await model.synchronize(authorize: true) } }
                .disabled(isLoading)
            Button("Sync steps") { Task { await model.synchronize() } }.disabled(isLoading)
            Text(statusText).font(.footnote).foregroundStyle(.secondary)
            Text("Allow step reading in Health permissions. If no data appears, check permissions and walk while wearing your watch.")
                .font(.footnote)
        }
    }
    private var isLoading: Bool { if case .loading = steps.status { true } else { false } }
    private var statusText: String {
        switch steps.status {
        case .unavailable: "Health is unavailable."
        case .idle: "Connect to read steps."
        case .loading: "Reading steps…"
        case .noData: "No accessible step data."
        case .ready: "Steps synced."
        case .failed(let message): message
        }
    }
}
