import XCTest
@testable import WatchCore

final class PersistenceTests: XCTestCase {
    func store() throws -> PersistentPetStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return PersistentPetStore(directory: directory)
    }

    func testAbsentOnlyReturnsNilAndSavedStateRoundTrips() throws {
        let store = try store()
        XCTAssertNil(try store.load())
        var state = PetState(now: Date(timeIntervalSince1970: 123))
        try GameEngine.giveGift(amount: 25, requestID: "gift", roll: 3,
                               now: state.createdAt, state: &state)
        try store.save(state)
        XCTAssertEqual(try store.load(), state)
        var reopened = try XCTUnwrap(store.load())
        XCTAssertThrowsError(try GameEngine.giveGift(amount: 25, requestID: "gift", roll: 3,
                                                    now: state.createdAt.addingTimeInterval(100), state: &reopened))
        XCTAssertEqual(reopened, state)
    }

    func testCorruptionPreservedAndPreviousAtomicSaveRecovered() throws {
        let store = try store()
        let first = PetState(now: Date(timeIntervalSince1970: 123))
        try store.save(first)
        var second = first
        second.settings.colored = false
        try store.save(second)
        let corrupt = Data("interrupted bytes".utf8)
        try corrupt.write(to: store.saveURL)
        XCTAssertEqual(try store.load(), first)
        let files = try FileManager.default.contentsOfDirectory(at: store.directory, includingPropertiesForKeys: nil)
        let preserved = try XCTUnwrap(files.first { $0.lastPathComponent.hasPrefix("pet.corrupt-") })
        XCTAssertEqual(try Data(contentsOf: preserved), corrupt)
        XCTAssertEqual(try Data(contentsOf: store.saveURL), corrupt)
        // Saving recovered state must retain the known-good backup.
        try store.save(first)
        XCTAssertEqual(try store.load(), first)
    }

    func testCorruptionWithoutBackupThrowsNeverResets() throws {
        let store = try store()
        let corrupt = Data("{".utf8)
        try corrupt.write(to: store.saveURL)
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(try Data(contentsOf: store.saveURL), corrupt)
    }

    func testFutureSchemaRejectedEvenWhenBackupExists() throws {
        let store = try store()
        let state = PetState(now: Date(timeIntervalSince1970: 123))
        try store.save(state)
        try store.save(state)
        let future = Data("{\"schemaVersion\":999}".utf8)
        try future.write(to: store.saveURL)
        XCTAssertThrowsError(try store.load()) { XCTAssertEqual($0 as? PersistenceError, .unsupportedSchema(999)) }
        XCTAssertThrowsError(try store.save(state))
        XCTAssertEqual(try Data(contentsOf: store.saveURL), future)
    }

    func testExplicitVersionZeroMigrationPreservesProgress() throws {
        let store = try store()
        let old = Data("{\"schemaVersion\":0,\"wattsBalance\":123,\"friendshipPoints\":3001,\"createdAt\":123}".utf8)
        try old.write(to: store.saveURL)
        let state = try XCTUnwrap(store.load())
        XCTAssertEqual(state.schemaVersion, 1)
        XCTAssertEqual(state.wattsBalance, 123)
        XCTAssertEqual(state.settings.stepsPerWatt, 20)
        XCTAssertEqual(state.mood, .love)
        try store.save(state)
        XCTAssertEqual(try store.load(), state)
    }
}
