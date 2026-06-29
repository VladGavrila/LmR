import Foundation

/// Where a `git clone` of `remoteURL` would land under `root`, derived from the
/// remote's URL path (host excluded). The clone *source* stays the original
/// pasted URL — only the destination directory is derived.
struct ClonePlan: Equatable {
    let parentDirectory: URL
    let repoFolderName: String
    let destination: URL
}

enum ClonePathPlanner {
    /// Returns `nil` when `remoteURL` has no recognizable web host (e.g. a
    /// local-path remote) or doesn't parse, which drives form validation.
    static func plan(remoteURL: String, into root: URL) -> ClonePlan? {
        guard let httpsURL = RemoteURLConverter.httpsURL(from: remoteURL) else { return nil }

        let components = httpsURL.pathComponents
            .filter { $0 != "/" }
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }

        guard let repoFolderName = components.last else { return nil }
        let subdirectories = components.dropLast()

        var parentDirectory = root
        for component in subdirectories {
            parentDirectory = parentDirectory.appendingPathComponent(component)
        }

        return ClonePlan(
            parentDirectory: parentDirectory,
            repoFolderName: repoFolderName,
            destination: parentDirectory.appendingPathComponent(repoFolderName)
        )
    }
}
