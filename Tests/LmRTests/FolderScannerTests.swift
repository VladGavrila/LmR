import Foundation
import Testing
@testable import LmRModels

@Suite("FolderScanner")
struct FolderScannerTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lmr-scan-test-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeRepo(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: url.appendingPathComponent(".git"), withIntermediateDirectories: true)
    }

    @Test func findsRepoAtRoot() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try makeRepo(at: root.appendingPathComponent("repoA"))

        let found = FolderScanner.scan(root: root, maxDepth: 6)
        #expect(found.map(\.lastPathComponent) == ["repoA"])
    }

    @Test func findsNestedReposAtVaryingDepths() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try makeRepo(at: root.appendingPathComponent("repoA"))
        try makeRepo(at: root.appendingPathComponent("group/repoB"))
        try makeRepo(at: root.appendingPathComponent("group/sub/repoC"))

        let found = Set(FolderScanner.scan(root: root, maxDepth: 6).map(\.lastPathComponent))
        #expect(found == ["repoA", "repoB", "repoC"])
    }

    @Test func doesNotDescendIntoFoundRepo() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = root.appendingPathComponent("repoA")
        try makeRepo(at: repo)
        // A nested ".git"-bearing directory inside the already-found repo
        // (e.g. a vendored submodule checkout) must not be reported separately.
        try makeRepo(at: repo.appendingPathComponent("nested"))

        let found = FolderScanner.scan(root: root, maxDepth: 6)
        #expect(found.count == 1)
        #expect(found[0].lastPathComponent == "repoA")
    }

    @Test func skipsNoiseDirectories() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try makeRepo(at: root.appendingPathComponent("node_modules/somePackage"))
        try makeRepo(at: root.appendingPathComponent("real"))

        let found = FolderScanner.scan(root: root, maxDepth: 6)
        #expect(found.map(\.lastPathComponent) == ["real"])
    }

    @Test func honorsDepthCap() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        // repo at depth 2 (root/a/b)
        try makeRepo(at: root.appendingPathComponent("a/b"))

        let foundShallow = FolderScanner.scan(root: root, maxDepth: 1)
        #expect(foundShallow.isEmpty)

        let foundDeep = FolderScanner.scan(root: root, maxDepth: 2)
        #expect(foundDeep.count == 1)
    }
}
