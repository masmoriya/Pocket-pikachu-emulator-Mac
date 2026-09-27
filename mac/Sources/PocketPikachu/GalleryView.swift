import SwiftUI
import PocketCore

struct GalleryView: View {
    @ObservedObject var model: CompanionModel
    @State private var selected = "love"
    @State private var search = ""
    @StateObject private var playback = GalleryPlayback()
    @State private var showFrames = false
    private var clip: AnimationClip? { model.clips[selected] }
    private var steps: [AnimationStep] { clip?.steps ?? [] }
    var body: some View {
        HSplitView {
            VStack(alignment: .leading) {
                TextField("Search animations", text: $search)
                Toggle("Individual frames", isOn: $showFrames)
                List(selection: $selected) {
                    if showFrames {
                        ForEach(model.library.frames.filter { search.isEmpty || $0.id.localizedCaseInsensitiveContains(search) }) { frame in
                            Text(frame.id).tag(frame.id)
                        }
                    } else {
                        ForEach(model.library.clips.filter { search.isEmpty || $0.label.localizedCaseInsensitiveContains(search) }) { clip in
                            Text(clip.label).tag(clip.id)
                        }
                    }
                }
                Text("\(model.library.sourceFrameCount) frames · \(model.library.clips.count) sequences")
                    .foregroundStyle(.secondary).font(.custom("Verdana", size: 10))
            }.padding(12).frame(minWidth: 220, idealWidth: 250, maxWidth: 280)
            VStack(spacing: 18) {
                Group {
                    let id = showFrames ? selected : steps[safe: playback.index]?.frame
                    if let id, let frame = model.frames[id] {
                        HStack(spacing: 20) {
                            preview(frame, colored: false)
                            preview(frame, colored: true)
                        }
                        Text(id).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }
                if !showFrames {
                    HStack {
                        Button("Previous", systemImage: "backward.frame") { playback.step(-1) }
                            .keyboardShortcut(.leftArrow, modifiers: [])
                        Button(playback.playing ? "Pause" : "Play", systemImage: playback.playing ? "pause" : "play") { playback.toggle() }
                        Button("Next", systemImage: "forward.frame") { playback.step(1) }
                            .keyboardShortcut(.rightArrow, modifiers: [])
                    }
                    Text("Frame \(playback.index + 1) of \(steps.count)").foregroundStyle(.secondary)
                    Button("Use this activity") { model.select(selected) }
                }
            }.padding(20).frame(minWidth: 470, maxWidth: .infinity, maxHeight: .infinity)
        }
        .onMoveCommand { direction in
            guard !showFrames else { return }
            switch direction {
            case .left: playback.step(-1)
            case .right: playback.step(1)
            default: break
            }
        }
        .frame(minWidth: 760, minHeight: 420).font(.custom("Verdana", size: 12))
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            if (notification.object as? NSWindow)?.title == "Animation gallery" { playback.stop() }
        }
        .onAppear { playback.select(clip) }
        .onDisappear { playback.stop() }
        .onChange(of: selected) { _, _ in playback.select(showFrames ? nil : clip) }
        .onChange(of: showFrames) { _, value in
            playback.stop(); selected = value ? model.library.frames[0].id : "love"
        }
    }
    private func preview(_ frame: PixelFrame, colored: Bool) -> some View {
        VStack {
            Image(nsImage: PixelRenderer.shared.image(frame, colored: colored))
                .interpolation(.none).resizable().frame(width: 216, height: 180)
                .padding(8).background(Color(nsColor: .windowBackgroundColor))
            Text(colored ? "Color" : "Original").foregroundStyle(.secondary)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
