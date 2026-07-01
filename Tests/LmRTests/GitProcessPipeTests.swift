import Foundation
import Testing
@testable import LmRUtilities

/// Reproduces the `Process`/`Pipe` deadlock in `Git.runProcess`: reading stdout
/// to EOF before starting to read stderr can hang forever if the child fills
/// stderr's OS pipe buffer (64KB) while nothing is draining it — the child
/// blocks inside its own `write()`, so it never closes stdout either. Real
/// `git clone --progress` output can hit this on a large clone. This uses
/// `/bin/sh` instead of `git` so the reproduction is deterministic and
/// hermetic (no network, no real repo needed).
@Suite("Git.runProcess – concurrent pipe draining")
struct GitProcessPipeTests {

    @Test func drainsLargeStderrWithoutDeadlockingOnStdout() async {
        // Writes well past any realistic OS pipe buffer size to stderr *before*
        // writing anything to stdout, then a small marker to stdout.
        let script = "head -c 2000000 /dev/zero 1>&2; printf done"
        let result = await Git.runProcess(executable: "/bin/sh", arguments: ["-c", script])

        #expect(result.exitCode == 0)
        #expect(result.stdout == "done")
        #expect(result.stderr.utf8.count == 2_000_000)
    }
}
