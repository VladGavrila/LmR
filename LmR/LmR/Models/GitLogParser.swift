import Foundation

/// Pure, testable parsing of `git log`/`git branch`/`git remote -v` output for
/// the repo detail panel. Process invocation lives in `RepoDetailLoader`.
enum GitLogParser {
    /// Parses `git log -n 20 --format=%h␞%s␞%cr␞%cn` output (one commit per
    /// line, fields separated by `\u{1f}`). Lines with the wrong field count
    /// are skipped rather than failing the whole parse.
    static func parseLog(_ output: String) -> [CommitSummary] {
        output.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
            let parts = line.split(separator: "\u{1f}", omittingEmptySubsequences: false)
            guard parts.count == 4 else { return nil }
            return CommitSummary(
                shortHash: String(parts[0]),
                subject: String(parts[1]),
                relativeDate: String(parts[2]),
                authorName: String(parts[3])
            )
        }
    }

    /// Parses `git branch --format=%(refname:short)` output into branch names.
    static func parseBranches(_ output: String) -> [String] {
        output.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Parses `git remote -v` output (`"<name>\t<url> (fetch|push)"`, two lines
    /// per remote). Dedupes by name, keeping the first occurrence.
    static func parseRemotes(_ output: String) -> [RemoteInfo] {
        var seenNames = Set<String>()
        var remotes: [RemoteInfo] = []
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let fields = trimmed.split(separator: "\t")
            guard fields.count == 2 else { continue }
            let name = String(fields[0])
            guard let url = fields[1].split(separator: " ").first.map(String.init),
                  !name.isEmpty, !url.isEmpty, !seenNames.contains(name) else { continue }
            seenNames.insert(name)
            remotes.append(RemoteInfo(name: name, url: url))
        }
        return remotes
    }
}

struct CommitSummary: Equatable, Hashable {
    let shortHash: String
    let subject: String
    let relativeDate: String
    let authorName: String
}

struct RemoteInfo: Equatable, Hashable {
    let name: String
    let url: String
}
