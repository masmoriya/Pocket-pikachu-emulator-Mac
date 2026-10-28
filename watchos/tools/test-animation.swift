import Foundation

@main
struct AnimationRegressionTests {
    static func main() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let library = try AnimationLibrary.decode(data)
        var assertions = 0
        func expect(_ condition: Bool, _ message: String) {
            precondition(condition, message)
            assertions += 1
        }
        func index(_ frameID: String) -> Int { library.frames[frameID]!.index }
        func sample(_ id: String, _ time: TimeInterval, idle: String = "idle") -> AnimationEngine.Sample {
            AnimationEngine(library: library, animationID: id, idleAnimationID: idle).sample(elapsed: time)
        }

        expect(library.frames.count == 623, "All original frames and blank are retained")
        expect(library.clips.count == 65, "All original clips are retained")
        expect(library.frames["blank"]?.index == 622, "Blank stays at its atlas index")
        for frame in library.frames.values {
            expect((0..<623).contains(frame.index), "Frame outside source atlas")
            expect(frame.index % library.columns * library.width + library.width <= 576,
                   "Crop exceeds atlas width")
            expect(frame.index / library.columns * library.height + library.height <= 1170,
                   "Crop exceeds atlas height")
        }
        for clip in library.clips.values {
            var time: TimeInterval = 0
            for step in clip.steps {
                expect(step.duration.isFinite && step.duration > 0, "Invalid duration")
                let frame = sample(clip.id, time + step.duration / 2)
                expect(frame.frameIndex == index(step.frame), "Sequence order changed: \(clip.id)")
                expect(frame.remainingDuration.isFinite && frame.remainingDuration > 0,
                       "Invalid next-frame delay")
                time += step.duration
            }
        }

        let walk = library.clip(for: "walk")
        expect(sample("walk", 0).frameIndex == index(walk.steps[0].frame), "Walking first frame")
        expect(sample("walk", walk.steps[0].duration).frameIndex == index(walk.steps[1].frame),
               "Exact frame boundary advances")
        expect(sample("walk", walk.duration).frameIndex == index(walk.steps[0].frame),
               "Loop wraps at its duration")

        let intro = library.clip(for: "love")
        expect(intro.loopStart == 1, "Fixture has an intro-only frame")
        expect(sample("love", intro.duration + 0.001).frameIndex == index(intro.steps[1].frame),
               "Loop skips intro after first pass")
        let loopDuration = intro.steps.dropFirst(intro.loopStart).reduce(0) { $0 + $1.duration }
        expect(sample("love", intro.duration + loopDuration + 0.001).frameIndex == index(intro.steps[1].frame),
               "Repeated loop skips intro")

        let greeting = library.clip(for: "greeting")
        expect(!sample("greeting", greeting.duration - 0.001).returnedToIdle, "Greeting must finish")
        expect(sample("greeting", greeting.duration).returnedToIdle, "Finite clip reports completion")
        expect(sample("greeting", greeting.duration).frameIndex == sample("idle", 0).frameIndex,
               "Finite clip returns to default idle")
        for mood in ["neutral", "mad", "left", "love"] {
            expect(sample("greeting", greeting.duration + 0.25, idle: mood).frameIndex
                   == sample(mood, 0.25).frameIndex, "Finite clip restores mood \(mood)")
        }
        expect(sample("does-not-exist", 0).frameIndex == sample("idle", 0).frameIndex,
               "Unknown clip falls back safely")
        expect(sample("happy", 0).frameIndex == index(library.clip(for: "happy").steps[0].frame),
               "Interrupting with happy resets playback")
        expect(sample("greeting", 0).frameIndex == index(greeting.steps[0].frame),
               "Replaying greeting starts from its first frame")
        expect(sample("walk", -10).frameIndex == sample("walk", 0).frameIndex,
               "Negative time clamps to zero")
        expect(sample("walk", .infinity).frameIndex == sample("walk", 0).frameIndex,
               "Nonfinite time clamps to zero")

        let repeating = AnimationEngine(library: library, animationID: "greeting", repeatFinite: true)
        expect(repeating.sample(elapsed: greeting.duration * 2).frameIndex == sample("greeting", 0).frameIndex,
               "Explicit finite activity repeats from first frame")
        expect(!repeating.sample(elapsed: greeting.duration * 2).returnedToIdle,
               "Explicit selection remains selected")
        let selected = library.clip(for: "hearts")
        expect(sample("greeting", greeting.duration + selected.duration * 2, idle: "hearts").frameIndex
               == sample("hearts", 0).frameIndex, "Greeting restores repeating finite selection")

        let ambient = AnimationEngine(library: library, animationID: "walk")
        let minute = Date(timeIntervalSince1970: 60 * 100)
        expect(ambient.ambientSample(at: minute).frameIndex == ambient.ambientSample(at: minute.addingTimeInterval(59)).frameIndex,
               "Ambient pose stays fixed within system minute")
        expect(ambient.ambientSample(at: minute.addingTimeInterval(60)).remainingDuration == 60,
               "Ambient pose only requests minute cadence")
        let ambientGreeting = AnimationEngine(library: library, animationID: "greeting", idleAnimationID: "neutral")
        expect(ambientGreeting.ambientSample(at: minute).returnedToIdle,
               "Ambient transient uses resting activity rather than a frozen reaction")

        for activity in ["kite", "history", "maths", "english", "left"] {
            let clip = library.clip(for: activity)
            let player = AnimationEngine(library: library, animationID: activity)
            let allowed = Set(clip.steps.dropFirst(clip.loopStart).filter { $0.frame != "blank" }.map { index($0.frame) })
            for value in 0..<(clip.steps.count * 2) {
                expect(allowed.contains(player.ambientSample(at: Date(timeIntervalSince1970: Double(value * 60))).frameIndex),
                       "Ambient \(activity) stays visible and skips intro")
            }
        }

        var malformed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var clips = malformed["clips"] as! [[String: Any]]
        var steps = clips[0]["steps"] as! [[String: Any]]
        steps[0]["duration"] = 0
        clips[0]["steps"] = steps
        malformed["clips"] = clips
        do {
            _ = try AnimationLibrary.decode(JSONSerialization.data(withJSONObject: malformed))
            preconditionFailure("Zero-duration manifest must be rejected")
        } catch { assertions += 1 }
        print("Animation regressions passed: \(assertions) assertions; \(library.clips.count) real clips")
    }
}
