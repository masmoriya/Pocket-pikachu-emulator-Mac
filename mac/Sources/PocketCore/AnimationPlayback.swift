import Foundation

public struct AnimationActivityChoice: Identifiable, Sendable {
    public var id: String
    public var label: String
    public init(id: String, label: String) { self.id = id; self.label = label }
}

/// Maps individual gallery clips to logical activities and samples their connected playback.
public struct AnimationActivityPlayer: Sendable {
    private let sequences: [String: AnimationSequence]
    private let aliases: [String: String]
    private var exitClipIDs: [String] = []

    public init(sequences: [AnimationSequence]) {
        self.sequences = Dictionary(uniqueKeysWithValues: sequences.map { ($0.id, $0) })
        aliases = Dictionary(uniqueKeysWithValues: sequences.flatMap { sequence in
            sequence.componentIDs.filter { $0 != sequence.id }.map { ($0, sequence.id) }
        })
    }

    public func canonicalActivity(_ id: String) -> String {
        if sequences[id] != nil { return id }
        return aliases[id] ?? id
    }

    public func label(for id: String, clips: [String: AnimationClip]) -> String {
        sequences[id]?.label ?? clips[id]?.label ?? id
    }

    public func choices(in clipOrder: [AnimationClip]) -> [AnimationActivityChoice] {
        var seen = Set<String>()
        return clipOrder.compactMap { clip in
            let id = canonicalActivity(clip.id)
            guard seen.insert(id).inserted else { return nil }
            return AnimationActivityChoice(id: id, label: sequences[id]?.label ?? clip.label)
        }
    }

    public mutating func switchActivity(to id: String, from currentID: String, elapsed: TimeInterval,
                                        clips: [String: AnimationClip]) -> String {
        let next = canonicalActivity(id)
        let activeExitDuration = AnimationTimeline.duration(of: exitClipIDs, clips: clips)
        let exitIsPlaying = !exitClipIDs.isEmpty && elapsed < activeExitDuration
        if next == currentID || exitIsPlaying { exitClipIDs = [] }
        else { exitClipIDs = sequences[currentID]?.exit ?? [] }
        return next
    }

    public func sample(activityID: String, elapsed: TimeInterval, clips: [String: AnimationClip],
                       repeatFinite: Bool) -> AnimationSample {
        let exitDuration = AnimationTimeline.duration(of: exitClipIDs, clips: clips)
        if elapsed < exitDuration,
           let sample = AnimationTimeline.sample(exitClipIDs, at: elapsed, clips: clips) {
            return sample
        }
        let activityElapsed = max(0, elapsed - exitDuration)
        if let sequence = sequences[activityID] { return sequence.sample(at: activityElapsed, clips: clips) }
        guard let clip = clips[activityID] else { return .blank }
        let sample = clip.sample(at: activityElapsed, repeatFinite: repeatFinite)
        return AnimationSample(frame: sample.frame, remaining: sample.remaining)
    }
}
