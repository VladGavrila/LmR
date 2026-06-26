import Foundation
import Testing
@testable import LmRModels

@Suite("RepoDisplayNames")
struct RepoDisplayNamesTests {

    private func repo(_ path: String) -> GitRepo {
        GitRepo(name: URL(fileURLWithPath: path).lastPathComponent, url: URL(fileURLWithPath: path), parentFolder: URL(fileURLWithPath: "/tmp"))
    }

    @Test func uniqueNameStaysPlain() {
        let repos = [repo("/h1/hub/test/user"), repo("/h1/lab/test/admin")]
        let names = RepoDisplayNames.compute(for: repos)
        #expect(names[repos[0].normalizedPath] == "user")
        #expect(names[repos[1].normalizedPath] == "admin")
    }

    @Test func collidingNamesExpandUntilDistinctEvenPastSharedSegment() {
        let repos = [repo("/h1/hub/test/user"), repo("/h1/lab/test/user")]
        let names = RepoDisplayNames.compute(for: repos)
        #expect(names[repos[0].normalizedPath] == "hub/test/user")
        #expect(names[repos[1].normalizedPath] == "lab/test/user")
    }

    @Test func collidingNamesExpandOnlyAsMuchAsNeeded() {
        let repos = [repo("/cloud/ui"), repo("/device/ui")]
        let names = RepoDisplayNames.compute(for: repos)
        #expect(names[repos[0].normalizedPath] == "cloud/ui")
        #expect(names[repos[1].normalizedPath] == "device/ui")
    }

    @Test func threeWayCollisionDisambiguatesAll() {
        let repos = [repo("/a/x/repo"), repo("/b/x/repo"), repo("/c/y/repo")]
        let names = RepoDisplayNames.compute(for: repos)
        #expect(names[repos[0].normalizedPath] == "a/x/repo")
        #expect(names[repos[1].normalizedPath] == "b/x/repo")
        #expect(names[repos[2].normalizedPath] == "c/y/repo")
    }

    @Test func fallsBackToFullPathWhenStillCollidingAtMaxDepth() {
        // Pathologically identical parent chains of different lengths still resolve
        // (normalizedPath itself differs, so a final unique suffix always exists).
        let repos = [repo("/short/repo"), repo("/much/longer/path/to/repo")]
        let names = RepoDisplayNames.compute(for: repos)
        #expect(names[repos[0].normalizedPath] == "short/repo")
        #expect(names[repos[1].normalizedPath] == "to/repo")
    }
}
