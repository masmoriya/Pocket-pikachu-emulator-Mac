import Foundation

/// Pure elapsed-time playback: no timer, publisher, or background task.
struct AnimationEngine: Sendable {
    struct Sample: Sendable {
        let frameIndex: Int
        let remainingDuration: TimeInterval
        let returnedToIdle: Bool
    }

    let library: AnimationLibrary
    let animationID: String
    let idleAnimationID: String

    init(library: AnimationLibrary, animationID: String, idleAnimationID: String = "idle") {
        self.library = library
        self.animationID = animationID
        self.idleAnimationID = idleAnimationID
    }

    func sample(elapsed: TimeInterval) -> Sample {
        let clip = library.clip(for: animationID)
        let time = elapsed.isFinite ? max(0, elapsed) : 0
        if !clip.loop, time >= clip.duration {
            return sample(clip: library.clip(for: idleAnimationID), time: time - clip.duration, returned: true)
        }
        return sample(clip: clip, time: time, returned: false)
    }

    private func sample(clip: AnimationClip, time: TimeInterval, returned: Bool) -> Sample {
        var position = time
        var start = 0
        if clip.loop, position >= clip.duration {
            let prefix = clip.steps.prefix(clip.loopStart).reduce(0) { $0 + $1.duration }
            let loopDuration = clip.duration - prefix
            position = (position - prefix).truncatingRemainder(dividingBy: loopDuration)
            start = clip.loopStart
        }
        for step in clip.steps.dropFirst(start) {
            if position < step.duration {
                return Sample(
                    frameIndex: library.frames[step.frame]?.index ?? 0,
                    remainingDuration: max(0.001, step.duration - position),
                    returnedToIdle: returned
                )
            }
            position -= step.duration
        }
        // Floating-point rounding at a cycle boundary starts the next valid frame.
        let step = clip.steps[clip.loop ? clip.loopStart : clip.steps.count - 1]
        return Sample(frameIndex: library.frames[step.frame]?.index ?? 0,
                      remainingDuration: step.duration, returnedToIdle: returned)
    }
}
