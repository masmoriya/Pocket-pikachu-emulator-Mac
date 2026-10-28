import SwiftUI
import WatchCore

struct ClockView: View {
    @ObservedObject var model: CompanionModel
    @Binding var showingMenu: Bool
    @Environment(\.isLuminanceReduced) private var dimmed
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reducedMotion

    private var scheduledActivity: String? {
        guard model.state.settings.routineMode == .scheduled else { return nil }
        return DailyRoutine.activity(in: model.state.settings.dailySchedule, at: .now)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                Button { model.greet() } label: {
                    PikachuSpriteView(animationID: model.state.currentAnimation,
                        colored: model.state.settings.colored,
                        isActive: phase == .active && !dimmed,
                        reducedMotion: reducedMotion || model.state.settings.reducedAnimation,
                        idleAnimationID: model.state.settings.selectedActivity ?? scheduledActivity ?? model.state.mood.animation,
                        repeatFinite: model.state.currentAnimation == model.state.settings.selectedActivity
                            || (model.state.settings.selectedActivity == nil
                                && model.state.currentAnimation == scheduledActivity))
                        .id(model.animationToken)
                        .frame(width: geometry.size.width * CGFloat(model.state.settings.spriteSize) / 100)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pikachu, \(model.state.mood.label)")
                .accessibilityHint(model.state.settings.cycleActivitiesOnTap ? "Tap to change activity" : "Tap to greet")
                .disabled(dimmed)
                VStack(spacing: 0) {
                    if model.state.settings.showClock {
                        DigitalClockView(format: model.state.settings.clockFormat)
                            .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                    if !dimmed { controls }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .background(.black)
        .opacity(dimmed ? 0.6 : 1)
    }

    private var controls: some View {
        TimelineView(.everyMinute) { context in
            HStack(alignment: .bottom, spacing: 4) {
                if model.state.settings.showSteps {
                    DailyStepRing(steps: model.displayedSteps(at: context.date), goal: model.state.settings.dailyStepGoal)
                }
                Spacer(minLength: 0)
                if model.state.settings.showWatts {
                    Label(model.state.wattsBalance.formatted(), systemImage: "bolt.fill")
                        .font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                        .padding(.bottom, 14)
                        .accessibilityLabel("\(model.state.wattsBalance) watts")
                }
                Spacer(minLength: 0)
                Button { showingMenu = true } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 19, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Activities and settings")
            }
            .padding(.horizontal, 4)
            .privacySensitive()
            .onChange(of: context.date, initial: true) { _, date in
                if phase == .active { model.tick(at: date) }
            }
        }
    }
}

struct DigitalClockView: View {
    var format: GameSettings.ClockFormat
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone

    var body: some View {
        TimelineView(.everyMinute) { context in
            Text(ClockFormatting.string(date: context.date, format: format, locale: locale, timeZone: timeZone))
                .font(.system(size: 25, weight: .medium)).monospacedDigit()
                .minimumScaleFactor(0.6).lineLimit(1)
        }
    }
}
