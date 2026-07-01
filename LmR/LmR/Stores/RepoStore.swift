import Foundation
import Observation

@MainActor
@Observable
final class RepoStore {
    var repos: [GitRepo] = []
    var loadError: String?

    private let cacheURL: URL
    private var index = RepoIndex()

    init(cacheURL: URL? = nil) {
        self.cacheURL = cacheURL ?? Self.defaultCacheURL()
    }

    private static func defaultCacheURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("LmR", isDirectory: true)
        return dir.appendingPathComponent("repos.json")
    }

    func load() {
        loadError = nil
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            index = RepoIndex()
            repos = []
            return
        }
        do {
            let data = try Data(contentsOf: cacheURL)
            index = try JSONDecoder().decode(RepoIndex.self, from: data)
            repos = index.repos
        } catch {
            loadError = error.localizedDescription
        }
    }

    func rescan(folder: URL, maxDepth: Int) async {
        let found = await Task.detached {
            FolderScanner.scan(root: folder, maxDepth: maxDepth)
        }.value

        index.removeAll(under: folder)
        for repoRoot in found {
            let repo = GitRepo(
                name: repoRoot.lastPathComponent,
                url: repoRoot,
                remoteURL: Self.remoteURL(for: repoRoot),
                parentFolder: folder
            )
            index.add(repo)
        }
        repos = index.repos
        persist()
    }

    func rescanAll(folders: [String], maxDepth: Int) async {
        for path in folders {
            await rescan(folder: URL(fileURLWithPath: path), maxDepth: maxDepth)
        }
    }

    func remove(path: URL) {
        index.remove(path: path)
        repos = index.repos
        persist()
    }

    /// Drops every repo discovered under `folder`. Used when a watched folder is
    /// removed — the folder itself is never a repo, its descendants are the cards.
    func removeAll(under folder: URL) {
        index.removeAll(under: folder)
        repos = index.repos
        persist()
    }

    /// Updates the cached remote URL for the repo at `path` (e.g. after adding
    /// a repo's first remote) without a full folder rescan. No-op if `path`
    /// isn't currently indexed. Copies the existing `GitRepo` rather than
    /// constructing a fresh one, so `id` is preserved and SwiftUI doesn't
    /// remount the card.
    func updateRemoteURL(_ remoteURL: String?, forPath path: URL) {
        let target = path.standardizedFileURL.path
        guard let existing = repos.first(where: { $0.normalizedPath == target }) else { return }
        var updated = existing
        updated.remoteURL = remoteURL
        index.add(updated)
        repos = index.repos
        persist()
    }

    private static func remoteURL(for repoRoot: URL) -> String? {
        let configURL = repoRoot.appendingPathComponent(".git/config")
        guard let text = try? String(contentsOf: configURL, encoding: .utf8) else { return nil }
        guard let urlLineRange = text.range(of: "url = ") else { return nil }
        let rest = text[urlLineRange.upperBound...]
        let line = rest.prefix { $0 != "\n" && $0 != "\r" }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func persist() {
        do {
            let dir = cacheURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            let data = try JSONEncoder().encode(index)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            loadError = "Failed to save repo index: \(error.localizedDescription)"
        }
    }
}
