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
public struct AnimationLibrary: Codable, Sendable {
    public var version: Int
    public var width: Int
    public var height: Int
    public var sourceFrameCount: Int
    public var frames: [PixelFrame]
    public var clips: [AnimationClip]
}
