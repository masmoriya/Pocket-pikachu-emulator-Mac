import SwiftUI

struct WatchFaceGuideView: View {
    var body: some View {
        List {
            Section("Add Pikachu") {
                Text("Touch and hold your watch face, then tap Edit.")
                Text("Swipe to Complications, tap a slot, then choose Pocket Pikachu.")
                Text("Press the Digital Crown to finish.")
            }
            Section("Layouts") {
                Label("Circular: Pikachu and step goal", systemImage: "circle")
                Label("Rectangular: pet, steps and watts", systemImage: "rectangle")
                Label("Inline: steps and watts", systemImage: "text.alignleft")
            }
            Section {
                Text("Tap Pikachu on your face to open the animated pet. Complications show your last saved data; open the app to sync steps.")
                Text("Apple controls the watch face and refresh timing. Pikachu animates inside the app.")
            }.font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle("Watch face")
    }
}
