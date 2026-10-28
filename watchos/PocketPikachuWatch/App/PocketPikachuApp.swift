import SwiftUI

@main struct PocketPikachuApp: App {
    @StateObject private var model = CompanionModel()
    @Environment(\.scenePhase) private var phase
    @State private var showingMenu = false

    var body: some Scene {
        WindowGroup {
            Group {
                if model.isLoaded { ClockView(model: model, showingMenu: $showingMenu) }
                else {
                    VStack {
                        Text("Save needs attention")
                        Text(model.errorMessage ?? "Unable to load save.").font(.footnote)
                        Button("Retry") { model.load() }
                    }
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showingMenu) {
                NavigationStack {
                    MenuView(model: model, returnToClock: { showingMenu = false })
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showingMenu = false }
                            }
                        }
                }
            }
            .onOpenURL { url in
                if url.scheme == "pocketpikachu" { showingMenu = false }
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
