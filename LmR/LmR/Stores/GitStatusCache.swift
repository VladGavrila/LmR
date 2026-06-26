import Foundation
import Observation

enum GitState: Equatable {
    case unknown, checking, clean, dirty, error
}

struct GitStatusInfo: Equatable {
    var branch: String?
    var isDirty: Bool = false
    var ahead: Int = 0
    var behind: Int = 0
    var lastCommitSubject: String?
    var lastCommitRelativeDate: String?
    var lastCommitAbsoluteDate: String?
    var lastCommitAuthorName: String?
    var state: GitState = .unknown
}

@MainActor
@Observable
final class GitStatusCache {
    private var statuses: [String: GitStatusInfo] = [:]
    private(set) var epoch: Int = 0

    func status(for path: String) -> GitStatusInfo {
        statuses[path] ?? GitStatusInfo()
    }

    func branch(for path: String) -> String? {
        statuses[path]?.branch
    }

    /// Wipes all cached state and bumps the epoch, so the next probe fleet
    /// re-checks every repo instead of skipping ones with a cached value.
    func clear() {
        statuses.removeAll()
        epoch &+= 1
    }

    /// Runs all `git` probes for `repo` off the main actor, then writes the
    /// combined result back on the main actor. Skips repos that already have
    /// a value for the current epoch (mirrors sshCM's de-dup).
    func runProbe(for repo: GitRepo) async {
        let path = repo.normalizedPath
        guard statuses[path] == nil else { return }
        statuses[path] = GitStatusInfo(state: .checking)

        let result = await Task.detached(priority: .utility) {
            Self.probe(path: path)
        }.value

        guard !Task.isCancelled else { return }
        statuses[path] = result
    }

    nonisolated private static func probe(path: String) -> GitStatusInfo {
        let branchOutput = run(["rev-parse", "--abbrev-ref", "HEAD"], cwd: path)
        var branch = GitStatusParser.parseBranch(branchOutput.stdout)
        if branch == nil, branchOutput.exitCode == 0 {
            let shaOutput = run(["rev-parse", "--short", "HEAD"], cwd: path)
            branch = GitStatusParser.parseDetachedHead(shaOutput.stdout)
        }
        guard branchOutput.exitCode == 0 else {
            return GitStatusInfo(state: .error)
        }

        let porcelain = run(["status", "--porcelain"], cwd: path)
        let isDirty = GitStatusParser.parseDirty(porcelain.stdout)

        let aheadBehindOutput = run(["rev-list", "--left-right", "--count", "@{upstream}...HEAD"], cwd: path)
        let aheadBehind = GitStatusParser.parseAheadBehind(aheadBehindOutput.stdout)

        let lastCommitOutput = run(["log", "-1", "--date=format:%Y-%m-%d %H:%M", "--format=%s\u{1f}%cr\u{1f}%cd\u{1f}%cn"], cwd: path)
        let lastCommit = GitStatusParser.parseLastCommit(lastCommitOutput.stdout)

        return GitStatusInfo(
            branch: branch,
            isDirty: isDirty,
            ahead: aheadBehind?.ahead ?? 0,
            behind: aheadBehind?.behind ?? 0,
            lastCommitSubject: lastCommit?.subject,
            lastCommitRelativeDate: lastCommit?.relativeDate,
            lastCommitAbsoluteDate: lastCommit?.absoluteDate,
            lastCommitAuthorName: lastCommit?.authorName,
            state: isDirty ? .dirty : .clean
        )
    }

    // MARK: - Process helper

    private struct CommandResult {
        let exitCode: Int32
        let stdout: String
    }

    nonisolated private static let gitPath = "/usr/bin/git"

    nonisolated private static func run(_ args: [String], cwd: String) -> CommandResult {
        guard FileManager.default.isExecutableFile(atPath: gitPath) else {
            return CommandResult(exitCode: -1, stdout: "")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = ["-C", cwd] + args
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return CommandResult(exitCode: -1, stdout: "")
        }
        let outData = (try? outPipe.fileHandleForReading.readToEnd()) ?? Data()
        process.waitUntilExit()
        return CommandResult(
            exitCode: process.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? ""
        )
    }
}
