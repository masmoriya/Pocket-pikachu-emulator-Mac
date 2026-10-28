import SwiftUI

struct PikachuSpriteView: View {
    let animationID: String
    var colored = true
    var isActive = true
    var reducedMotion = false
    var idleAnimationID = "idle"

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var elapsed: TimeInterval = 0
    @State private var resumedAt = Date()
    @State private var running = false

    private var shouldPlay: Bool {
        isActive && scenePhase == .active && !isLuminanceReduced
            && !reducedMotion && !accessibilityReduceMotion
    }

    var body: some View {
        Group {
            if let library = AnimationLibrary.bundled {
                let engine = AnimationEngine(
                    library: library, animationID: animationID, idleAnimationID: idleAnimationID
                )
                if shouldPlay {
                    TimelineView(FrameSchedule(engine: engine, resumedAt: resumedAt, elapsed: elapsed)) { context in
                        sprite(engine.sample(elapsed: playbackTime(at: context.date)), library: library)
                    }
                } else {
                    // No timeline exists while ambient, inactive, or reducing motion.
                    sprite(engine.sample(elapsed: elapsed), library: library)
                }
            } else {
                Text("Sprite unavailable").font(.caption)
            }
        }
        .aspectRatio(36.0 / 30.0, contentMode: .fit)
        .accessibilityLabel("Pikachu")
        .onChange(of: shouldPlay, initial: true) { _, active in
            let now = Date()
            if running { elapsed += max(0, now.timeIntervalSince(resumedAt)) }
            resumedAt = now
            running = active
        }
        .onChange(of: animationID) { _, _ in
            elapsed = 0
            resumedAt = Date()
        }
    }

    private func playbackTime(at date: Date) -> TimeInterval {
        elapsed + (running ? max(0, date.timeIntervalSince(resumedAt)) : 0)
    }

    @ViewBuilder
    private func sprite(_ sample: AnimationEngine.Sample, library: AnimationLibrary) -> some View {
        if let image = SpriteAtlasLoader.shared.image(
            index: sample.frameIndex, colored: colored, library: library
        ) {
            Image(decorative: image, scale: 1)
                .renderingMode(colored ? .original : .template)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .foregroundStyle(.white)
        } else {
            Text("Sprite unavailable").font(.caption)
        }
    }
}

/// Schedule exactly at source frame boundaries, including long holds and intro loops.
private struct FrameSchedule: TimelineSchedule {
    let engine: AnimationEngine
    let resumedAt: Date
    let elapsed: TimeInterval

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnySequence<Date> {
        AnySequence {
            var nextDate = startDate
            return AnyIterator<Date> {
                let date = nextDate
                let time = elapsed + max(0, date.timeIntervalSince(resumedAt))
                nextDate = date.addingTimeInterval(engine.sample(elapsed: time).remainingDuration)
                return date
            }
        }
    }
}
