import Foundation
import WatchCore

extension CompanionModel {
    var activityChoices: [WatchActivity] { WatchActivity.catalog }

    func selectActivity(_ id: String?) {
        var next = state
        next.settings.selectedActivity = id
        GameEngine.interact(activity: id ?? "idle", now: .now, state: &next)
        DailyRoutine.apply(at: .now, state: &next)
        if commit(next) { animationToken = UUID() }
    }

    func cycleActivity() {
        let choices = activityChoices
        guard let index = choices.firstIndex(where: { $0.id == state.settings.selectedActivity }) else {
            selectActivity(choices.first?.id)
            return
        }
        selectActivity(index + 1 < choices.count ? choices[index + 1].id : nil)
    }

    func setFriendship(_ mood: PetMood) {
        var next = state
        switch mood {
        case .away: next.friendshipPoints = -1501
        case .mad: next.friendshipPoints = -501
        case .neutral: next.friendshipPoints = 0
        case .like: next.friendshipPoints = 1501
        case .love: next.friendshipPoints = 3001
        }
        if next.settings.selectedActivity == nil {
            next.currentActivity = "idle"
            next.currentAnimation = next.mood.animation
            DailyRoutine.apply(at: .now, state: &next)
        }
        if commit(next) { animationToken = UUID() }
    }

    func tick(at date: Date) {
        var next = state
        // Temporary greetings and gifts finish once, then return to the selected
        // activity or current schedule. No background animation timer is needed.
        if let library = AnimationLibrary.bundled {
            let clip = library.clip(for: next.currentAnimation)
            let scheduled = next.settings.routineMode == .scheduled
                ? DailyRoutine.activity(in: next.settings.dailySchedule, at: date) : nil
            if !clip.loop, next.currentAnimation != (next.settings.selectedActivity ?? scheduled),
               date.timeIntervalSince(next.lastInteractionDate) >= clip.duration {
                next.currentActivity = next.settings.selectedActivity ?? "idle"
                next.currentAnimation = next.settings.selectedActivity ?? next.mood.animation
            }
        }
        DailyRoutine.apply(at: date, state: &next)
        if next.currentAnimation != state.currentAnimation || next.currentActivity != state.currentActivity {
            next.lastStateUpdateDate = date
            if commit(next) { animationToken = UUID() }
        }
    }
}
