import Foundation
import Testing
@testable import LmRModels

@Suite("GitLogParser – log")
struct GitLogParserLogTests {

    @Test func parsesWellFormedMultiLineLog() {
        let output = "a1b2c3d\u{1f}Fix bug\u{1f}2 days ago\u{1f}Jane Doe\nb2c3d4e\u{1f}Add feature\u{1f}5 days ago\u{1f}John Smith\n"
        let commits = GitLogParser.parseLog(output)
        #expect(commits.count == 2)
        #expect(commits[0] == CommitSummary(shortHash: "a1b2c3d", subject: "Fix bug", relativeDate: "2 days ago", authorName: "Jane Doe"))
        #expect(commits[1] == CommitSummary(shortHash: "b2c3d4e", subject: "Add feature", relativeDate: "5 days ago", authorName: "John Smith"))
    }

    @Test func emptyOutputReturnsEmptyArray() {
        #expect(GitLogParser.parseLog("") == [])
    }

    @Test func skipsLinesWithMissingOrEmptyFields() {
        let output = "a1b2c3d\u{1f}Fix bug\u{1f}2 days ago\nb2c3d4e\u{1f}\u{1f}5 days ago\u{1f}John Smith\n"
        let commits = GitLogParser.parseLog(output)
        #expect(commits.count == 1)
        #expect(commits[0] == CommitSummary(shortHash: "b2c3d4e", subject: "", relativeDate: "5 days ago", authorName: "John Smith"))
    }

    @Test func parsesUnicodeSubjects() {
        let output = "a1b2c3d\u{1f}修复错误 🎉\u{1f}1 hour ago\u{1f}José\n"
        let commits = GitLogParser.parseLog(output)
        #expect(commits == [CommitSummary(shortHash: "a1b2c3d", subject: "修复错误 🎉", relativeDate: "1 hour ago", authorName: "José")])
    }
}

@Suite("GitLogParser – branches")
struct GitLogParserBranchesTests {

    @Test func parsesMultipleBranches() {
        #expect(GitLogParser.parseBranches("main\nfeature/foo\n") == ["main", "feature/foo"])
    }

    @Test func emptyOutputReturnsEmptyArray() {
        #expect(GitLogParser.parseBranches("") == [])
    }

    @Test func skipsBlankLines() {
        #expect(GitLogParser.parseBranches("main\n\n  \nfeature/foo\n") == ["main", "feature/foo"])
    }
}

@Suite("GitLogParser – remotes")
struct GitLogParserRemotesTests {

    @Test func parsesFetchAndPushDedupingByName() {
        let output = "origin\thttps://github.com/owner/repo.git (fetch)\norigin\thttps://github.com/owner/repo.git (push)\n"
        #expect(GitLogParser.parseRemotes(output) == [RemoteInfo(name: "origin", url: "https://github.com/owner/repo.git")])
    }

    @Test func parsesMultipleRemotes() {
        let output = "origin\thttps://github.com/owner/repo.git (fetch)\nupstream\thttps://github.com/other/repo.git (fetch)\n"
        #expect(GitLogParser.parseRemotes(output) == [
            RemoteInfo(name: "origin", url: "https://github.com/owner/repo.git"),
            RemoteInfo(name: "upstream", url: "https://github.com/other/repo.git"),
        ])
    }

    @Test func emptyOutputReturnsEmptyArray() {
        #expect(GitLogParser.parseRemotes("") == [])
    }

    @Test func skipsMalformedLines() {
        #expect(GitLogParser.parseRemotes("not a remote line\n") == [])
    }
}
