import Foundation
import Testing
@testable import LmRModels

@Suite("ClonePathPlanner")
struct ClonePathPlannerTests {

    private let root = URL(fileURLWithPath: "/Users/dev/src")

    @Test func canonicalNestedExample() {
        let plan = ClonePathPlanner.plan(remoteURL: "https://gitlab.com/org/module/part/repo.git", into: root)
        #expect(plan?.parentDirectory.path == "/Users/dev/src/org/module/part")
        #expect(plan?.repoFolderName == "repo")
        #expect(plan?.destination.path == "/Users/dev/src/org/module/part/repo")
    }

    @Test func singleSegment() {
        let plan = ClonePathPlanner.plan(remoteURL: "https://github.com/repo.git", into: root)
        #expect(plan?.parentDirectory.path == "/Users/dev/src")
        #expect(plan?.repoFolderName == "repo")
        #expect(plan?.destination.path == "/Users/dev/src/repo")
    }

    @Test func scpShorthand() {
        let plan = ClonePathPlanner.plan(remoteURL: "git@github.com:owner/repo.git", into: root)
        #expect(plan?.parentDirectory.path == "/Users/dev/src/owner")
        #expect(plan?.repoFolderName == "repo")
        #expect(plan?.destination.path == "/Users/dev/src/owner/repo")
    }

    @Test func trailingSlashAndNoGitSuffix() {
        let plan = ClonePathPlanner.plan(remoteURL: "https://github.com/owner/repo/", into: root)
        #expect(plan?.repoFolderName == "repo")
        #expect(plan?.parentDirectory.path == "/Users/dev/src/owner")
    }

    @Test func deepNesting() {
        let plan = ClonePathPlanner.plan(remoteURL: "https://example.com/a/b/c/d/e/repo.git", into: root)
        #expect(plan?.parentDirectory.path == "/Users/dev/src/a/b/c/d/e")
        #expect(plan?.repoFolderName == "repo")
    }

    @Test func excludesHostFromDerivedPath() {
        let plan = ClonePathPlanner.plan(remoteURL: "https://gitlab.com/org/repo.git", into: root)
        #expect(plan?.destination.path.contains("gitlab.com") == false)
    }

    @Test func nilForLocalPathRemote() {
        #expect(ClonePathPlanner.plan(remoteURL: "/Users/dev/somewhere/repo", into: root) == nil)
    }

    @Test func nilForUnparseableGarbage() {
        #expect(ClonePathPlanner.plan(remoteURL: "not a url at all", into: root) == nil)
    }

    @Test func nilForEmptyString() {
        #expect(ClonePathPlanner.plan(remoteURL: "", into: root) == nil)
    }
}
