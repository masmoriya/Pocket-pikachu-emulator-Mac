import Foundation
import XCTest
@testable import WatchCore

final class ClockFormattingTests: XCTestCase {
    private let utc = TimeZone(secondsFromGMT: 0)!
    private let us = Locale(identifier: "en_US")

    private func instant(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func display(_ value: String, _ format: GameSettings.ClockFormat,
                         locale: Locale = Locale(identifier: "en_US"),
                         zone: TimeZone = TimeZone(secondsFromGMT: 0)!) -> String {
        ClockFormatting.string(date: instant(value), format: format, locale: locale, timeZone: zone)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    func testTwelveAndTwentyFourHourPreferences() {
        XCTAssertEqual(display("2026-10-27T13:05:59Z", .twelveHour), "1:05 PM")
        XCTAssertEqual(display("2026-10-27T13:05:59Z", .twentyFourHour), "13:05")
        XCTAssertEqual(display("2026-10-27T01:05:00Z", .twelveHour), "1:05 AM")
    }

    func testMidnightRolloverUsesActualDate() {
        XCTAssertEqual(display("2026-10-27T23:59:59Z", .twentyFourHour), "23:59")
        XCTAssertEqual(display("2026-10-28T00:00:00Z", .twentyFourHour), "00:00")
        XCTAssertEqual(display("2026-10-28T00:00:00Z", .twelveHour), "12:00 AM")
        XCTAssertEqual(display("2026-10-28T12:00:00Z", .twelveHour), "12:00 PM")
    }

    func testChangingTimeZoneImmediatelyReformatsSameInstant() {
        let value = "2026-10-28T01:05:00Z"
        XCTAssertEqual(display(value, .twentyFourHour, zone: utc), "01:05")
        XCTAssertEqual(display(value, .twentyFourHour,
                               zone: TimeZone(identifier: "America/Los_Angeles")!), "18:05")
        XCTAssertEqual(display(value, .twentyFourHour,
                               zone: TimeZone(identifier: "Asia/Tokyo")!), "10:05")
    }

    func testSpringDaylightSavingSkipsMissingHour() {
        let zone = TimeZone(identifier: "America/Los_Angeles")!
        XCTAssertEqual(display("2026-03-08T09:59:59Z", .twentyFourHour, zone: zone), "01:59")
        XCTAssertEqual(display("2026-03-08T10:00:00Z", .twentyFourHour, zone: zone), "03:00")
    }

    func testFallDaylightSavingRepeatsHourWithoutClockDrift() {
        let zone = TimeZone(identifier: "America/Los_Angeles")!
        XCTAssertEqual(display("2026-11-01T08:59:59Z", .twentyFourHour, zone: zone), "01:59")
        XCTAssertEqual(display("2026-11-01T09:00:00Z", .twentyFourHour, zone: zone), "01:00")
    }

    func testSystemFormatFollowsLocale() {
        let value = "2026-10-27T13:05:00Z"
        XCTAssertEqual(display(value, .system, locale: us), "1:05 PM")
        XCTAssertEqual(display(value, .system, locale: Locale(identifier: "en_GB")), "13:05")
        XCTAssertEqual(display(value, .system, locale: Locale(identifier: "fr_FR")), "13:05")
    }
}
