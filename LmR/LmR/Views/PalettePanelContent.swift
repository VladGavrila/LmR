import SwiftUI

struct PalettePanelContent: View {
    let onOpen: (GitRepo, LauncherApp) -> Void
    let onClose: () -> Void

    @Environment(RepoStore.self) private var repoStore
    @Environment(LauncherAppsStore.self) private var launcherAppsStore

    @AppStorage(AppStorageKey.defaultOpenAction.rawValue) private var defaultOpenAction: String = "finder"

    var body: some View {
        CommandPaletteView(
            repos: sortedRepos,
            apps: launcherAppsStore.selectableApps(),
            defaultApp: defaultApp,
            onOpen: onOpen,
            onClose: onClose
        )
    }

    private var sortedRepos: [GitRepo] {
        repoStore.repos.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var defaultApp: LauncherApp {
        let apps = launcherAppsStore.selectableApps()
        return apps.first { $0.id.uuidString == defaultOpenAction }
            ?? apps.first { $0.name == LauncherApp.finderName }
            ?? LauncherApp(name: LauncherApp.finderName, appPath: "")
    }
}
