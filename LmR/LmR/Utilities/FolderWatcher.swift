import Foundation
import CoreServices

/// Watches a set of root folders with FSEvents and triggers a debounced
/// rescan of whichever root changed, so newly created/removed repos are
/// auto-added/pruned without a manual refresh.
@MainActor
final class FolderWatcher {
    /// Carries the watched root path through to the C callback, since
    /// `FSEventStreamContext.info` is the only data the callback receives.
    private final class StreamBox {
        let watcher: FolderWatcher
        let path: String
        init(watcher: FolderWatcher, path: String) {
            self.watcher = watcher
            self.path = path
        }
    }

    private var streams: [String: FSEventStreamRef] = [:]
    private var boxes: [String: StreamBox] = [:]
    private var debounceTasks: [String: Task<Void, Never>] = [:]
    private let onChange: (URL) -> Void

    init(onChange: @escaping (URL) -> Void) {
        self.onChange = onChange
    }

    /// Starts/stops streams so the watched set exactly matches `paths`.
    func setWatchedPaths(_ paths: [String]) {
        let desired = Set(paths)
        for path in streams.keys where !desired.contains(path) {
            stop(path: path)
        }
        for path in desired where streams[path] == nil {
            start(path: path)
        }
    }

    func stopAll() {
        for path in Array(streams.keys) {
            stop(path: path)
        }
    }

    private func start(path: String) {
        let box = StreamBox(watcher: self, path: path)
        boxes[path] = box

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(box).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let box = Unmanaged<StreamBox>.fromOpaque(info).takeUnretainedValue()
            Task { @MainActor in
                box.watcher.handleEvent(rootPath: box.path)
            }
        }
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            UInt32(kFSEventStreamCreateFlagNone)
        ) else {
            boxes.removeValue(forKey: path)
            return
        }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
        streams[path] = stream
    }

    private func stop(path: String) {
        guard let stream = streams.removeValue(forKey: path) else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        boxes.removeValue(forKey: path)
        debounceTasks.removeValue(forKey: path)?.cancel()
    }

    /// Debounces bursts of events for `rootPath` (e.g. a `git clone` writes
    /// many files) so a single rescan runs ~0.5s after the burst settles.
    private func handleEvent(rootPath: String) {
        debounceTasks[rootPath]?.cancel()
        debounceTasks[rootPath] = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            onChange(URL(fileURLWithPath: rootPath))
        }
    }
}
