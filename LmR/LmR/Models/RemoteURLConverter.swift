import Foundation

/// Converts a `git remote.origin.url` value (ssh shorthand, `ssh://`, `git://`,
/// or already-`https://`) into the `https://` URL for browsing that remote on
/// the web. Returns `nil` for anything without a recognizable host (e.g. a
/// local filesystem remote).
enum RemoteURLConverter {
    static func httpsURL(from remoteURL: String) -> URL? {
        let trimmed = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let scpURL = httpsURLFromSCPLikeSyntax(trimmed) {
            return scpURL
        }

        guard var components = URLComponents(string: trimmed), let scheme = components.scheme?.lowercased() else { return nil }
        switch scheme {
        case "https", "http", "ssh", "git":
            components.scheme = "https"
            components.user = nil
            components.password = nil
            components.port = nil
            components.path = stripGitSuffix(components.path)
            return components.url
        default:
            return nil
        }
    }

    /// Handles the scp-like shorthand `[user@]host:path` (no `scheme://`), e.g.
    /// `git@github.com:owner/repo.git`.
    private static func httpsURLFromSCPLikeSyntax(_ string: String) -> URL? {
        guard !string.contains("://") else { return nil }
        guard let atIndex = string.firstIndex(of: "@") else { return nil }
        let afterAt = string[string.index(after: atIndex)...]
        guard let colonIndex = afterAt.firstIndex(of: ":") else { return nil }
        let host = afterAt[..<colonIndex]
        let path = afterAt[afterAt.index(after: colonIndex)...]
        guard !host.isEmpty, !path.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = String(host)
        components.path = "/" + stripGitSuffix(String(path))
        return components.url
    }

    private static func stripGitSuffix(_ path: String) -> String {
        path.hasSuffix(".git") ? String(path.dropLast(4)) : path
    }
}
