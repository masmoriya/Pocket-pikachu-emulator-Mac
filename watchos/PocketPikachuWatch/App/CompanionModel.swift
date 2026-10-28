import SwiftUI
import WatchCore
import WatchKit
import WidgetKit

@MainActor final class CompanionModel: ObservableObject {
    @Published private(set) var state = PetState(now: .now)
    @Published private(set) var isLoaded = false
    @Published var errorMessage: String?
    @Published private(set) var todaySteps: Int?
    @Published var animationToken = UUID()
    let steps = StepManager()
    private let store: PersistentPetStore
    private var lastSnapshot: PetSnapshot?
    private var isSyncing = false
    private var stepDisplayDate: Date?
    private var stepDisplayTimeZone = TimeZone.current.identifier

    func displayedSteps(at date: Date) -> Int? {
        guard let stepDisplayDate, Calendar.current.isDate(stepDisplayDate, inSameDayAs: date) else { return nil }
        if stepDisplayTimeZone != TimeZone.current.identifier,
           let snapshot = steps.latestSnapshot {
            return Int(GameEngine.todaySteps(samples: snapshot.samples, on: min(date, snapshot.through)))
        }
        return todaySteps
    }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        store = PersistentPetStore(directory: base.appendingPathComponent("PocketPikachu", isDirectory: true))
        load()
    }

    func load() {
        do {
            var loaded: PetState
            if let saved = try store.load() { loaded = saved }
            else {
                loaded = PetState(now: .now)
                // Initial preferences mirror the saved Mac companion. Existing
                // watch progress and preferences always take precedence.
                loaded.friendshipPoints = 3001
                loaded.currentAnimation = loaded.mood.animation
                loaded.settings.spriteSize = 100
            }
            restoreExpiredReaction(in: &loaded)
            DailyRoutine.apply(at: .now, state: &loaded)
            try store.save(loaded)
            state = loaded
            isLoaded = true
            errorMessage = nil
            publishSnapshot()
        } catch {
            isLoaded = false
            errorMessage = "Save unavailable. Your files are preserved. Retry loading after freeing storage or restoring a backup."
        }
    }

    @discardableResult func commit(_ next: PetState) -> Bool {
        guard isLoaded else { return false }
        do {
            try store.save(next)
            state = next
            publishSnapshot()
            return true
        } catch {
            errorMessage = "Could not save. Progress has not changed. Try again."
            return false
        }
    }

    func updateSettings(_ settings: GameSettings) {
        var next = state
        next.settings = settings
        if settings.routineMode != state.settings.routineMode,
           settings.routineMode == .free, settings.selectedActivity == nil {
            next.currentActivity = "idle"
            next.currentAnimation = next.mood.animation
        }
        next.lastStateUpdateDate = .now
        DailyRoutine.apply(at: .now, state: &next)
        let changed = next.currentAnimation != state.currentAnimation
        if commit(next), changed { animationToken = UUID() }
    }

    func interact(_ activity: String) {
        var next = state
        GameEngine.interact(activity: activity, now: .now, state: &next)
        if commit(next) { animationToken = UUID() }
    }

    func greet() {
        if state.settings.cycleActivitiesOnTap { cycleActivity() }
        else { interact(state.mood == .love ? "loveHello" : "look") }
    }

    @discardableResult func gift(_ amount: Int64, requestID: String) -> Bool {
        var next = state
        do {
            try GameEngine.giveGift(amount: amount, requestID: requestID,
                                    roll: Int.random(in: 1...10), now: .now, state: &next)
            let moodChanged = next.mood != state.mood
            guard commit(next) else { return false }
            animationToken = UUID()
            haptic(moodChanged ? .success : .click)
            return true
        } catch GameError.insufficientWatts {
            errorMessage = "Not enough watts."
        } catch GameError.giftDebounced {
            return false
        } catch GameError.duplicateRequest {
            return false
        } catch { errorMessage = "Gift could not be given." }
        haptic(.failure)
        return false
    }

    func synchronize(authorize: Bool = false) async {
        guard isLoaded, !isSyncing else { return }
        isSyncing = true
        var resumed = state
        restoreExpiredReaction(in: &resumed)
        DailyRoutine.apply(at: .now, state: &resumed)
        if resumed.currentAnimation != state.currentAnimation { commit(resumed) }
        defer { isSyncing = false }
        if authorize { await steps.requestAuthorization() }
        else { await steps.refresh() }
        guard let snapshot = steps.latestSnapshot else { todaySteps = nil; return }
        // HealthKit cannot distinguish revoked read access from an empty store.
        // Keep credit ledger intact when no accessible samples exist.
        guard !snapshot.samples.isEmpty else { todaySteps = nil; return }
        var next = state
        do {
            try GameEngine.reconcile(samples: snapshot.samples, windowStart: snapshot.windowStart,
                                     through: snapshot.through, cursor: snapshot.cursor, state: &next)
            let total = GameEngine.eligibleStepCount(samples: snapshot.samples,
                start: Calendar.current.startOfDay(for: snapshot.through), end: snapshot.through)
            let previousSteps = todaySteps
            let previousDate = stepDisplayDate
            todaySteps = Int(total.rounded(.down))
            stepDisplayDate = snapshot.through
            stepDisplayTimeZone = TimeZone.current.identifier
            let milestone = next.lifetimeStepsCredited / 1000 > state.lifetimeStepsCredited / 1000
            if commit(next) { if milestone { haptic(.success) } }
            else { todaySteps = previousSteps; stepDisplayDate = previousDate }
        } catch { errorMessage = "Step sync could not finish. Saved rewards are unchanged." }
    }

    private func restoreExpiredReaction(in pet: inout PetState) {
        guard let library = AnimationLibrary.bundled else { return }
        let scheduled = pet.settings.routineMode == .scheduled
            ? DailyRoutine.activity(in: pet.settings.dailySchedule, at: .now) : nil
        guard pet.currentAnimation != (pet.settings.selectedActivity ?? scheduled) else { return }
        let clip = library.clip(for: pet.currentAnimation)
        if !clip.loop, Date.now.timeIntervalSince(pet.lastInteractionDate) >= clip.duration {
            pet.currentActivity = pet.settings.selectedActivity ?? "idle"
            pet.currentAnimation = pet.settings.selectedActivity ?? pet.mood.animation
            pet.lastStateUpdateDate = .now
        }
    }

    // Every mutation already commits before publication; no dirty state at suspension.
    func save() { if isLoaded { publishSnapshot() } }

    private func haptic(_ type: WKHapticType) {
        if state.settings.hapticsEnabled { WKInterfaceDevice.current().play(type) }
    }

    private func publishSnapshot() {
        let frame: String
        switch state.mood {
        case .away: frame = "standLeft"
        case .mad: frame = "standMad.stand"
        default: frame = "standBasic.stand"
        }
        let snapshot = PetSnapshot(date: .now, steps: displayedSteps(at: .now),
                                   watts: state.wattsBalance, mood: state.mood.label, frameID: frame)
        guard lastSnapshot?.steps != snapshot.steps || lastSnapshot?.watts != snapshot.watts
            || lastSnapshot?.mood != snapshot.mood
            || lastSnapshot.map({ !Calendar.current.isDate($0.date, inSameDayAs: snapshot.date) }) ?? true
            else { return }
        do {
            try SharedSnapshotStore.write(snapshot)
            lastSnapshot = snapshot
            WidgetCenter.shared.reloadTimelines(ofKind: "PocketPikachuPet")
        } catch {
            // App-owned saves remain valid even when App Group provisioning is unavailable.
        }
    }
}
