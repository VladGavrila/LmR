import Foundation
import Observation
#if canImport(LmRModels)
@testable import LmRModels
#endif
#if canImport(LmRUtilities)
@testable import LmRUtilities
#endif

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
    private let probe: @Sendable (String) async -> GitStatusInfo

    /// `probe` is injectable so tests can substitute a fake, controllable probe
    /// instead of shelling out to `git` — defaults to the real implementation.
    init(probe: @escaping @Sendable (String) async -> GitStatusInfo = { path in await GitStatusCache.defaultProbe(path: path) }) {
        self.probe = probe
    }

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
    ///
    /// The caller (`ContentView`) spawns one unstructured `Task` per repo, so
    /// a `clear()` (e.g. Refresh) doesn't cancel probes already in flight —
    /// they keep running and would otherwise land after, and clobber, a
    /// fresher probe for the same repo. Capturing the epoch at start and
    /// checking it again before the write-back makes a stale probe's result a
    /// no-op instead.
    func runProbe(for repo: GitRepo) async {
        let path = repo.normalizedPath
        guard statuses[path] == nil else { return }
        statuses[path] = GitStatusInfo(state: .checking)

        let startEpoch = epoch
        let probeFn = probe
        let result = await Task.detached(priority: .utility) {
            await probeFn(path)
        }.value

        guard !Task.isCancelled, epoch == startEpoch else { return }
        statuses[path] = result
    }

    nonisolated static func defaultProbe(path: String) async -> GitStatusInfo {
        // `git rev-parse --abbrev-ref HEAD` fails (non-zero exit) on a repo
        // with zero commits ("unborn branch"), which used to make this whole
        // probe report `.error` for a freshly-created/cloned-but-empty repo
        // instead of a clean, commit-less one. `symbolic-ref` resolves the
        // branch name for both a normal and an unborn HEAD, and only fails
        // (as intended) when HEAD is detached — that failure is what drives
        // the short-SHA fallback below, not overall probe success.
        let branchOutput = await Git.run(["symbolic-ref", "--short", "-q", "HEAD"], cwd: path)
        var branch = GitStatusParser.parseBranch(branchOutput.stdout)
        if branch == nil {
            let shaOutput = await Git.run(["rev-parse", "--short", "HEAD"], cwd: path)
            branch = GitStatusParser.parseDetachedHead(shaOutput.stdout)
        }

        let porcelain = await Git.run(["status", "--porcelain"], cwd: path)
        guard porcelain.exitCode == 0 else {
            return GitStatusInfo(state: .error)
        }
        let isDirty = GitStatusParser.parseDirty(porcelain.stdout)

        let aheadBehindOutput = await Git.run(["rev-list", "--left-right", "--count", "@{upstream}...HEAD"], cwd: path)
        let aheadBehind = GitStatusParser.parseAheadBehind(aheadBehindOutput.stdout)

        let lastCommitOutput = await Git.run(["log", "-1", "--date=format:%Y-%m-%d %H:%M", "--format=%s\u{1f}%cr\u{1f}%cd\u{1f}%cn"], cwd: path)
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
}
