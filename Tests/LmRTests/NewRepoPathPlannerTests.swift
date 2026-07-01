import Foundation
import Testing
@testable import LmRModels

@Suite("NewRepoPathPlanner")
struct NewRepoPathPlannerTests {

    private let root = URL(fileURLWithPath: "/Users/dev/src")

    @Test func ordinaryName() {
        let destination = NewRepoPathPlanner.plan(name: "repo", into: root)
        #expect(destination?.path == "/Users/dev/src/repo")
    }

    @Test func nameContainingLiteralDotIsNotRejected() {
        #expect(NewRepoPathPlanner.plan(name: "my.project", into: root)?.path == "/Users/dev/src/my.project")
        #expect(NewRepoPathPlanner.plan(name: ".dotfiles", into: root)?.path == "/Users/dev/src/.dotfiles")
    }

    @Test func trimsLeadingAndTrailingWhitespace() {
        #expect(NewRepoPathPlanner.plan(name: "  repo  ", into: root)?.path == "/Users/dev/src/repo")
    }

    @Test func nilForEmptyString() {
        #expect(NewRepoPathPlanner.plan(name: "", into: root) == nil)
    }

    @Test func nilForWhitespaceOnly() {
        #expect(NewRepoPathPlanner.plan(name: "   ", into: root) == nil)
    }

    @Test func nilForSingleDot() {
        #expect(NewRepoPathPlanner.plan(name: ".", into: root) == nil)
    }

    @Test func nilForDoubleDot() {
        #expect(NewRepoPathPlanner.plan(name: "..", into: root) == nil)
    }

    @Test func nilForNameContainingSlash() {
        #expect(NewRepoPathPlanner.plan(name: "org/repo", into: root) == nil)
    }
}
