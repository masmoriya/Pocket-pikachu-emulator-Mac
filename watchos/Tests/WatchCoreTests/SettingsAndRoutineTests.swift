import XCTest
@testable import WatchCore

final class SettingsAndRoutineTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testOriginalSchemaOneSettingsDecodeWithoutNewKeys() throws {
        var original = PetState(now: now)
        original.settings.stepsPerWatt = 20
        original.stepRemainder = 19
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        var settings = try XCTUnwrap(json["settings"] as? [String: Any])
        for key in ["stepsPerWatt", "cycleActivitiesOnTap", "spriteSize", "routineMode", "dailySchedule", "selectedActivity"] {
            settings.removeValue(forKey: key)
        }
        json["settings"] = settings
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = PersistentPetStore(directory: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: json).write(to: store.saveURL)
        let migrated = try XCTUnwrap(store.load())
        XCTAssertEqual(migrated.settings.stepsPerWatt, 20)
        XCTAssertEqual(migrated.settings.routineMode, .free)
        XCTAssertEqual(migrated.stepRemainder, 19)
        XCTAssertEqual(migrated.wattsBalance, original.wattsBalance)
        try store.save(migrated)
        XCTAssertEqual(try store.load(), migrated)
        XCTAssertEqual(PetState(now: now).settings.stepsPerWatt, 1)
    }

    func testRateChangeRetainsPartialStepsButDoesNotRewardUntilNewWalking() throws {
        var state = PetState(now: now)
        state.settings.stepsPerWatt = 100
        try sync(99, state: &state)
        XCTAssertEqual(state.stepRemainder, 99)
        state.settings.stepsPerWatt = 1
        try sync(99, state: &state)
        XCTAssertEqual(state.wattsBalance, 50)
        XCTAssertEqual(state.stepRemainder, 99)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PersistentPetStore(directory: directory)
        try store.save(state)
        state = try XCTUnwrap(store.load())
        try sync(100, state: &state)
        XCTAssertEqual(state.wattsBalance, 150)
        XCTAssertEqual(state.stepRemainder, 0)
        state.settings.stepsPerWatt = 20
        try sync(100, state: &state)
        state.settings.stepsPerWatt = 1
        try sync(100, state: &state)
        XCTAssertEqual(state.wattsBalance, 150)
        XCTAssertEqual(state.transactions.count, 1)
    }

    func testHigherRateKeepsExistingPartialProgress() throws {
        var state = PetState(now: now)
        state.settings.stepsPerWatt = 20
        try sync(19, state: &state)
        state.settings.stepsPerWatt = 50
        try sync(49, state: &state)
        XCTAssertEqual(state.wattsBalance, 50)
        XCTAssertEqual(state.stepRemainder, 49)
        try sync(50, state: &state)
        XCTAssertEqual(state.wattsBalance, 51)
        XCTAssertEqual(state.stepRemainder, 0)
    }

    func testScheduleWrapsMidnightAndManualSelectionSurvivesRollover() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let morning = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 8)))
        let midnight = calendar.startOfDay(for: morning)
        var state = PetState(now: morning)
        state.settings.routineMode = .scheduled
        state.settings.dailySchedule = [DailyActivity(minute: 420, activity: "walk"), DailyActivity(minute: 1260, activity: "sleep-front")]
        XCTAssertTrue(DailyRoutine.apply(at: morning, state: &state, calendar: calendar))
        XCTAssertEqual(state.currentActivity, "walk")
        XCTAssertFalse(DailyRoutine.apply(at: morning, state: &state, calendar: calendar))
        XCTAssertTrue(DailyRoutine.apply(at: midnight.addingTimeInterval(86400), state: &state, calendar: calendar))
        XCTAssertEqual(state.currentActivity, "sleep-front")
        state.settings.selectedActivity = "reading"
        state.currentActivity = "reading"
        XCTAssertFalse(DailyRoutine.apply(at: morning.addingTimeInterval(86400), state: &state, calendar: calendar))
        XCTAssertEqual(state.currentActivity, "reading")
        state.settings.selectedActivity = nil
        XCTAssertTrue(DailyRoutine.apply(at: morning.addingTimeInterval(86400), state: &state, calendar: calendar))
        XCTAssertEqual(state.currentActivity, "walk")
        XCTAssertTrue(state.interactions.isEmpty)
    }

    func testEmptyScheduleAndFreePlayLeaveActivityUntouched() {
        var state = PetState(now: now)
        XCTAssertFalse(DailyRoutine.apply(at: now, state: &state))
        state.settings.routineMode = .scheduled
        state.settings.dailySchedule = []
        XCTAssertFalse(DailyRoutine.apply(at: now, state: &state))
        XCTAssertEqual(state.currentActivity, "idle")
    }

    private func sync(_ steps: Double, state: inout PetState) throws {
        let sample = StepSample(id: "sample", sourceID: "watch", sourcePriority: 0, start: now,
                                end: now.addingTimeInterval(60), steps: steps)
        try GameEngine.reconcile(samples: [sample], windowStart: now, through: now.addingTimeInterval(60),
                                 cursor: "same-snapshot", state: &state)
    }
}
