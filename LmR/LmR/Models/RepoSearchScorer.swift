import Foundation

/// Pure, testable scoring logic for ranking repos against a palette search query.
/// Higher is better; 0 = no match.
///
/// Score hierarchy (descending):
///   1000  exact name match
///    500+ name prefix (bonus for shorter excess)
///    100  name contains query
///     10  any other field (display path, remote URL, branch)
///      0  no match
enum RepoSearchScorer {
    static func score(repo: GitRepo, query: String, branch: String? = nil) -> Int {
        let q = query.lowercased()
        guard !q.isEmpty else { return 0 }
        let name = repo.name.lowercased()

        if name == q { return 1000 }
        if name.hasPrefix(q) { return 500 + max(0, 20 - (name.count - q.count)) }
        if name.contains(q) { return 100 }

        let others: [String?] = [repo.displayPath, repo.remoteURL, branch]
        for value in others.compactMap({ $0?.lowercased() }) where !value.isEmpty {
            if value.contains(q) { return 10 }
        }
        return 0
    }
}
