import Foundation

/// Decides whether an ancestor directory left behind by a deleted repo should
/// be removed during cleanup (e.g. `org/module/part` left behind once `part`
/// is trashed). Pure — takes a directory listing and the watched-folder set
/// rather than touching the filesystem itself, so the caller (`ContentView`)
/// stays the only place that actually deletes anything.
enum EmptyDirectoryCheck {
    /// `.DS_Store` is Finder's own bookkeeping file, not user content — a
    /// directory containing only it should still count as empty, or cleanup
    /// silently stops the moment someone has browsed the folder in Finder.
    private static let ignorableEntries: Set<String> = [".DS_Store"]

    /// `false` for `path` itself being a folder the user has explicitly asked
    /// LmR to watch — deleting a repo inside it should never silently remove
    /// a watched root out from under them, empty or not.
    static func isRemovable(path: String, contents: [String], watchedPaths: Set<String>) -> Bool {
        guard !watchedPaths.contains(path) else { return false }
        return contents.allSatisfy { ignorableEntries.contains($0) }
    }
}
