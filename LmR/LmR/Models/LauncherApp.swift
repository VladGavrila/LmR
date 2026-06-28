import Foundation

/// One entry in the user-configurable "open in app" list offered per repo.
/// Finder is always available and is represented as a synthesized instance
/// rather than being stored in the list — see `LauncherAppsStore`.
nonisolated struct LauncherApp: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var appPath: String

    init(id: UUID = UUID(), name: String, appPath: String) {
        self.id = id
        self.name = name
        self.appPath = appPath
    }

    static let finderName = "Finder"

    /// Sentinel name for the synthesized "open the repo's remote in the default
    /// browser" entry. Like Finder, it is never stored in the user's app list —
    /// it's built per-repo (only when the repo has a web remote) by
    /// `BrowserLauncher` and routed specially by `RepoOpener`.
    static let browserName = "Browser"
}
