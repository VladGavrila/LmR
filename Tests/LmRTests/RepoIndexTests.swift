import Foundation
import Testing
@testable import LmRModels

@Suite("RepoIndex")
struct RepoIndexTests {

    private func repo(_ path: String) -> GitRepo {
        GitRepo(name: URL(fileURLWithPath: path).lastPathComponent, url: URL(fileURLWithPath: path), parentFolder: URL(fileURLWithPath: "/tmp"))
    }

    @Test func addAndContains() {
        var index = RepoIndex()
        index.add(repo("/tmp/a"))
        #expect(index.contains(path: URL(fileURLWithPath: "/tmp/a")))
        #expect(!index.contains(path: URL(fileURLWithPath: "/tmp/b")))
    }

    @Test func dedupeByPathReplacesExisting() {
        var index = RepoIndex()
        index.add(repo("/tmp/a"))
        let updated = GitRepo(name: "a", url: URL(fileURLWithPath: "/tmp/a"), remoteURL: "origin", parentFolder: URL(fileURLWithPath: "/tmp"))
        index.add(updated)
        #expect(index.repos.count == 1)
        #expect(index.repos[0].remoteURL == "origin")
    }

    @Test func remove() {
        var index = RepoIndex()
        index.add(repo("/tmp/a"))
        index.add(repo("/tmp/b"))
        index.remove(path: URL(fileURLWithPath: "/tmp/a"))
        #expect(index.repos.count == 1)
        #expect(index.repos[0].name == "b")
    }

    @Test func removeAllUnderFolder() {
        var index = RepoIndex()
        index.add(GitRepo(name: "a", url: URL(fileURLWithPath: "/root1/a"), parentFolder: URL(fileURLWithPath: "/root1")))
        index.add(GitRepo(name: "b", url: URL(fileURLWithPath: "/root2/b"), parentFolder: URL(fileURLWithPath: "/root2")))
        index.removeAll(under: URL(fileURLWithPath: "/root1"))
        #expect(index.repos.map(\.name) == ["b"])
    }

    @Test func codableRoundTrip() throws {
        var index = RepoIndex()
        index.add(repo("/tmp/a"))
        let data = try JSONEncoder().encode(index)
        let decoded = try JSONDecoder().decode(RepoIndex.self, from: data)
        #expect(decoded.repos.count == 1)
        #expect(decoded.repos[0].name == "a")
    }
}
