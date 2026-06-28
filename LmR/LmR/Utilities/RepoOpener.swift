import AppKit
import Foundation

/// Central "open this repo" gate shared by the main window and (later) the
/// command palette.
enum RepoOpener {
    /// Opens the repo's own folder in Finder (not just selecting it inside its parent).
    static func revealInFinder(_ repo: GitRepo) {
        NSWorkspace.shared.open(repo.url)
    }

    /// Opens the repo's remote origin in the default browser, converting ssh/scp-like
    /// remotes to `https://` first. No-op if there's no remote or it has no web host.
    static func openRemoteInBrowser(_ repo: GitRepo) {
        guard let remoteURL = repo.remoteURL, let httpsURL = RemoteURLConverter.httpsURL(from: remoteURL) else { return }
        NSWorkspace.shared.open(httpsURL)
    }

    /// Single dispatch point for activating any entry in a repo's app list,
    /// including the two synthesized entries (Finder, Browser). Use this from
    /// the UI/palette so the browser entry "just works" like a configured app.
    static func activate(_ repo: GitRepo, with app: LauncherApp) throws {
        switch app.name {
        case LauncherApp.browserName:
            openRemoteInBrowser(repo)
        case LauncherApp.finderName:
            revealInFinder(repo)
        default:
            try open(repo, with: app)
        }
    }

    /// Opens the repo's folder with `app` via `NSWorkspace`. Terminal apps
    /// (Terminal, iTerm, …) already `cd` into a folder handed to them this
    /// way, so no special-casing is needed.
    static func open(_ repo: GitRepo, with app: LauncherApp) throws {
        guard !app.appPath.isEmpty else {
            revealInFinder(repo)
            return
        }
        let appURL = URL(fileURLWithPath: app.appPath)
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw RepoOpenError.appNotFound(app.appPath)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([repo.url], withApplicationAt: appURL, configuration: configuration) { _, error in
            if let error {
                NSLog("RepoOpener failed: \(error.localizedDescription)")
            }
        }
    }
}

enum RepoOpenError: LocalizedError {
    case appNotFound(String)

    var errorDescription: String? {
        switch self {
        case .appNotFound(let path):
            return "Application not found at \(path)."
        }
    }
}
