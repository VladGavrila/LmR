import Foundation
import Observation

enum CloneState: Equatable {
    case idle, cloning, done(URL), error(String)
}

/// Clones a remote into a destination derived by `ClonePathPlanner`. The clone
/// *source* is always the original pasted URL (so SSH/scp remotes clone over
/// SSH) — only the destination directory is derived.
@MainActor
@Observable
final class GitCloner {
    var state: CloneState = .idle

    func clone(remoteURL: String, plan: ClonePlan) async {
        state = .cloning

        if FileManager.default.fileExists(atPath: plan.destination.path) {
            let contents = try? FileManager.default.contentsOfDirectory(atPath: plan.destination.path)
            if contents == nil || !(contents?.isEmpty ?? true) {
                state = .error("\"\(plan.destination.lastPathComponent)\" already exists at the destination.")
                return
            }
        }

        do {
            try FileManager.default.createDirectory(at: plan.parentDirectory, withIntermediateDirectories: true)
        } catch {
            state = .error("Couldn't create \(plan.parentDirectory.path): \(error.localizedDescription)")
            return
        }

        let destination = plan.destination
        let result = await Task.detached(priority: .utility) {
            Git.run(["clone", "--progress", remoteURL, destination.path])
        }.value

        guard !Task.isCancelled else { return }

        if result.exitCode == 0 {
            state = .done(destination)
        } else {
            let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            state = .error(message.isEmpty ? "git clone failed (exit code \(result.exitCode))." : message)
        }
    }

    func reset() {
        state = .idle
    }
}
