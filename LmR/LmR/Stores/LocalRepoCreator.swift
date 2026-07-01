import Foundation
import Observation

enum CreateRepoState: Equatable {
    case idle, creating, done(URL), error(String)
}

/// Creates a brand-new local repo via `git init` at a destination derived by
/// `NewRepoPathPlanner`. Deliberately not merged with `GitCloner` — cloning
/// and initializing are different operations with different guards.
@MainActor
@Observable
final class LocalRepoCreator {
    var state: CreateRepoState = .idle

    func create(at destination: URL) async {
        state = .creating

        // Mirrors GitCloner's guard exactly rather than allowing `git init`
        // into an existing non-empty non-repo folder — simpler, and avoids
        // silently repo-ifying a folder the user didn't intend to.
        if FileManager.default.fileExists(atPath: destination.path) {
            let contents = try? FileManager.default.contentsOfDirectory(atPath: destination.path)
            if contents == nil || !(contents?.isEmpty ?? true) {
                state = .error("\"\(destination.lastPathComponent)\" already exists at the destination.")
                return
            }
        }

        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        } catch {
            state = .error("Couldn't create \(destination.path): \(error.localizedDescription)")
            return
        }

        let result = await Task.detached(priority: .utility) {
            await Git.run(["init", destination.path])
        }.value

        guard !Task.isCancelled else { return }

        if result.exitCode == 0 {
            state = .done(destination)
        } else {
            let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            state = .error(message.isEmpty ? "git init failed (exit code \(result.exitCode))." : message)
        }
    }

    func reset() {
        state = .idle
    }
}
