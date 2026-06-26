import Foundation

/// Pure dedupe/normalize logic for the watched-folder list, delegated to by
/// `FoldersStore` (which adds UserDefaults persistence — kept out of the SPM
/// package since it imports Observation/AppKit-adjacent app wiring).
struct WatchedFolders {
    private(set) var paths: [String]

    init(paths: [String] = []) {
        self.paths = []
        for path in paths {
            add(path)
        }
    }

    /// Adds `path`, normalized and deduped against existing entries.
    mutating func add(_ path: String) {
        let normalized = Self.normalize(path)
        guard !normalized.isEmpty, !paths.contains(normalized) else { return }
        paths.append(normalized)
    }

    mutating func remove(_ path: String) {
        let normalized = Self.normalize(path)
        paths.removeAll { $0 == normalized }
    }

    static func normalize(_ path: String) -> String {
        guard !path.isEmpty else { return "" }
        return URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
