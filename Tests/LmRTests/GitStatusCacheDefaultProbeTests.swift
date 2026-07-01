import Foundation
import Testing
@testable import LmRStores
@testable import LmRUtilities

/// `defaultProbe` is `GitStatusCache`'s real, non-fake probe — it shells out
/// to `git` against an actual repo on disk, so these tests use a real,
/// hermetic `git init`'d temp directory rather than the injectable fake used
/// elsewhere.
@Suite("GitStatusCache.defaultProbe – zero-commit repo")
struct GitStatusCacheDefaultProbeTests {

    private func makeEmptyRepo() async throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lmr-defaultprobe-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        _ = await Git.run(["init", dir.path])
        return dir
    }

    @Test func zeroCommitRepoReportsCleanNotError() async throws {
        // `git rev-parse --abbrev-ref HEAD` fails (exit 128) on a repo with no
        // commits yet ("unborn branch"), which previously made defaultProbe
        // bail out with `.error` before it ever got to `git status
        // --porcelain` — so a freshly `git init`'d repo showed as an error
        // instead of "No commits yet", regardless of what GitStatusBadge does
        // with a clean/dirty state.
        let repo = try await makeEmptyRepo()
        defer { try? FileManager.default.removeItem(at: repo) }

        let status = await GitStatusCache.defaultProbe(path: repo.path)

        #expect(status.state == .clean)
        #expect(status.lastCommitSubject == nil)
        // Branch name depends on the environment's `init.defaultBranch`
        // config — just confirm it resolved to *something*, not nil.
        #expect(status.branch != nil)
    }
}
