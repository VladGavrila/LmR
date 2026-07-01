import Foundation
import Testing
@testable import LmRUtilities

/// Reproduces thread-pool starvation in `Git.runProcess`: many concurrent
/// invocations each blocking a `DispatchQueue.global(qos: .utility)` worker
/// thread on `DispatchGroup.wait()` while *also* dispatching their pipe reads
/// onto that same bounded pool can exhaust it — every thread ends up waiting
/// on read-jobs that have no free thread left to run on. This is exactly what
/// happens in the real app when `GitStatusCache.clear()` fires and every repo
/// in a folder gets re-probed at once (e.g. after creating a new local repo).
/// A single-call test can't catch this; it only manifests under concurrent load.
@Suite("Git.runProcess – concurrent invocations")
struct GitProcessConcurrencyTests {

    @Test func manyConcurrentInvocationsAllComplete() async {
        let concurrency = 40
        let results = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<concurrency {
                group.addTask {
                    let result = await Git.runProcess(executable: "/bin/sh", arguments: ["-c", "printf ok"])
                    return result.stdout == "ok" && result.exitCode == 0
                }
            }
            var successes: [Bool] = []
            for await success in group {
                successes.append(success)
            }
            return successes
        }
        #expect(results.count == concurrency)
        #expect(results.allSatisfy { $0 })
    }
}
