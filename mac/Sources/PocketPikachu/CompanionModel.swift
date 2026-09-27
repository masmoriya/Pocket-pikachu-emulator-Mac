import AppKit
import Combine
import PocketCore

@MainActor final class CompanionModel: ObservableObject {
    @Published var saved: SavedCompanion
    @Published var activity = "love"
    @Published var activityStarted = Date.now
    @Published var status = "Connecting to local Codex usage…"
    var hidden: Bool {
        get { pet.menuBarOnly ?? false }
        set { update { $0.menuBarOnly = newValue } }
    }
    @Published var sleepingDisplay = false
    @Published var error: String?
    let library: AnimationLibrary
    let frames: [String: PixelFrame]
    let clips: [String: AnimationClip]
    private var activityPlayer: AnimationActivityPlayer
    private let store: CompanionStore
    private lazy var scanner = UsageScanner(cursors: saved.cursors ?? [:], home: saved.pet.codexHome)
    private var timer: Timer?
    private var scanTimer: Timer?
    private var scanning = false
    private var lastScan = Date.distantPast
    private var deferredScan: Task<Void, Never>?
    private var firstScan = true
    private var savingAllowed = true
    private var reactionTask: Task<Void, Never>?
    private var returnActivity: String?
    private var pendingCelebration = false
    private var temporaryUntil: Date?
    private var nextActivity = Date.now.addingTimeInterval(90)
    private var lastAcknowledgment = Date.distantPast
    private var watcher: SessionWatcher?
    var onPlacementChange: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOpenGallery: (() -> Void)?
    var pet: PetState { saved.pet }
    var selectedActivity: String? { pet.selectedActivity.map(activityPlayer.canonicalActivity) }
    var activityLabel: String { activityPlayer.label(for: activity, clips: clips) }
    var activityChoices: [AnimationActivityChoice] { activityPlayer.choices(in: library.clips) }
    var animating: Bool { !hidden && !sleepingDisplay }

    init() throws {
        let resource = AppResources.bundle.url(forResource: "animations", withExtension: "json")!
        library = try JSONDecoder().decode(AnimationLibrary.self, from: Data(contentsOf: resource))
        let sequenceResource = AppResources.bundle.url(forResource: "sequences", withExtension: "json")!
        let sequenceLibrary = try JSONDecoder().decode(AnimationSequenceLibrary.self, from: Data(contentsOf: sequenceResource))
        frames = Dictionary(uniqueKeysWithValues: library.frames.map { ($0.id, $0) })
        clips = Dictionary(uniqueKeysWithValues: library.clips.map { ($0.id, $0) })
        activityPlayer = AnimationActivityPlayer(sequences: sequenceLibrary.sequences)
        let home = ProcessInfo.processInfo.environment["CODEX_HOME"] ?? NSHomeDirectory() + "/.codex"
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        store = CompanionStore(url: support.appendingPathComponent("PocketPikachu/state.json"))
        do { saved = try store.load(defaultHome: home) }
        catch {
            saved = SavedCompanion(pet: PetState(codexHome: home))
            savingAllowed = false
            self.error = "Saved state could not be opened. It has been preserved. Restore state.json before restarting."
        }
        activity = activityPlayer.canonicalActivity(saved.pet.selectedActivity ?? saved.pet.friendship.idle)
    }
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        scanTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.scan() }
        }
        restartWatcher()
        Task { await scan() }
    }
    func update(_ mutation: (inout PetState) -> Void) {
        mutation(&saved.pet); persist(); onPlacementChange?()
    }
    func persist() {
        guard savingAllowed else { return }
        do { try store.save(saved) } catch { self.error = "Could not save companion state: \(error.localizedDescription)" }
    }
    func interact() { saved.pet.lastInteraction = .now; persist() }
    func resumeAnimation() { sleepingDisplay = false }
    func select(_ id: String?) {
        let selected = id.map(activityPlayer.canonicalActivity)
        saved.pet.selectedActivity = selected
        reactionTask?.cancel(); temporaryUntil = nil; returnActivity = nil; interact()
        switchActivity(selected ?? saved.pet.friendship.idle)
    }
    func cycleActivity(_ offset: Int = 1) {
        let activities = activityChoices
        guard !activities.isEmpty else { return }
        guard let current = activities.firstIndex(where: { $0.id == activityPlayer.canonicalActivity(activity) }) else {
            select(offset < 0 ? activities[activities.count - 1].id : activities[0].id)
            return
        }
        let next = current + (offset < 0 ? -1 : 1)
        if next < 0 || next >= activities.count { select(nil) }
        else { select(activities[next].id) }
    }
    func friendship(_ value: Friendship) {
        saved.pet.friendship = value; interact()
        if saved.pet.selectedActivity == nil && temporaryUntil == nil { switchActivity(value.idle) }
    }
    func react(_ id: String, seconds: Double? = nil) {
        if temporaryUntil == nil { returnActivity = activity }
        interact()
        temporaryUntil = .now.addingTimeInterval(seconds ?? clips[id]?.duration ?? 8)
        switchActivity(id)
        reactionTask?.cancel()
        let delay = max(0.1, seconds ?? clips[id]?.duration ?? 8)
        reactionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.tick()
        }
    }
    func give(_ amount: Int64) {
        guard saved.pet.progression.spend(amount) else { return }
        react(PetBehavior.gift(amount: amount, friendship: pet.friendship, roll: Int.random(in: 1...10)))
    }
    func chooseHome(_ path: String) {
        guard path != pet.codexHome else { return }
        saved.pet.codexHome = path
        saved.cursors = [:]
        saved.ledger = UsageLedger() // A different home starts a new baseline, retaining earned progress.
        firstScan = true
        persist(); restartWatcher()
        Task { await scan() }
    }
    private func restartWatcher() {
        watcher = SessionWatcher(path: pet.codexHome) { [weak self] in
            Task { @MainActor in await self?.scan() }
        }
    }
    func scan() async {
        guard !scanning, savingAllowed else { return }
        if Date.now.timeIntervalSince(lastScan) < 5 {
            if deferredScan == nil {
                deferredScan = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(5))
                    self?.deferredScan = nil
                    await self?.scan()
                }
            }
            return
        }
        lastScan = .now
        scanning = true
        defer { scanning = false }
        let home = pet.codexHome
        if saved.ledger.startedAt == nil {
            _ = saved.ledger.reconcile([], now: .now)
            persist()
        }
        let result = await scanner.scan(home: home, since: saved.ledger.startedAt!, knownSessions: Set(saved.ledger.sessions.keys), requiredParents: Set(saved.ledger.sessions.values.compactMap(\.parent)))
        guard home == pet.codexHome else { return }
        var candidate = saved
        let awarded = candidate.ledger.reconcile(result.sessions, now: .now)
        candidate.pet.progression.award(awarded)
        let milestone = PetBehavior.crossedMilestone(from: saved.pet.progression.steps, to: candidate.pet.progression.steps)
        candidate.cursors = result.cursors
        do { try store.save(candidate) }
        catch { self.error = "Usage paused: cannot save its accounting checkpoint."; await scanner.invalidate(); return }
        saved = candidate
        status = result.errors.first ?? (result.fileCount == 0 ? "Waiting for your first Codex session" : "Connected · local token counts")
        let live = !firstScan && awarded > 0 && (result.latest.map { Date.now.timeIntervalSince($0) < 60 } ?? false)
        firstScan = false
        if live {
            if milestone != nil { pendingCelebration = true }
            saved.pet.lastInteraction = .now
            if pet.selectedActivity == nil && temporaryUntil == nil {
                if activity.hasPrefix("sleep") { react("loveHello") }
                else if activity == pet.friendship.idle && Date.now.timeIntervalSince(lastAcknowledgment) > 120 {
                    lastAcknowledgment = .now; react("loveHello")
                }
            }
            persist()
        }
    }
    private func tick() {
        guard !sleepingDisplay else { return }
        if let until = temporaryUntil {
            if Date.now < until { return }
            temporaryUntil = nil
            let resume = returnActivity ?? pet.friendship.idle
            if activity == "toast" { react("brush", seconds: 8); returnActivity = resume; return }
            returnActivity = nil
            switchActivity(pet.selectedActivity ?? resume)
        }
        guard pet.selectedActivity == nil else { return }
        if let resting = PetBehavior.restingActivity(state: pet, now: .now) {
            if activity != activityPlayer.canonicalActivity(resting) { switchActivity(resting) }
            return
        }
        if Date.now >= nextActivity {
            if pendingCelebration { pendingCelebration = false; nextActivity = .now.addingTimeInterval(30); react("happy"); return }
            if ["toast", "rice", "onigiri", "bath", "shower"].contains(activity) {
                switchActivity("brush"); nextActivity = .now.addingTimeInterval(8); return
            }
            let options = [pet.friendship.idle, "reading", "computer", "yoyo", "sand", "blocks", "kite", "study", "bath", "rice", "onigiri", "toast", "rc"]
            switchActivity(options.randomElement()!)
            nextActivity = .now.addingTimeInterval(Double.random(in: 45...120))
        }
    }
    func sample(at date: Date = .now) -> AnimationSample {
        let elapsed = max(0, date.timeIntervalSince(activityStarted))
        return activityPlayer.sample(activityID: activity, elapsed: elapsed, clips: clips,
                                     repeatFinite: pet.selectedActivity != nil)
    }

    private func switchActivity(_ id: String) {
        let now = Date.now
        activity = activityPlayer.switchActivity(to: id, from: activity,
            elapsed: now.timeIntervalSince(activityStarted), clips: clips)
        activityStarted = now
    }
}
