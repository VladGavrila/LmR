import Foundation

/// Pure, testable filtering and sorting logic for the repo dashboard. Store
/// queries are injected as closures so this type has no dependency on
/// SwiftUI or the concrete store types. Favorites/tag-rank closures are
/// stubbed by callers in phase 1 and wired up in phase 4.
struct RepoListFilter {
    var searchText: String

    init(searchText: String = "") {
        self.searchText = searchText
    }

    /// Returns `repos` sorted and filtered according to the current filter state.
    ///
    /// - Parameters:
    ///   - repos: Flat list from RepoStore.
    ///   - isFavorite: Returns `true` when a repo's path is a user favourite.
    ///   - tagRank: Returns the sort rank for a repo's path (lower = earlier).
    ///   - branch: Returns the cached branch name for a repo's path, if known.
    ///   - tagName: Returns the display name of the repo's color tag, or `nil`
    ///              when no tag is set (used as a search haystack field).
    func apply(
        repos: [GitRepo],
        isFavorite: (String) -> Bool,
        tagRank: (String) -> Int,
        branch: (String) -> String? = { _ in nil },
        tagName: (String) -> String? = { _ in nil }
    ) -> [GitRepo] {
        let sorted = repos.sorted { a, b in
            let aFav = isFavorite(a.normalizedPath)
            let bFav = isFavorite(b.normalizedPath)
            if aFav != bFav { return aFav }

            let aTagRank = tagRank(a.normalizedPath)
            let bTagRank = tagRank(b.normalizedPath)
            if aTagRank != bTagRank { return aTagRank < bTagRank }

            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return sorted }

        return sorted.filter { repo in
            let haystacks: [String?] = [
                repo.name,
                repo.displayPath,
                repo.remoteURL,
                branch(repo.normalizedPath),
                tagName(repo.normalizedPath)
            ]
            return haystacks.contains { value in
                guard let value, !value.isEmpty else { return false }
                return value.localizedCaseInsensitiveContains(query)
            }
        }
    }
}
