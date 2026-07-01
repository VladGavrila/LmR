import Foundation

/// Shared `/usr/bin/git` `Process` invocation, used by every store that shells
/// out to git (`GitStatusCache`'s probes, `GitCloner`'s clone) so the Process
/// plumbing exists in exactly one place.
enum Git {
    struct CommandResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    private static let gitPath = "/usr/bin/git"

    nonisolated static func run(_ args: [String], cwd: String? = nil) async -> CommandResult {
        guard FileManager.default.isExecutableFile(atPath: gitPath) else {
            return CommandResult(exitCode: -1, stdout: "", stderr: "")
        }
        return await runProcess(executable: gitPath, arguments: (cwd.map { ["-C", $0] } ?? []) + args)
    }

    /// Not `private` so tests can exercise the pipe-draining behavior directly
    /// against an arbitrary executable, without needing `git` itself.
    nonisolated static func runProcess(executable: String, arguments: [String]) async -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        do {
            try process.run()
        } catch {
            return CommandResult(exitCode: -1, stdout: "", stderr: "")
        }

        // Drain both pipes concurrently via genuine async child tasks (not a
        // blocking DispatchGroup.wait()). Reading one to EOF before starting
        // the other can deadlock: if the child fills the *other* stream's OS
        // pipe buffer (64KB) while nothing is draining it, the child blocks
        // inside its own write() call and never reaches EOF on the stream
        // we're waiting on either — `git clone --progress`'s frequent stderr
        // updates hit exactly this on a large clone. A prior fix used
        // DispatchGroup.wait() to run the two reads concurrently, but that
        // blocks a DispatchQueue.global(qos: .utility) thread while *also*
        // dispatching the reads onto that same bounded pool — with enough
        // concurrent probes (e.g. every repo in a folder re-probed at once
        // after GitStatusCache.clear()), every pool thread ends up parked in
        // .wait() and none are left free to run the queued reads, hanging
        // every in-flight probe. async let suspends instead of blocking a
        // thread, so it doesn't compete with itself under load.
        async let outData = Self.readToEnd(outPipe)
        async let errData = Self.readToEnd(errPipe)
        let (out, err) = await (outData, errData)
        process.waitUntilExit()

        return CommandResult(
            exitCode: process.terminationStatus,
            stdout: String(data: out, encoding: .utf8) ?? "",
            stderr: String(data: err, encoding: .utf8) ?? ""
        )
    }

    nonisolated private static func readToEnd(_ pipe: Pipe) async -> Data {
        await Task.detached(priority: .utility) {
            (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
        }.value
    }
}
