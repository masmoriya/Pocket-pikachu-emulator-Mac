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
    func testSequencePlaysBedtimeEntryThenCyclesSleepForms() {
        let clips = [
            testClip("bed", ["walk", "tuck"], duration: 1),
            testClip("front", ["front"], duration: 2),
            testClip("side", ["side"], duration: 2),
            testClip("back", ["back"], duration: 2)
        ]
        let sequence = AnimationSequence(id: "sleep", label: "Sleeping", entry: ["bed"],
                                         loop: ["front", "side", "back"], exit: [])
        let byID = Dictionary(uniqueKeysWithValues: clips.map { ($0.id, $0) })
        XCTAssertEqual(sequence.sample(at: 0, clips: byID).frame, "walk")
        XCTAssertEqual(sequence.sample(at: 0.5, clips: byID).frame, "tuck")
        XCTAssertEqual(sequence.sample(at: 1, clips: byID).frame, "front")
        XCTAssertEqual(sequence.sample(at: 3, clips: byID).frame, "side")
        XCTAssertEqual(sequence.sample(at: 5, clips: byID).frame, "back")
        XCTAssertEqual(sequence.sample(at: 7, clips: byID).frame, "front")
    }
    func testComputerSequenceAlternatesLookingAndTyping() {
        let clips = [testClip("look", ["look"], duration: 1), testClip("type", ["type"], duration: 1)]
        let sequence = AnimationSequence(id: "computer", label: "Using computer", entry: [],
                                         loop: ["look", "type"], exit: [])
        let byID = Dictionary(uniqueKeysWithValues: clips.map { ($0.id, $0) })
        XCTAssertEqual(sequence.sample(at: 0, clips: byID).frame, "look")
        XCTAssertEqual(sequence.sample(at: 1, clips: byID).frame, "type")
        XCTAssertEqual(sequence.sample(at: 2, clips: byID).frame, "look")
    }
    func testTreatDropActionsPlayBeforeTheNextTreat() throws {
        let package = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let resources = package.appendingPathComponent("Sources/PocketPikachu/Resources")
        let library = try JSONDecoder().decode(AnimationLibrary.self,
            from: Data(contentsOf: resources.appendingPathComponent("animations.json")))
        let definitions = try JSONDecoder().decode(AnimationSequenceLibrary.self,
            from: Data(contentsOf: resources.appendingPathComponent("sequences.json")))
        let clips = Dictionary(uniqueKeysWithValues: library.clips.map { ($0.id, $0) })
        var player = AnimationActivityPlayer(sequences: definitions.sequences)

        let next = player.switchActivity(to: "icecream", from: "lolly", elapsed: 10, clips: clips)
        XCTAssertEqual(player.sample(activityID: next, elapsed: 1.5, clips: clips, repeatFinite: true).frame, "licking.lollypopFall")
        XCTAssertEqual(player.sample(activityID: next, elapsed: 4, clips: clips, repeatFinite: true).frame, "licking.icecream1")

        let after = player.switchActivity(to: "neutral", from: next, elapsed: 4, clips: clips)
        XCTAssertEqual(player.sample(activityID: after, elapsed: 1.5, clips: clips, repeatFinite: true).frame, "licking.icecreamFall")
        XCTAssertEqual(player.sample(activityID: after, elapsed: 4, clips: clips, repeatFinite: true).frame, "standBasic.stand")
    }
    func testSequenceExitIsFiniteAndManifestReferencesUniqueClips() throws {
        let exit = testClip("wake", ["awake"], duration: 1)
        let sequence = AnimationSequence(id: "studySleep", label: "Sleeping at your desk", entry: [],
                                         loop: ["sleep"], exit: ["wake"])
        let byID = ["wake": exit, "sleep": testClip("sleep", ["sleep"], duration: 2)]
        XCTAssertEqual(sequence.sampleExit(at: 0.25, clips: byID)?.frame, "awake")
        XCTAssertNil(sequence.sampleExit(at: 1, clips: byID))

        let neutral = testClip("neutral", ["neutral"], duration: 1)
        let computer = AnimationSequence(id: "computer", label: "Using computer", entry: [],
                                         loop: ["neutral"], exit: [])
        var player = AnimationActivityPlayer(sequences: [sequence, computer])
        let clips = byID.merging(["neutral": neutral]) { first, _ in first }
        let selected = player.switchActivity(to: "computer", from: "studySleep", elapsed: 5, clips: clips)
        XCTAssertEqual(player.sample(activityID: selected, elapsed: 0.25, clips: clips, repeatFinite: false).frame, "awake")
        let interrupted = player.switchActivity(to: "neutral", from: selected, elapsed: 0.25, clips: clips)
        XCTAssertEqual(player.sample(activityID: interrupted, elapsed: 0, clips: clips, repeatFinite: false).frame, "neutral")

        let package = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let resources = package.appendingPathComponent("Sources/PocketPikachu/Resources")
        let library = try JSONDecoder().decode(AnimationLibrary.self,
            from: Data(contentsOf: resources.appendingPathComponent("animations.json")))
        let definitions = try JSONDecoder().decode(AnimationSequenceLibrary.self,
            from: Data(contentsOf: resources.appendingPathComponent("sequences.json")))
        let clipIDs = Set(library.clips.map(\.id))
        let components = definitions.sequences.flatMap(\.componentIDs)
        XCTAssertTrue(components.allSatisfy(clipIDs.contains))
        XCTAssertEqual(components.count, Set(components).count)
        let choicePlayer = AnimationActivityPlayer(sequences: definitions.sequences)
        let choices = choicePlayer.choices(in: library.clips)
        XCTAssertTrue(choices.contains { $0.id == "sleep" })
        XCTAssertTrue(choices.contains { $0.id == "computer" })
        XCTAssertFalse(choices.contains { ["bed", "typing", "sleep-front", "sleep-side", "sleep-back"].contains($0.id) })
        XCTAssertEqual(choicePlayer.canonicalActivity("typing"), "computer")
        XCTAssertEqual(choicePlayer.canonicalActivity("sleep-front"), "sleep")
    }
    private func testClip(_ id: String, _ frames: [String], duration: Double) -> AnimationClip {
        AnimationClip(id: id, label: id, source: "test", loop: true, loopStart: 0,
                      steps: frames.map { .init(frame: $0, duration: duration / Double(frames.count)) }, props: [])
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
