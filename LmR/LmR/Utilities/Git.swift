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

    nonisolated static func run(_ args: [String], cwd: String? = nil) -> CommandResult {
        guard FileManager.default.isExecutableFile(atPath: gitPath) else {
            return CommandResult(exitCode: -1, stdout: "", stderr: "")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = (cwd.map { ["-C", $0] } ?? []) + args
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        do {
            try process.run()
        } catch {
            return CommandResult(exitCode: -1, stdout: "", stderr: "")
        }
        let outData = (try? outPipe.fileHandleForReading.readToEnd()) ?? Data()
        let errData = (try? errPipe.fileHandleForReading.readToEnd()) ?? Data()
        process.waitUntilExit()
        return CommandResult(
            exitCode: process.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? ""
        )
    }
}
