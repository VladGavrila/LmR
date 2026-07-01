import Foundation
import Observation

enum AddRemoteState: Equatable {
    case idle, saving, error(String)
}

/// Adds a remote to a repo that doesn't have one yet (e.g. one just created
/// locally via `LocalRepoCreator`). Only handles adding — editing/replacing
/// an existing remote is a separate, deferred feature.
@MainActor
@Observable
final class RemoteAdder {
    var state: AddRemoteState = .idle

    @discardableResult
    func addRemote(name: String, url: String, at path: String) async -> Bool {
        state = .saving

        let result = await Task.detached(priority: .utility) {
            await Git.run(["remote", "add", name, url], cwd: path)
        }.value

        guard !Task.isCancelled else { return false }

        if result.exitCode == 0 {
            state = .idle
            return true
        }
        let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        state = .error(message.isEmpty ? "git remote add failed (exit code \(result.exitCode))." : message)
        return false
    }

    func reset() {
        state = .idle
    }
}
