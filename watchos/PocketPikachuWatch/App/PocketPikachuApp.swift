import SwiftUI

@main struct PocketPikachuApp: App {
    @StateObject private var model = CompanionModel()
    @Environment(\.scenePhase) private var phase
    @State private var path = NavigationPath()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                if model.isLoaded { ClockView(model: model, path: $path) }
                else {
                    VStack {
                        Text("Save needs attention")
                        Text(model.errorMessage ?? "Unable to load save.").font(.footnote)
                        Button("Retry") { model.load() }
                    }
                }
            }
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                if url.scheme == "pocketpikachu" { path = NavigationPath() }
            }
            .task { await model.synchronize() }
            .onChange(of: phase) { _, value in
                if value == .active { Task { await model.synchronize() } }
                else { model.save() }
            }
            .alert("Pocket Pikachu", isPresented: Binding(
                get: { model.isLoaded && model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) { Button("OK") { model.errorMessage = nil } }
                message: { Text(model.errorMessage ?? "") }
        }
    }
}
