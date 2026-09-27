import XCTest
@testable import PocketCore

final class PetTests: XCTestCase {
    func testFractionalStepsAndProspectiveConversion() {
        var progression = Progression()
        progression.award(1500)
        XCTAssertEqual(progression.steps, 1)
        XCTAssertEqual(progression.fractionalStep, 0.5)
        progression.tokensPerStep = 100
        progression.award(50)
        XCTAssertEqual(progression.steps, 2)
        XCTAssertEqual(progression.fractionalStep, 0)
        progression.award(1800)
        XCTAssertEqual(progression.watts, 51)
        XCTAssertEqual(progression.stepsTowardWatt, 0)
    }
    func testGiftCostCannotGoNegativeAndAllBandsResolve() {
        var progression = Progression()
        XCTAssertFalse(progression.spend(-1))
        XCTAssertFalse(progression.spend(51))
        XCTAssertTrue(progression.spend(50))
        XCTAssertEqual(progression.watts, 0)
        XCTAssertEqual(PetBehavior.gift(amount: 899, friendship: .love, roll: 9), "ball")
        XCTAssertEqual(PetBehavior.gift(amount: 900, friendship: .love, roll: 9), "horn")
        XCTAssertEqual(PetBehavior.gift(amount: 450, friendship: .mad, roll: 9), "hearts")
    }
    func testManualActivityOverridesRestAndFriendshipIsIndependent() {
        var pet = PetState(codexHome: "/tmp/example")
        pet.lastInteraction = Date(timeIntervalSince1970: 1000)
        XCTAssertEqual(PetBehavior.restingActivity(state: pet, now: Date(timeIntervalSince1970: 2000)), "reading")
        XCTAssertEqual(PetBehavior.restingActivity(state: pet, now: Date(timeIntervalSince1970: 3000)), "sleep-front")
        pet.selectedActivity = "piano"
        XCTAssertNil(PetBehavior.restingActivity(state: pet, now: Date(timeIntervalSince1970: 3000)))
        XCTAssertEqual(pet.friendship, .love)
    }
    func testPersistenceRoundTripAndCorruptionPreserved() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CompanionStore(url: directory.appendingPathComponent("state.json"))
        var saved = SavedCompanion(pet: PetState(codexHome: "/tmp/codex"))
        saved.pet.progression.award(20000)
        try store.save(saved)
        let loaded = try store.load(defaultHome: "ignored")
        XCTAssertEqual(loaded.pet.progression, saved.pet.progression)
        try Data("broken".utf8).write(to: store.url)
        XCTAssertThrowsError(try store.load(defaultHome: "ignored"))
        XCTAssertEqual(try String(contentsOf: store.url), "broken")
    }
    func testMenuBarPreferencePreservesExistingSaves() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        var saved = SavedCompanion(pet: PetState(codexHome: "/tmp/codex"))
        saved.pet.progression.award(20000)
        let legacyData = try encoder.encode(saved)
        let legacyJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: legacyData) as? [String: Any])
        let legacyPet = try XCTUnwrap(legacyJSON["pet"] as? [String: Any])
        XCTAssertNil(legacyPet["menuBarStyle"])
        let restored = try decoder.decode(SavedCompanion.self, from: legacyData)
        XCTAssertEqual(restored.pet.menuBarStyle ?? .paw, .paw)
        XCTAssertEqual(restored.pet.progression, saved.pet.progression)
        for style in MenuBarStyle.allCases {
            saved.pet.menuBarStyle = style
            let roundTrip = try decoder.decode(SavedCompanion.self, from: encoder.encode(saved))
            XCTAssertEqual(roundTrip.pet.menuBarStyle, style)
            XCTAssertEqual(roundTrip.pet.progression, saved.pet.progression)
        }
    }
    func testClipLoopKeepsIntroOutOfRepeat() {
        let clip = AnimationClip(id: "test", label: "Test", source: "test", loop: true, loopStart: 1,
            steps: [.init(frame: "intro", duration: 1), .init(frame: "a", duration: 1), .init(frame: "b", duration: 1)], props: [])
        XCTAssertEqual(clip.frame(at: 0), "intro")
        XCTAssertEqual(clip.frame(at: 3), "a")
        XCTAssertEqual(clip.frame(at: 4), "b")
    }
}

extension PetTests {
    func testMilestonesOnlyCelebrateNewThresholds() {
        XCTAssertEqual(PetBehavior.crossedMilestone(from: 999, to: 1000), 1000)
        XCTAssertNil(PetBehavior.crossedMilestone(from: 1000, to: 2000))
        XCTAssertEqual(PetBehavior.crossedMilestone(from: 900, to: 100_000), 100_000)
        XCTAssertNil(PetBehavior.crossedMilestone(from: 100_000, to: 100_000))
    }
}


extension PetTests {
    func testMenuBarOnlySurvivesRestartAndOlderSaves() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        var saved = SavedCompanion(pet: PetState(codexHome: "/tmp/codex"))
        let legacyData = try encoder.encode(saved)
        let legacy = try decoder.decode(SavedCompanion.self, from: legacyData)
        XCTAssertFalse(legacy.pet.menuBarOnly ?? false)
        saved.pet.menuBarStyle = .monochrome
        for hidden in [true, false] {
            saved.pet.menuBarOnly = hidden
            let restored = try decoder.decode(SavedCompanion.self, from: encoder.encode(saved))
            XCTAssertEqual(restored.pet.menuBarOnly, hidden)
            XCTAssertEqual(restored.pet.menuBarStyle, .monochrome)
        }
    }
}
