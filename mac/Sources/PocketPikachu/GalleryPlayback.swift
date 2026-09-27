import Foundation
import Combine
import PocketCore

/// Advance only at source-frame boundaries; paused galleries have no display timer.
@MainActor final class GalleryPlayback: ObservableObject {
    @Published var index = 0
    @Published var playing = false
    private var clip: AnimationClip?
    private var timer: Timer?
    func select(_ clip: AnimationClip?) {
        let resume = playing
        stop(); self.clip = clip; index = 0
        if resume && clip != nil { toggle() }
    }
    func toggle() {
        if playing { stop() }
        else if clip != nil { playing = true; schedule() }
    }
    func step(_ delta: Int) {
        stop()
        let count = clip?.steps.count ?? 0
        guard count > 0 else { index = 0; return }
        index = (index + delta % count + count) % count
    }
    func stop() { playing = false; timer?.invalidate(); timer = nil }
    private func schedule() {
        guard playing, let clip, clip.steps.indices.contains(index) else { return }
        let timer = Timer(timeInterval: clip.steps[index].duration, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let clip = self.clip, self.playing else { return }
                self.index += 1
                if self.index >= clip.steps.count { self.index = clip.loop ? clip.loopStart : 0 }
                self.schedule()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}
