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
    var repeatFinite = false

    init(library: AnimationLibrary, animationID: String, idleAnimationID: String = "idle", repeatFinite: Bool = false) {
        self.library = library
        self.animationID = animationID
        self.idleAnimationID = idleAnimationID
        self.repeatFinite = repeatFinite
    }

    func sample(elapsed: TimeInterval) -> Sample {
        let clip = library.clip(for: animationID)
        let time = elapsed.isFinite ? max(0, elapsed) : 0
        if !clip.loop, repeatFinite {
            return sample(clip: clip, time: time.truncatingRemainder(dividingBy: clip.duration), returned: false)
        }
        if !clip.loop, time >= clip.duration {
            let idle = library.clip(for: idleAnimationID)
            let elapsed = time - clip.duration
            return sample(clip: idle, time: idle.loop ? elapsed : elapsed.truncatingRemainder(dividingBy: idle.duration), returned: true)
        }
        return sample(clip: clip, time: time, returned: false)
    }

    /// A single pose per system minute; never a background animation loop.
    func ambientSample(at date: Date) -> Sample {
        let current = library.clip(for: animationID)
        let clip = !current.loop && !repeatFinite ? library.clip(for: idleAnimationID) : current
        // Avoid minute-long blank frames and replaying a looping activity's intro.
        let repeating = clip.loop ? Array(clip.steps.dropFirst(clip.loopStart)) : clip.steps
        let visible = repeating.filter { $0.frame != "blank" }
        let poses = visible.isEmpty ? library.clip(for: "neutral").steps : visible
        let minute = Int(date.timeIntervalSince1970 / 60)
        let index = ((minute % poses.count) + poses.count) % poses.count
        return Sample(frameIndex: library.frames[poses[index].frame]?.index ?? 0,
                      remainingDuration: 60, returnedToIdle: clip.id != current.id)
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
