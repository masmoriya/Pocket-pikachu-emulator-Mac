import Foundation
import CoreServices

/// FSEvents watches nested session folders without one file descriptor per log.
final class SessionWatcher {
    private var stream: FSEventStreamRef?
    private var debounce: DispatchWorkItem?
    private let queue = DispatchQueue(label: "PocketPikachu.session-events")
    private let onChange: () -> Void
    init(path: String, onChange: @escaping () -> Void) {
        self.onChange = onChange
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<SessionWatcher>.fromOpaque(info).takeUnretainedValue().changed()
        }
        stream = FSEventStreamCreate(nil, callback, &context, [path + "/sessions", path + "/archived_sessions"] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 1,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer))
        if let stream { FSEventStreamSetDispatchQueue(stream, queue); FSEventStreamStart(stream) }
    }
    private func changed() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange() }
        debounce = work
        queue.asyncAfter(deadline: .now() + 1, execute: work)
    }
    deinit {
        debounce?.cancel()
        if let stream { FSEventStreamStop(stream); FSEventStreamInvalidate(stream); FSEventStreamRelease(stream) }
    }
}
