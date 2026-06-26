import Foundation
import Testing
@testable import LmRModels

@Suite("GitStatusParser – branch")
struct GitStatusParserBranchTests {

    @Test func parsesNormalBranch() {
        #expect(GitStatusParser.parseBranch("main\n") == "main")
    }

    @Test func detachedHeadReturnsNil() {
        #expect(GitStatusParser.parseBranch("HEAD\n") == nil)
    }

    @Test func emptyOutputReturnsNil() {
        #expect(GitStatusParser.parseBranch("") == nil)
    }

    @Test func parsesDetachedHeadShortSHA() {
        #expect(GitStatusParser.parseDetachedHead("a1b2c3d\n") == "a1b2c3d")
    }
}

@Suite("GitStatusParser – dirty")
struct GitStatusParserDirtyTests {

    @Test func emptyPorcelainIsClean() {
        #expect(GitStatusParser.parseDirty("") == false)
    }

    @Test func whitespaceOnlyPorcelainIsClean() {
        #expect(GitStatusParser.parseDirty("\n  \n") == false)
    }

    @Test func nonEmptyPorcelainIsDirty() {
        #expect(GitStatusParser.parseDirty(" M Sources/Foo.swift\n") == true)
    }
}

@Suite("GitStatusParser – ahead/behind")
struct GitStatusParserAheadBehindTests {

    @Test func parsesAheadAndBehind() {
        let result = GitStatusParser.parseAheadBehind("2\t3\n")
        #expect(result?.ahead == 3)
        #expect(result?.behind == 2)
    }

    @Test func noUpstreamReturnsNil() {
        #expect(GitStatusParser.parseAheadBehind("") == nil)
    }

    @Test func malformedOutputReturnsNil() {
        #expect(GitStatusParser.parseAheadBehind("not-a-number\n") == nil)
    }
}

@Suite("GitStatusParser – last commit")
struct GitStatusParserLastCommitTests {

    @Test func parsesSubjectRelativeDateAbsoluteDateAndAuthor() {
        let result = GitStatusParser.parseLastCommit("Fix crash\u{1f}2 days ago\u{1f}2026-06-20 10:15\u{1f}Jane Doe\n")
        #expect(result?.subject == "Fix crash")
        #expect(result?.relativeDate == "2 days ago")
        #expect(result?.absoluteDate == "2026-06-20 10:15")
        #expect(result?.authorName == "Jane Doe")
    }

    @Test func emptyOutputReturnsNil() {
        #expect(GitStatusParser.parseLastCommit("") == nil)
    }

    @Test func missingSeparatorReturnsNil() {
        #expect(GitStatusParser.parseLastCommit("no separator here") == nil)
    }
}
