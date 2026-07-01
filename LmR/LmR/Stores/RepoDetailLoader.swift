import Foundation
import Observation

/// On-demand loader for the repo detail sheet: recent commits, branches,
/// remotes, and the README — fetched once per sheet presentation rather than
/// kept warm like `GitStatusCache`.
@MainActor
@Observable
final class RepoDetailLoader {
    private(set) var commits: [CommitSummary] = []
    private(set) var branches: [String] = []
    private(set) var remotes: [RemoteInfo] = []
    private(set) var readmeText: String?
    private(set) var isLoading: Bool = false

    func load(for repo: GitRepo) async {
        isLoading = true
        let path = repo.normalizedPath

        let result = await Task.detached(priority: .utility) {
            await Self.fetch(path: path)
        }.value

        guard !Task.isCancelled else { return }
        commits = result.commits
        branches = result.branches
        remotes = result.remotes
        readmeText = result.readme
        isLoading = false
    }

    private struct FetchResult {
        let commits: [CommitSummary]
        let branches: [String]
        let remotes: [RemoteInfo]
        let readme: String?
    }

    nonisolated private static func fetch(path: String) async -> FetchResult {
        let logOutput = await Git.run(["log", "-n", "20", "--format=%h\u{1f}%s\u{1f}%cr\u{1f}%cn"], cwd: path)
        let branchOutput = await Git.run(["branch", "--format=%(refname:short)"], cwd: path)
        let remoteOutput = await Git.run(["remote", "-v"], cwd: path)

        return FetchResult(
            commits: GitLogParser.parseLog(logOutput.stdout),
            branches: GitLogParser.parseBranches(branchOutput.stdout),
            remotes: GitLogParser.parseRemotes(remoteOutput.stdout),
            readme: readReadme(at: path)
        )
    }

    /// Locates `README.md` / `README` / `README.txt` case-insensitively in the
    /// repo root. Known limit (per plan #9): images/tables in the README won't
    /// render via `MarkdownView` — acceptable for a quick preview.
    nonisolated private static func readReadme(at path: String) -> String? {
        let candidates = ["readme.md", "readme", "readme.txt"]
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: path),
              let match = entries.first(where: { candidates.contains($0.lowercased()) }) else { return nil }
        let fileURL = URL(fileURLWithPath: path).appendingPathComponent(match)
        return try? String(contentsOf: fileURL, encoding: .utf8)
    }
}
