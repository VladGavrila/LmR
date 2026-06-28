import AppKit
import Foundation

/// Synthesizes the "open in the default browser" entry shown alongside the
/// configured launcher apps. The entry only exists for repos that have a web
/// remote (so the icon/button appears exactly when there's something to open),
/// and carries the user's *default browser* as its `appPath` so `AppIcon`
/// renders that browser's real logo. The action itself is special-cased by
/// `RepoOpener` on the `LauncherApp.browserName` sentinel, not by `appPath`.
enum BrowserLauncher {
    /// The browser entry for `repo`, or `nil` if the repo has no web-browsable
    /// remote (matching `RepoOpener.openRemoteInBrowser`'s guard).
    static func app(for repo: GitRepo) -> LauncherApp? {
        guard let remoteURL = repo.remoteURL,
              RemoteURLConverter.httpsURL(from: remoteURL) != nil else { return nil }
        return defaultBrowserApp()
    }

    /// The user's default `https` handler as a synthesized `LauncherApp`. Falls
    /// back to an empty `appPath` (Finder icon) only if no default browser
    /// resolves, which shouldn't happen on a normal macOS install.
    private static func defaultBrowserApp() -> LauncherApp {
        let probe = URL(string: "https://example.com")!
        let path = NSWorkspace.shared.urlForApplication(toOpen: probe)?.path ?? ""
        return LauncherApp(name: LauncherApp.browserName, appPath: path)
    }
}
