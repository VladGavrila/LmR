import Foundation

/// Pure, testable parsing of `git` CLI output. Process invocation lives in
/// `GitStatusCache` — this type only turns raw strings into typed values.
enum GitStatusParser {
    /// Parses `git rev-parse --abbrev-ref HEAD` output. Returns `nil` when
    /// detached (output is the literal "HEAD"); use `parseDetachedHead` with
    /// `git rev-parse --short HEAD` output to get a short SHA in that case.
    static func parseBranch(_ output: String) -> String? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "HEAD" else { return nil }
        return trimmed
    }

    /// Parses `git rev-parse --short HEAD` output for the detached-HEAD case.
    static func parseDetachedHead(_ output: String) -> String? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// `true` when `git status --porcelain` reports any non-empty line.
    static func parseDirty(_ porcelain: String) -> Bool {
        porcelain.split(separator: "\n").contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Parses `git rev-list --left-right --count @{upstream}...HEAD` output
    /// of the form `"<behind>\t<ahead>"`. `nil` when there is no upstream
    /// (the command fails) or the output doesn't match the expected shape.
    static func parseAheadBehind(_ output: String) -> (ahead: Int, behind: Int)? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let fields = trimmed.split(whereSeparator: { $0 == "\t" || $0 == " " })
        guard fields.count == 2,
              let behind = Int(fields[0]),
              let ahead = Int(fields[1]) else { return nil }
        return (ahead: ahead, behind: behind)
    }

    /// Parses `git log -1 --format=%s%x1f%cr%x1f%cd%x1f%cn` output (subject,
    /// relative date, absolute date, committer name — each separated by
    /// `\u{1f}`). `nil` for an empty repo.
    static func parseLastCommit(_ output: String) -> (subject: String, relativeDate: String, absoluteDate: String, authorName: String)? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: "\u{1f}", maxSplits: 3, omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        return (subject: String(parts[0]), relativeDate: String(parts[1]), absoluteDate: String(parts[2]), authorName: String(parts[3]))
    }
}
