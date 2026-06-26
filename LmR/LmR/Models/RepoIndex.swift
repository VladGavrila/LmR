import Foundation

/// Ordered, deduped collection of discovered repos, persisted as the on-disk
/// JSON cache. Dedupe is by normalized filesystem path, not `id` — rescans
/// produce fresh `GitRepo` values for the same on-disk repo.
struct RepoIndex: Codable {
    private(set) var repos: [GitRepo]

    init(repos: [GitRepo] = []) {
        self.repos = []
        for repo in repos {
            add(repo)
        }
    }

    func contains(path: URL) -> Bool {
        let target = path.standardizedFileURL.path
        return repos.contains { $0.normalizedPath == target }
    }

    /// Adds `repo`, replacing any existing entry at the same path so a rescan
    /// refreshes metadata (e.g. remote URL) without creating a duplicate.
    mutating func add(_ repo: GitRepo) {
        if let idx = repos.firstIndex(where: { $0.normalizedPath == repo.normalizedPath }) {
            repos[idx] = repo
        } else {
            repos.append(repo)
        }
    }

    mutating func remove(path: URL) {
        let target = path.standardizedFileURL.path
        repos.removeAll { $0.normalizedPath == target }
    }

    /// Removes every repo whose parent folder matches `folder`, e.g. before a
    /// rescan of that folder replaces its contents.
    mutating func removeAll(under folder: URL) {
        let target = folder.standardizedFileURL.path
        repos.removeAll { $0.parentFolder.standardizedFileURL.path == target }
    }
}

extension RepoIndex {
    private enum CodingKeys: String, CodingKey {
        case repos
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        repos = try container.decode([GitRepo].self, forKey: .repos)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(repos, forKey: .repos)
    }
}
