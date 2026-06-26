import Foundation
import Testing
@testable import LmRModels

private func repo(_ name: String, remote: String? = nil) -> GitRepo {
    GitRepo(name: name, url: URL(fileURLWithPath: "/tmp/\(name)"), remoteURL: remote, parentFolder: URL(fileURLWithPath: "/tmp"))
}

@Suite("RepoSearchScorer")
struct RepoSearchScorerTests {

    @Test func exactNameMatchScoresHighest() {
        #expect(RepoSearchScorer.score(repo: repo("LmR"), query: "lmr") == 1000)
    }

    @Test func namePrefixScoresAbovePrefixThreshold() {
        let score = RepoSearchScorer.score(repo: repo("LmRCore"), query: "lmr")
        #expect(score >= 500 && score < 1000)
    }

    @Test func nameContainsScoresOneHundred() {
        #expect(RepoSearchScorer.score(repo: repo("my-lmr-fork"), query: "lmr") == 100)
    }

    @Test func otherFieldMatchScoresTen() {
        let r = repo("sshCM", remote: "git@github.com:vlad/sshCM.git")
        #expect(RepoSearchScorer.score(repo: r, query: "vlad") == 10)
    }

    @Test func branchMatchScoresTen() {
        #expect(RepoSearchScorer.score(repo: repo("LmR"), query: "feature", branch: "feature/palette") == 10)
    }

    @Test func noMatchScoresZero() {
        #expect(RepoSearchScorer.score(repo: repo("LmR"), query: "zzz") == 0)
    }

    @Test func emptyQueryScoresZero() {
        #expect(RepoSearchScorer.score(repo: repo("LmR"), query: "") == 0)
    }

    @Test func orderingFavorsHigherTiers() {
        let exact = RepoSearchScorer.score(repo: repo("lmr"), query: "lmr")
        let prefix = RepoSearchScorer.score(repo: repo("lmrcore"), query: "lmr")
        let contains = RepoSearchScorer.score(repo: repo("my-lmr"), query: "lmr")
        #expect(exact > prefix)
        #expect(prefix > contains)
    }
}
