import Foundation
import Testing
@testable import LmRModels

private func noFav(_: String) -> Bool { false }
private func flatRank(_: String) -> Int { 0 }

private func repo(_ name: String, remote: String? = nil) -> GitRepo {
    GitRepo(name: name, url: URL(fileURLWithPath: "/tmp/\(name)"), remoteURL: remote, parentFolder: URL(fileURLWithPath: "/tmp"))
}

@Suite("RepoListFilter – sorting")
struct RepoListFilterSortingTests {

    @Test func alphabeticalSort() {
        let repos = [repo("charlie"), repo("alice"), repo("bob")]
        let result = RepoListFilter().apply(repos: repos, isFavorite: noFav, tagRank: flatRank)
        #expect(result.map(\.name) == ["alice", "bob", "charlie"])
    }

    @Test func favoritesSortFirst() {
        let repos = [repo("zeta"), repo("alpha")]
        let result = RepoListFilter().apply(
            repos: repos,
            isFavorite: { $0.contains("zeta") },
            tagRank: flatRank
        )
        #expect(result.first?.name == "zeta")
    }

    @Test func tagRankOrdersBeforeName() {
        let repos = [repo("zeta"), repo("alpha")]
        let result = RepoListFilter().apply(
            repos: repos,
            isFavorite: noFav,
            tagRank: { $0.contains("zeta") ? 0 : 1 }
        )
        #expect(result.first?.name == "zeta")
    }

    @Test func favoritesOutrankTags() {
        let repos = [repo("zeta"), repo("alpha")]
        let result = RepoListFilter().apply(
            repos: repos,
            isFavorite: { $0.contains("alpha") },
            tagRank: { $0.contains("zeta") ? 0 : 1 }
        )
        #expect(result.first?.name == "alpha")
    }
}

@Suite("RepoListFilter – search")
struct RepoListFilterSearchTests {

    @Test func emptyQueryReturnsAll() {
        let repos = [repo("prod"), repo("staging")]
        let result = RepoListFilter(searchText: "  ").apply(repos: repos, isFavorite: noFav, tagRank: flatRank)
        #expect(result.count == 2)
    }

    @Test func searchMatchesName() {
        let repos = [repo("prod-api"), repo("staging-api")]
        let result = RepoListFilter(searchText: "prod").apply(repos: repos, isFavorite: noFav, tagRank: flatRank)
        #expect(result.map(\.name) == ["prod-api"])
    }

    @Test func searchMatchesRemoteURL() {
        let repos = [repo("a", remote: "git@github.com:foo/bar.git"), repo("b", remote: "git@github.com:other/baz.git")]
        let result = RepoListFilter(searchText: "foo/bar").apply(repos: repos, isFavorite: noFav, tagRank: flatRank)
        #expect(result.map(\.name) == ["a"])
    }

    @Test func searchIsCaseInsensitive() {
        let repos = [repo("MyRepo")]
        let result = RepoListFilter(searchText: "myrepo").apply(repos: repos, isFavorite: noFav, tagRank: flatRank)
        #expect(result.count == 1)
    }

    @Test func noMatchReturnsEmpty() {
        let repos = [repo("alpha"), repo("beta")]
        let result = RepoListFilter(searchText: "zzz").apply(repos: repos, isFavorite: noFav, tagRank: flatRank)
        #expect(result.isEmpty)
    }

    @Test func searchMatchesTagName() {
        let repos = [repo("prod-api"), repo("staging-api")]
        let result = RepoListFilter(searchText: "urgent").apply(
            repos: repos,
            isFavorite: noFav,
            tagRank: flatRank,
            tagName: { $0.contains("prod") ? "Urgent" : nil }
        )
        #expect(result.map(\.name) == ["prod-api"])
    }
}
