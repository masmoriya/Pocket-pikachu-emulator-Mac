import XCTest
@testable import WatchCore

final class StepReconciliationTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    func sample(_ id: String, _ steps: Double, offset: Double = 0, length: Double = 100,
                priority: Int = 0) -> StepSample {
        StepSample(id: id, sourceID: priority == 0 ? "watch" : "phone", sourcePriority: priority,
                   start: start.addingTimeInterval(offset), end: start.addingTimeInterval(offset + length), steps: steps)
    }
    func sync(_ samples: [StepSample], _ state: inout PetState, offset: Double = 0, through: Double = 1000) throws {
        try GameEngine.reconcile(samples: samples, windowStart: start.addingTimeInterval(offset),
                                 through: start.addingTimeInterval(through), cursor: "cursor", state: &state)
    }

    func legacyState() -> PetState {
        var state = PetState(now: start)
        state.settings.stepsPerWatt = 20
        return state
    }

    func testDuplicateSyncAndRemainderSurviveRoundTrip() throws {
        var state = legacyState()
        try sync([sample("a", 39), sample("a", 39)], &state)
        XCTAssertEqual(state.wattsBalance, 51)
        XCTAssertEqual(state.stepRemainder, 19)
        state = try JSONDecoder().decode(PetState.self, from: JSONEncoder().encode(state))
        try sync([sample("a", 39)], &state)
        XCTAssertEqual(state.transactions.count, 1)
        try sync([sample("a", 39), sample("b", 1, offset: 100)], &state)
        XCTAssertEqual(state.wattsBalance, 52)
        XCTAssertEqual(state.stepRemainder, 0)
    }

    func testOverlapUsesWatchThenPhoneOnlyForUncoveredPortion() throws {
        var state = legacyState()
        try sync([sample("phone", 200, length: 200, priority: 1), sample("watch", 50)], &state)
        XCTAssertEqual(state.lifetimeStepsCredited, 150)
        XCTAssertEqual(state.wattsBalance, 57)
        XCTAssertEqual(state.stepRemainder, 10)
    }

    func testCorrectionsDeletionReplacementCannotReawardSpentWatts() throws {
        var state = legacyState()
        try sync([sample("a", 100)], &state)
        try GameEngine.giveGift(amount: 55, requestID: "spent", roll: 1, now: start, state: &state)
        try sync([sample("a", 40)], &state)
        XCTAssertEqual(state.reconciliation.correctionDebt, 60)
        XCTAssertEqual(state.wattsBalance, 0)
        try sync([], &state)
        try sync([sample("replacement", 100)], &state)
        XCTAssertEqual(state.wattsBalance, 0)
        try sync([sample("replacement", 100), sample("new", 40, offset: 100)], &state)
        XCTAssertEqual(state.wattsBalance, 2)
        XCTAssertEqual(state.lifetimeStepsCredited, 140)
    }

    func testWindowRetirementAndBackfillRemainIdempotent() throws {
        var state = legacyState()
        try sync([sample("a", 100)], &state)
        try sync([sample("b", 40, offset: 100)], &state, offset: 100)
        XCTAssertEqual(state.lifetimeStepsCredited, 140)
        try sync([sample("b", 40, offset: 100)], &state, offset: 100)
        XCTAssertEqual(state.wattsBalance, 57)
        // A delayed record in the current bounded window contributes normally.
        try sync([sample("b", 40, offset: 100), sample("late", 20, offset: 300)], &state, offset: 100)
        XCTAssertEqual(state.wattsBalance, 58)
    }

    func testMidnightAndTimeZoneOnlyChangeDisplayNotRewards() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let midnight = calendar.startOfDay(for: start).addingTimeInterval(86400)
        let record = StepSample(id: "midnight", sourceID: "watch", sourcePriority: 0,
                                start: midnight.addingTimeInterval(-60), end: midnight.addingTimeInterval(60), steps: 120)
        var state = legacyState()
        try GameEngine.reconcile(samples: [record], windowStart: midnight.addingTimeInterval(-86400),
                                 through: midnight.addingTimeInterval(120), cursor: "one", state: &state)
        XCTAssertEqual(GameEngine.todaySteps(samples: [record], on: midnight.addingTimeInterval(120), calendar: calendar), 60)
        calendar.timeZone = TimeZone(secondsFromGMT: -8 * 3600)!
        XCTAssertEqual(GameEngine.todaySteps(samples: [record], on: midnight.addingTimeInterval(120), calendar: calendar), 120)
        try GameEngine.reconcile(samples: [record], windowStart: midnight.addingTimeInterval(-86400),
                                 through: midnight.addingTimeInterval(120), cursor: "two", state: &state)
        XCTAssertEqual(state.lifetimeWattsEarned, 6)
    }

    func testInvalidInputDoesNotMutate() {
        var state = legacyState()
        XCTAssertThrowsError(try sync([sample("bad", .nan)], &state))
        XCTAssertEqual(state, legacyState())
    }

    func testLargeOverlappingSnapshotUsesSamePriorityPolicy() {
        var samples = (0..<25_000).map { index in
            sample("watch-\(index)", 20, offset: Double(index * 2), length: 2)
        }
        samples += (0..<25_000).map { index in
            sample("phone-\(index)", 200, offset: Double(index * 2), length: 2, priority: 1)
        }
        XCTAssertEqual(GameEngine.eligibleStepCount(samples: samples, start: start,
                                                   end: start.addingTimeInterval(50_000)), 500_000)
    }

    func testRetirementDoesNotCreditUnobservedFutureSamplePortion() throws {
        var state = legacyState()
        try sync([sample("long", 1000, length: 1000)], &state, through: 100)
        XCTAssertEqual(state.lifetimeStepsCredited, 100)
        try sync([], &state, offset: 500, through: 1000)
        XCTAssertEqual(state.lifetimeStepsCredited, 100)
        XCTAssertEqual(state.reconciliation.finalizedEligibleSteps, 100)
    }

    func testDaylightSavingCalendarUsesActualDayBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        for (month, day, hours) in [(3, 8, 23), (11, 1, 25)] {
            let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12)))
            let interval = try XCTUnwrap(calendar.dateInterval(of: .day, for: date))
            XCTAssertEqual(interval.duration, Double(hours * 3600))
            let record = StepSample(id: "dst", sourceID: "watch", sourcePriority: 0,
                                    start: interval.start, end: interval.end, steps: Double(hours * 60))
            XCTAssertEqual(GameEngine.todaySteps(samples: [record], on: interval.end.addingTimeInterval(-1),
                                                 calendar: calendar), Int64(hours * 60 - 1))
        }
    }
}
