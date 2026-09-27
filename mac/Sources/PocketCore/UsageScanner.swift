import Foundation

public struct UsageCursor: Codable, Sendable {
    public var offset: UInt64 = 0
    public var modified: Date = .distantPast
    public var inode: UInt64 = 0
    public var session: SessionUsage?
}
public struct UsageScan: Sendable {
    public var sessions: [SessionUsage] = []
    public var errors: [String] = []
    public var bytesRead = 0
    public var fileCount = 0
    public var latest: Date?
    public var cursors: [String: UsageCursor] = [:]
}
public actor UsageScanner {
    private var checkpoints: [String: UsageCursor]
    private var home: String
    public init(cursors: [String: UsageCursor] = [:], home: String = "") {
        checkpoints = cursors; self.home = home
    }
    public func invalidate() { checkpoints.removeAll() }
    public func scan(home: String, since: Date = .distantPast, knownSessions: Set<String> = [], requiredParents: Set<String> = []) -> UsageScan {
        if self.home != home { checkpoints.removeAll(); self.home = home }
        var result = UsageScan()
        let manager = FileManager.default
        guard manager.fileExists(atPath: home) else { result.errors = ["Choose an existing Codex home."]; return result }
        var files: [URL] = [], rootsFound = 0
        for name in ["sessions", "archived_sessions"] {
            let root = URL(fileURLWithPath: home).appendingPathComponent(name)
            guard manager.fileExists(atPath: root.path) else { continue }
            rootsFound += 1
            var enumerationFailed = false
            guard let enumerator = manager.enumerator(at: root, includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles], errorHandler: { _, _ in enumerationFailed = true; return false }) else {
                result.errors.append("Cannot read \(name)."); continue
            }
            files += enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "jsonl" }
            if enumerationFailed { result.errors.append("Cannot enumerate all local Codex sessions. Check folder access.") }
        }
        result.fileCount = files.count
        var seen = Set<String>()
        func read(_ file: URL, force: Bool = false) {
            guard !seen.contains(file.path) else { return }
            do {
                let attributes = try manager.attributesOfItem(atPath: file.path)
                let modified = attributes[.modificationDate] as? Date ?? .distantPast
                // A fresh pet earns nothing from untouched historical files. Read an old
                // file lazily only if it changes or a new fork needs its counter baseline.
                guard force || modified >= since else { return }
                seen.insert(file.path)
                let update = try readFile(file, attributes: attributes, force: force)
                result.sessions += update.sessions
                result.bytesRead += update.bytesRead
                result.errors += update.errors
                if let latest = update.latest { result.latest = max(result.latest ?? .distantPast, latest) }
            } catch { result.errors.append("A session could not be read. Check folder access.") }
        }
        for file in files { read(file) }
        // Resolve only the ancestor files needed by newly observed forks.
        var resolved = knownSessions.union(result.sessions.map(\.id))
        var attempted = Set<String>()
        while let parent = requiredParents.union(result.sessions.compactMap(\.parent)).first(where: { !resolved.contains($0) && !attempted.contains($0) }) {
            attempted.insert(parent)
            if let file = files.first(where: { $0.deletingPathExtension().lastPathComponent.hasSuffix(parent) }) {
                read(file, force: true)
                resolved.formUnion(result.sessions.map(\.id))
            }
            if !resolved.contains(parent) { result.errors.append("A fork is waiting for its parent session before awarding steps.") }
        }
        if rootsFound == 0 { result.errors.append("No Codex sessions found in this folder yet.") }
        result.errors = Array(Set(result.errors)).sorted()
        result.cursors = checkpoints
        return result
    }
    private func readFile(_ file: URL, attributes: [FileAttributeKey: Any], force: Bool) throws -> UsageScan {
        var result = UsageScan()
        let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        let inode = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
        let modified = attributes[.modificationDate] as? Date ?? .distantPast
        var cursor = checkpoints[file.path] ?? UsageCursor()
        if !force && cursor.modified == modified && cursor.offset == size && cursor.inode == inode { return result }
        if force || size < cursor.offset || inode != cursor.inode || (size == cursor.offset && modified != cursor.modified) {
            cursor = UsageCursor()
        }
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        try handle.seek(toOffset: cursor.offset)
        var buffer = Data(), consumed = cursor.offset
        var updated = cursor.session
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            result.bytesRead += chunk.count
            buffer.append(chunk)
            guard let last = buffer.lastIndex(of: 10) else {
                if buffer.count > 16_777_216 { throw CocoaError(.fileReadCorruptFile) }
                continue
            }
            let complete = Data(buffer[...last])
            let parsed = SessionParser.parse(complete,
                fallbackID: updated?.id ?? file.deletingPathExtension().lastPathComponent, metadata: updated)
            if parsed.malformed > 0 { result.errors.append("Skipped malformed usage records in a session.") }
            if var session = parsed.session {
                if !session.samples.isEmpty || updated == nil { result.sessions.append(session) }
                if let latest = session.samples.map(\.timestamp).max() { result.latest = max(result.latest ?? .distantPast, latest) }
                session.samples = []
                updated = session
            }
            consumed += UInt64(complete.count)
            buffer = Data(buffer.dropFirst(complete.count))
        }
        cursor.offset = consumed; cursor.modified = modified; cursor.inode = inode; cursor.session = updated
        checkpoints[file.path] = cursor
        return result
    }
}
