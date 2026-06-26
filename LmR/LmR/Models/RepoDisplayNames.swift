import Foundation

/// Disambiguates repos that share the same folder name by prefixing just
/// enough parent path components to make each one unique, e.g. `h1/hub/test/user`
/// and `h1/lab/test/user` (both named "user") become "hub/test/user" and
/// "lab/test/user" rather than colliding on "user" or even "test/user".
enum RepoDisplayNames {
    /// Returns a display name per repo, keyed by `normalizedPath`. Repos whose
    /// name is unique across `repos` map to their plain `name`.
    static func compute(for repos: [GitRepo]) -> [String: String] {
        var result: [String: String] = [:]
        for (name, group) in Dictionary(grouping: repos, by: \.name) {
            guard group.count > 1 else {
                if let only = group.first {
                    result[only.normalizedPath] = name
                }
                continue
            }

            let componentLists = group.map { $0.normalizedPath.split(separator: "/").map(String.init) }
            let maxDepth = componentLists.map(\.count).max() ?? 1

            var suffixes = componentLists.map { $0.suffix(1).joined(separator: "/") }
            var depth = 1
            while depth < maxDepth, Set(suffixes).count != suffixes.count {
                depth += 1
                suffixes = componentLists.map { $0.suffix(depth).joined(separator: "/") }
            }

            for (repo, suffix) in zip(group, suffixes) {
                result[repo.normalizedPath] = suffix
            }
        }
        return result
    }
}
