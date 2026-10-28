import SwiftUI
import WatchCore

struct ClockView: View {
    @ObservedObject var model: CompanionModel
    @Binding var path: NavigationPath
    @Environment(\.isLuminanceReduced) private var dimmed
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reducedMotion

    var body: some View {
        VStack(spacing: 2) {
            DigitalClockView(format: model.state.settings.clockFormat)
            Button { model.greet() } label: {
                PikachuSpriteView(animationID: model.state.currentAnimation,
                    colored: model.state.settings.colored,
                    isActive: phase == .active && !dimmed,
                    reducedMotion: reducedMotion || model.state.settings.reducedAnimation,
                    idleAnimationID: model.state.mood.animation)
                    .id(model.animationToken)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Pikachu, \(model.state.mood.label)")
            .accessibilityHint("Tap to greet")
            .disabled(dimmed)
            if !dimmed {
                TimelineView(.everyMinute) { context in
                let displayedSteps = model.displayedSteps(at: context.date)
                HStack(spacing: 12) {
                    if model.state.settings.showSteps {
                        Label(displayedSteps.map { $0.formatted() } ?? "—", systemImage: "figure.walk")
                            .accessibilityLabel(displayedSteps.map { "\($0) steps today" } ?? "Steps unavailable")
                    }
                    if model.state.settings.showWatts {
                        Label(model.state.wattsBalance.formatted(), systemImage: "bolt.fill")
                            .accessibilityLabel("\(model.state.wattsBalance) watts")
                    }
                }.font(.caption2).foregroundStyle(.secondary).privacySensitive()
                }
                NavigationLink { MenuView(model: model, returnToClock: { path = NavigationPath() }) } label: {
                    Image(systemName: "ellipsis").frame(maxWidth: .infinity, minHeight: 28)
                }
                .buttonStyle(.plain).accessibilityLabel("Activities and settings")
            }
        }
        .padding(.horizontal, 6)
        .background(.black)
        .opacity(dimmed ? 0.6 : 1)
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct DigitalClockView: View {
    var format: GameSettings.ClockFormat
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone

    var body: some View {
        TimelineView(.everyMinute) { context in
            Text(timeString(context.date))
                .font(.system(size: 34, weight: .medium)).monospacedDigit()
                .minimumScaleFactor(0.6).lineLimit(1)
                .accessibilityLabel(timeString(context.date))
        }
    }

    private func timeString(_ date: Date) -> String {
        ClockFormatting.string(date: date, format: format, locale: locale, timeZone: timeZone)
    }
}
