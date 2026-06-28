import Foundation
import Observation

/// User-managed list of apps (IDEs, terminals, …) offered alongside the
/// always-available, built-in Finder entry. Finder itself is never stored
/// here — see `selectableApps`.
@MainActor
@Observable
final class LauncherAppsStore {
    private(set) var apps: [LauncherApp] = []

    init() {
        apps = Self.loadApps()
    }

    func add(name: String, appPath: String) {
        apps.append(LauncherApp(name: name, appPath: appPath))
        save()
    }

    func update(_ app: LauncherApp) {
        guard let idx = apps.firstIndex(where: { $0.id == app.id }) else { return }
        apps[idx] = app
        save()
    }

    func remove(id: UUID) {
        apps.removeAll { $0.id == id }
        save()
    }

    func move(app: LauncherApp, before target: LauncherApp) {
        guard app != target,
              let srcIndex = apps.firstIndex(of: app) else { return }
        apps.remove(at: srcIndex)
        guard let dstIndex = apps.firstIndex(of: target) else {
            apps.insert(app, at: srcIndex)
            return
        }
        apps.insert(app, at: dstIndex)
        save()
    }

    func moveToEnd(app: LauncherApp) {
        guard let srcIndex = apps.firstIndex(of: app) else { return }
        apps.remove(at: srcIndex)
        apps.append(app)
        save()
    }

    /// Every app a repo can open in, with the synthesized Finder entry first.
    func selectableApps() -> [LauncherApp] {
        [LauncherApp(name: LauncherApp.finderName, appPath: "")]
            + apps.filter { !$0.appPath.isEmpty }
    }

    /// Per-repo app list: like `selectableApps()`, but with the synthesized
    /// Browser entry inserted right after Finder for repos that have a web
    /// remote. Used by the repo cards/rows so the browser button appears (and
    /// disappears) in step with the repo's remote — including when a rescan
    /// gives a repo an upstream URL it didn't have before.
    func selectableApps(for repo: GitRepo) -> [LauncherApp] {
        var apps = selectableApps()
        if let browser = BrowserLauncher.app(for: repo) {
            apps.insert(browser, at: 1)
        }
        return apps
    }

    private static func loadApps() -> [LauncherApp] {
        guard let data = UserDefaults.standard.data(forKey: AppStorageKey.launcherApps.rawValue),
              let decoded = try? JSONDecoder().decode([LauncherApp].self, from: data) else { return [] }
        return decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(apps.filter { !$0.appPath.isEmpty }) else { return }
        UserDefaults.standard.set(data, forKey: AppStorageKey.launcherApps.rawValue)
    }
}
