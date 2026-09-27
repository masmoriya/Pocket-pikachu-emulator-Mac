import Foundation

public struct PixelFrame: Codable, Identifiable, Sendable {
    public var id: String
    public var category: String
    public var pixels: [Int]
    public var sourcePixels: [Int]
}
public struct AnimationStep: Codable, Sendable {
    public var frame: String
    public var duration: Double
}
public struct AnimationClip: Codable, Identifiable, Sendable {
    public var id: String
    public var label: String
    public var source: String
    public var loop: Bool
    public var loopStart: Int
    public var steps: [AnimationStep]
    public var props: [String]

    public var duration: Double { steps.reduce(0) { $0 + $1.duration } }
    public func frame(at elapsed: Double, repeatFinite: Bool = false) -> String {
        sample(at: elapsed, repeatFinite: repeatFinite).frame
    }
    public func sample(at elapsed: Double, repeatFinite: Bool = false) -> (frame: String, remaining: Double) {
        guard !steps.isEmpty else { return ("blank", 1) }
        var time = max(0, elapsed)
        if time >= duration {
            if loop {
                let intro = steps.prefix(loopStart).reduce(0) { $0 + $1.duration }
                time = intro + (time - intro).truncatingRemainder(dividingBy: max(0.001, duration - intro))
            } else if repeatFinite {
                time.formTruncatingRemainder(dividingBy: max(0.001, duration))
            } else { return (steps.last!.frame, 60) }
        }
        for step in steps {
            if time < step.duration { return (step.frame, step.duration - time) }
            time -= step.duration
        }
        return (steps.last!.frame, 1)
    }
}
public struct AnimationSequence: Codable, Identifiable, Sendable {
    public var id: String
    public var label: String
    public var entry: [String]
    public var loop: [String]
    public var exit: [String]

    public var componentIDs: [String] { entry + loop + exit }
    public func entryDuration(clips: [String: AnimationClip]) -> Double { AnimationTimeline.duration(of: entry, clips: clips) }
    public func loopDuration(clips: [String: AnimationClip]) -> Double { AnimationTimeline.duration(of: loop, clips: clips) }
    public func exitDuration(clips: [String: AnimationClip]) -> Double { AnimationTimeline.duration(of: exit, clips: clips) }

    public func sample(at elapsed: Double, clips: [String: AnimationClip]) -> AnimationSample {
        let time = max(0, elapsed)
        let entryDuration = entryDuration(clips: clips)
        if time < entryDuration, let sample = AnimationTimeline.sample(entry, at: time, clips: clips) {
            return sample
        }
        guard !loop.isEmpty else {
            return AnimationTimeline.sample(entry, at: time, clips: clips) ?? .blank
        }
        let loopTime = max(0, time - entryDuration).truncatingRemainder(dividingBy: max(0.001, loopDuration(clips: clips)))
        return AnimationTimeline.sample(loop, at: loopTime, clips: clips) ?? .blank
    }

    public func sampleExit(at elapsed: Double, clips: [String: AnimationClip]) -> AnimationSample? {
        guard elapsed < exitDuration(clips: clips) else { return nil }
        return AnimationTimeline.sample(exit, at: max(0, elapsed), clips: clips)
    }
}

public struct AnimationSample: Sendable, Equatable {
    public var frame: String
    public var remaining: Double
    public init(frame: String, remaining: Double) {
        self.frame = frame
        self.remaining = remaining
    }
    public static let blank = AnimationSample(frame: "blank", remaining: 1)
}

public enum AnimationTimeline {
    public static func duration(of ids: [String], clips: [String: AnimationClip]) -> Double {
        ids.reduce(0) { $0 + (clips[$1]?.duration ?? 0) }
    }

    public static func sample(_ ids: [String], at elapsed: Double, clips: [String: AnimationClip]) -> AnimationSample? {
        guard !ids.isEmpty else { return nil }
        var time = max(0, elapsed)
        for id in ids {
            guard let clip = clips[id] else { continue }
            if time < clip.duration {
                let sample = clip.sample(at: time)
                return AnimationSample(frame: sample.frame, remaining: sample.remaining)
            }
            time -= clip.duration
        }
        guard let last = ids.reversed().compactMap({ clips[$0] }).first else { return nil }
        return AnimationSample(frame: last.steps.last?.frame ?? "blank", remaining: 60)
    }
}

public struct AnimationSequenceLibrary: Codable, Sendable {
    public var version: Int
    public var sequences: [AnimationSequence]
}

public struct AnimationLibrary: Codable, Sendable {
    public var version: Int
    public var width: Int
    public var height: Int
    public var sourceFrameCount: Int
    public var frames: [PixelFrame]
    public var clips: [AnimationClip]
}
