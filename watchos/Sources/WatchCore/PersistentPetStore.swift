import Foundation

public enum PersistenceError: Error, Equatable {
    case unsupportedSchema(Int), corruptSave, invalidState
}

/// One app-owned authoritative file. Widgets only consume a separate snapshot.
public struct PersistentPetStore: Sendable {
    public let directory: URL
    public var saveURL: URL { directory.appendingPathComponent("pet.json") }
    public var backupURL: URL { directory.appendingPathComponent("pet.backup.json") }
    public init(directory: URL) { self.directory = directory }

    /// nil means first install only. Decode failures are never converted to a new pet.
    /// A valid backup is returned after preserving the corrupt original verbatim.
    public func load() throws -> PetState? {
        let files = FileManager.default
        guard files.fileExists(atPath: saveURL.path) else {
            if files.fileExists(atPath: backupURL.path) { return try decode(Data(contentsOf: backupURL)) }
            return nil
        }
        let data = try Data(contentsOf: saveURL)
        do { return try decode(data) }
        catch PersistenceError.unsupportedSchema(let version) {
            throw PersistenceError.unsupportedSchema(version)
        } catch {
            try preserve(data)
            guard let backup = try? Data(contentsOf: backupURL), let state = try? decode(backup) else {
                throw PersistenceError.corruptSave
            }
            return state
        }
    }

    public func save(_ state: PetState) throws {
        try validate(state)
        let files = FileManager.default
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        if files.fileExists(atPath: saveURL.path) {
            let previous = try Data(contentsOf: saveURL)
            do {
                _ = try decode(previous)
                try previous.write(to: backupURL, options: .atomic)
            } catch PersistenceError.unsupportedSchema(let version) {
                // Never overwrite a future app version's save with an older writer.
                throw PersistenceError.unsupportedSchema(version)
            } catch {
                try preserve(previous)
            }
        }
        try data.write(to: saveURL, options: .atomic)
    }

    private func preserve(_ data: Data) throws {
        let url = directory.appendingPathComponent("pet.corrupt-\(UUID().uuidString).json")
        try data.write(to: url, options: .atomic)
    }

    private func decode(_ data: Data) throws -> PetState {
        struct Header: Decodable { var schemaVersion: Int }
        let decoder = JSONDecoder()
        let header = try decoder.decode(Header.self, from: data)
        if header.schemaVersion == 0 {
            // Version 0 contained only the original balance, points and creation date.
            // Migrate explicitly; do not invent missing historical earned/spent totals.
            struct Legacy: Decodable { var wattsBalance: Int64; var friendshipPoints: Int64; var createdAt: Date }
            let legacy = try decoder.decode(Legacy.self, from: data)
            var state = PetState(now: legacy.createdAt)
            state.wattsBalance = legacy.wattsBalance
            state.friendshipPoints = legacy.friendshipPoints
            state.currentAnimation = state.mood.animation
            try validate(state)
            return state
        }
        guard header.schemaVersion == PetState.currentSchemaVersion else {
            throw PersistenceError.unsupportedSchema(header.schemaVersion)
        }
        let state = try decoder.decode(PetState.self, from: data)
        try validate(state)
        return state
    }

    private func validate(_ state: PetState) throws {
        guard state.schemaVersion == PetState.currentSchemaVersion,
              state.wattsBalance >= 0, state.lifetimeWattsEarned >= 0,
              state.lifetimeWattsSpent >= 0, state.lifetimeStepsCredited >= 0,
              (0..<GameEngine.stepsPerWatt).contains(state.stepRemainder),
              state.transactions.count <= GameEngine.historyLimit,
              state.reconciliation.finalizedEligibleSteps.isFinite,
              state.reconciliation.finalizedEligibleSteps >= 0,
              state.reconciliation.creditedHighWater == state.lifetimeStepsCredited else {
            throw PersistenceError.invalidState
        }
    }
}
