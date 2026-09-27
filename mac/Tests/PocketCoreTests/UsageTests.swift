import XCTest
@testable import PocketCore

final class UsageTests: XCTestCase {
    let origin = Date(timeIntervalSince1970: 1_000)
    func sample(_ seconds: Double, _ total: Int64) -> TokenSample {
        TokenSample(timestamp: origin.addingTimeInterval(seconds), total: total)
    }
    func testBaselineAndCumulativeDeltasAcrossRestart() throws {
        var ledger = UsageLedger()
        XCTAssertEqual(ledger.reconcile([.init(id: "a", samples: [sample(-10, 100)])], now: origin), 0)
        XCTAssertEqual(ledger.reconcile([.init(id: "a", samples: [sample(10, 180)])], now: origin.addingTimeInterval(10)), 80)
        ledger = try JSONDecoder().decode(UsageLedger.self, from: JSONEncoder().encode(ledger))
        XCTAssertEqual(ledger.reconcile([.init(id: "a", samples: [sample(10, 180), sample(20, 210)])], now: origin.addingTimeInterval(20)), 30)
        XCTAssertEqual(ledger.reconcile([.init(id: "a", samples: [sample(10, 180), sample(20, 210)])], now: origin.addingTimeInterval(30)), 0)
    }
    func testForkAndEmptyIntermediateAncestor() {
        var ledger = UsageLedger()
        _ = ledger.reconcile([.init(id: "parent", samples: [sample(-10, 100)])], now: origin)
        let child = SessionUsage(id: "child", parent: "parent", forkTime: origin.addingTimeInterval(5), samples: [])
        let grandchild = SessionUsage(id: "grandchild", parent: "child", forkTime: origin.addingTimeInterval(10), samples: [sample(15, 120)])
        XCTAssertEqual(ledger.reconcile([grandchild, child], now: origin.addingTimeInterval(20)), 20)
        XCTAssertEqual(ledger.reconcile([grandchild, child], now: origin.addingTimeInterval(30)), 0)
    }
    func testInheritedEventsAndConcurrentSessions() {
        var ledger = UsageLedger()
        _ = ledger.reconcile([], now: origin)
        let parent = SessionUsage(id: "parent", samples: [sample(1, 100), sample(10, 200)])
        let child = SessionUsage(id: "child", parent: "parent", forkTime: origin.addingTimeInterval(5), samples: [sample(1, 100), sample(8, 150)])
        XCTAssertEqual(ledger.reconcile([child, parent], now: origin.addingTimeInterval(20)), 250)
    }
    func testOldHistoryDiscoveredLaterDoesNotAward() {
        var ledger = UsageLedger()
        _ = ledger.reconcile([], now: origin)
        XCTAssertEqual(ledger.reconcile([.init(id: "old", samples: [sample(-100, 4000)])], now: origin.addingTimeInterval(10)), 0)
    }
    func testParserCountsCachedInputAndReasoningExactlyOnce() {
        let data = Data("""
        {"type":"session_meta","payload":{"id":"session","timestamp":"2026-01-01T00:00:00Z"}}
        {"type":"event_msg","timestamp":"2026-01-01T00:00:01Z","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":80,"output_tokens":20,"reasoning_output_tokens":10,"total_tokens":120}}}}
        {"type":"response_item","payload":{"content":"private text"}}
        {"type":"event_msg","payload":{"type":"token_count","info":null}}

        """.utf8)
        let parsed = SessionParser.parse(data, fallbackID: "fallback")
        XCTAssertEqual(parsed.session?.id, "session")
        XCTAssertEqual(parsed.session?.samples.map(\.total), [120])
        XCTAssertEqual(parsed.malformed, 0)
    }
    func testPartialRecordIsNotConsumed() {
        let parsed = SessionParser.parse(Data("{\"type\":\"event_msg\",\"payload\":{\"type\":\"token_count\"}".utf8), fallbackID: "a")
        XCTAssertEqual(parsed.malformed, 0)
        XCTAssertEqual(parsed.session?.samples, [])
    }
    func testScannerDoesNotReadUnchangedFilesAndHandlesArchiveMove() async throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let sessions = home.appendingPathComponent("sessions")
        let archive = home.appendingPathComponent("archived_sessions")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
        let file = sessions.appendingPathComponent("test.jsonl")
        let event = "{\"type\":\"event_msg\",\"timestamp\":\"2026-01-01T00:00:01Z\",\"payload\":{\"type\":\"token_count\",\"info\":{\"total_token_usage\":{\"input_tokens\":100,\"output_tokens\":20}}}}\n"
        try Data(event.utf8).write(to: file)
        let scanner = UsageScanner()
        let first = await scanner.scan(home: home.path)
        XCTAssertGreaterThan(first.bytesRead, 0)
        let unchanged = await scanner.scan(home: home.path)
        XCTAssertEqual(unchanged.bytesRead, 0)
        try FileManager.default.moveItem(at: file, to: archive.appendingPathComponent("test.jsonl"))
        let moved = await scanner.scan(home: home.path)
        XCTAssertEqual(moved.sessions.first?.samples.first?.total, 120)
    }
}

extension UsageTests {
    func testMissingForkParentDefersRatherThanDoubleCounting() {
        var ledger = UsageLedger()
        _ = ledger.reconcile([], now: origin)
        let child = SessionUsage(id: "child", parent: "parent", forkTime: origin.addingTimeInterval(5), samples: [sample(10, 150)])
        XCTAssertEqual(ledger.reconcile([child], now: origin.addingTimeInterval(10)), 0)
        XCTAssertEqual(ledger.reconcile([.init(id: "parent", samples: [sample(-10, 100)])], now: origin.addingTimeInterval(20)), 50)
    }
    func testCounterResetUsesNewRequestNotPreviousHighWater() {
        var ledger = UsageLedger()
        _ = ledger.reconcile([.init(id: "a", samples: [sample(-10, 1000)])], now: origin)
        let reset = TokenSample(timestamp: origin.addingTimeInterval(5), total: 30, last: 30)
        XCTAssertEqual(ledger.reconcile([.init(id: "a", samples: [reset])], now: origin.addingTimeInterval(10)), 30)
        XCTAssertEqual(ledger.reconcile([.init(id: "a", samples: [reset, sample(15, 60)])], now: origin.addingTimeInterval(20)), 30)
    }
    func testEmbeddedAncestorMetadataCannotReplaceChildIdentity() {
        let lines = """
        {"type":"session_meta","payload":{"id":"child","forked_from_id":"parent","timestamp":"2026-01-02T00:00:00Z"}}
        {"type":"session_meta","payload":{"id":"parent","timestamp":"2026-01-01T00:00:00Z"}}

        """
        let parsed = SessionParser.parse(Data(lines.utf8), fallbackID: "fallback")
        XCTAssertEqual(parsed.session?.id, "child")
        XCTAssertEqual(parsed.session?.parent, "parent")
    }
    func testScannerIncrementalPartialAndTruncatedFile() async throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let directory = home.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("one.jsonl")
        let header = "{\"type\":\"session_meta\",\"payload\":{\"id\":\"canonical\"}}\n"
        let record = "{\"type\":\"event_msg\",\"timestamp\":\"2026-01-01T00:00:01Z\",\"payload\":{\"type\":\"token_count\",\"info\":{\"total_token_usage\":{\"input_tokens\":100,\"output_tokens\":20}}}}"
        try Data((header + record).utf8).write(to: file)
        let scanner = UsageScanner()
        let first = await scanner.scan(home: home.path)
        XCTAssertEqual(first.sessions.flatMap(\.samples).count, 0)
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd(); try handle.write(contentsOf: Data([10])); try handle.close()
        let completed = await scanner.scan(home: home.path)
        XCTAssertEqual(completed.sessions.first?.id, "canonical")
        XCTAssertEqual(completed.sessions.first?.samples.first?.total, 120)
        try Data((header + record + "\n").utf8).write(to: file, options: .atomic)
        let rewritten = await scanner.scan(home: home.path)
        XCTAssertEqual(rewritten.sessions.flatMap(\.samples).map(\.total), [120])
    }
}

extension UsageTests {
    func testFreshBaselineSkipsOldFilesAndRestartKeepsOffsets() async throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let directory = home.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("old.jsonl")
        try Data("{\"type\":\"session_meta\",\"payload\":{\"id\":\"old\"}}\n".utf8).write(to: file)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 100)], ofItemAtPath: file.path)
        let scanner = UsageScanner()
        let skipped = await scanner.scan(home: home.path, since: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(skipped.fileCount, 1)
        XCTAssertEqual(skipped.bytesRead, 0)
        let scanned = await scanner.scan(home: home.path)
        XCTAssertGreaterThan(scanned.bytesRead, 0)
        let restored = UsageScanner(cursors: scanned.cursors, home: home.path)
        let restart = await restored.scan(home: home.path)
        XCTAssertEqual(restart.bytesRead, 0)
    }
}

extension UsageTests {
    func testSubagentOpeningSnapshotDoesNotAwardInheritedTokens() {
        var ledger = UsageLedger()
        _ = ledger.reconcile([], now: origin)
        var child = SessionUsage(id: "child", forkTime: origin.addingTimeInterval(1), samples: [
            .init(timestamp: origin.addingTimeInterval(2), total: 10_000, last: 0),
            .init(timestamp: origin.addingTimeInterval(3), total: 10_100, last: 100)
        ])
        child.isSubagent = true
        XCTAssertEqual(ledger.reconcile([child], now: origin.addingTimeInterval(5)), 100)
    }
    func testIndependentSubagentOpeningUsageIsCounted() {
        var ledger = UsageLedger()
        _ = ledger.reconcile([], now: origin)
        var child = SessionUsage(id: "child", forkTime: origin.addingTimeInterval(1), samples: [
            .init(timestamp: origin.addingTimeInterval(2), total: 100, last: 100)
        ])
        child.isSubagent = true
        XCTAssertEqual(ledger.reconcile([child], now: origin.addingTimeInterval(5)), 100)
    }
}
