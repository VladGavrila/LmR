import Foundation

/// Where creating a new local repo named `name` would land under `root`.
/// Unlike `ClonePathPlanner`, there's no URL to derive nested subdirectories
/// from — the destination is always a single new folder directly under `root`.
enum NewRepoPathPlanner {
    /// Returns `nil` when `name` is empty, `.`/`..`, or contains a path
    /// separator, which drives form validation.
    static func plan(name: String, into root: URL) -> URL? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != ".", trimmed != ".." else { return nil }
        guard !trimmed.contains("/") else { return nil }
        return root.appendingPathComponent(trimmed)
    }
}
