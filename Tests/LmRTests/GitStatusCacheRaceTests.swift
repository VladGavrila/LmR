import Foundation
import Testing
@testable import LmRModels
@testable import LmRStores

/// Reproduces the Refresh-button race: `ContentView` spawns a new, unstructured
/// `Task` per repo to call `runProbe`, so an older probe that was still in
/// flight when `GitStatusCache.clear()` bumped the epoch (e.g. the user hit
/// Refresh, or `CloneRepoSheet` cleared the cache after a clone finished) is
/// never cancelled — it keeps running and, without an epoch check, its stale
/// result can land *after* a fresh probe for the same repo and clobber it.
@Suite("GitStatusCache – stale probe race")
@MainActor
struct GitStatusCacheRaceTests {

    private final class CallCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        func increment() -> Int {
            lock.lock()
            defer { lock.unlock() }
            count += 1
            return count
        }
    }

    /// `DispatchSemaphore.wait` is unavailable from `async` contexts (blocking
    /// the cooperative thread pool is dangerous), so bridge it via a plain
    /// background queue instead of calling it directly from the test body.
    private func wait(_ semaphore: DispatchSemaphore, timeout: DispatchTime) async -> DispatchTimeoutResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: semaphore.wait(timeout: timeout))
            }
        }
    }

    @Test func staleProbeStartedBeforeClearDoesNotOverwriteFreshResultAfterClear() async {
        let repo = GitRepo(
            name: "demo",
            url: URL(fileURLWithPath: "/tmp/demo"),
            parentFolder: URL(fileURLWithPath: "/tmp")
        )

        let firstProbeStarted = DispatchSemaphore(value: 0)
        let releaseFirstProbe = DispatchSemaphore(value: 0)
        let counter = CallCounter()

        let cache = GitStatusCache(probe: { [self] path async in
            if counter.increment() == 1 {
                // Simulate a slow first probe (e.g. a `git` subprocess call
                // that's still running when Refresh is pressed).
                firstProbeStarted.signal()
                _ = await wait(releaseFirstProbe, timeout: .now() + 2)
                return GitStatusInfo(branch: "stale", state: .clean)
            }
            return GitStatusInfo(branch: "fresh", state: .clean)
        })

        let staleProbeTask = Task { await cache.runProbe(for: repo) }
        #expect(await wait(firstProbeStarted, timeout: .now() + 2) == .success)

        // Simulate hitting Refresh while the first probe is still in flight.
        cache.clear()

        // A fresh probe for the same repo, started after the clear, completes
        // first — this is what a re-triggered `.task(id: probeFleetKey)`
        // would kick off.
        await cache.runProbe(for: repo)
        #expect(cache.status(for: repo.normalizedPath).branch == "fresh")

        // Now let the stale probe (started *before* the clear) finish and
        // write back. Its result must not clobber the fresher one.
        releaseFirstProbe.signal()
        await staleProbeTask.value

        #expect(cache.status(for: repo.normalizedPath).branch == "fresh")
    }
}
