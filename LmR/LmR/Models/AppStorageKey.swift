import Foundation

/// Central registry of every UserDefaults / @AppStorage key used in the app.
/// Using typed enum cases instead of scattered string literals prevents typos
/// from silently creating separate, always-empty keys and losing persisted data.
enum AppStorageKey: String, CaseIterable {
    // MARK: - FoldersStore
    case watchedFolders

    // MARK: - LauncherAppsStore
    case launcherApps

    // MARK: - ContentView / RepoOpener
    case defaultOpenAction
    case reposViewMode

    // MARK: - RepoStore / FolderScanner
    case scanMaxDepth

    // MARK: - KeyShortcut (palette global hotkey)
    case paletteHotKeyEnabled
    case paletteHotKeyKeyCode
    case paletteHotKeyModifiers
    case paletteHotKeyDisplay

    // MARK: - App presentation (AppPresentation)
    case appPresentation

    // MARK: - FavoritesStore
    case favoriteRepos

    // MARK: - TagsStore
    case repoTags
    case repoTagOrder
    case repoTagNames

    // MARK: - UpdateChecker
    case autoCheckForUpdates
    case updateLastCheck
    case skippedUpdateVersion
}
