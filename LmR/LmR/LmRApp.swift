import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(AppPresentation.current.activationPolicy)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MenuBarStatusItem.shared.apply(AppPresentation.current)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        MainWindowCloseGuard.surfaceMainWindow()
        return true
    }

    /// Dropping folders onto the Dock icon routes here (also covers Finder's
    /// "Open With" on a folder).
    func application(_ application: NSApplication, open urls: [URL]) {
        DockDropHandler.handle?(urls)
    }
}

/// Intercepts the main window's close button (and ⌘W / "Close") so it hides the
/// window instead of destroying it. Closing previously quit the app, which fought
/// with the global command palette: the palette must activate the app to receive
/// keystrokes, and activating raises whatever main window exists. Hiding on close
/// lets the user tuck the window away so the palette can float alone over other
/// apps, while keeping a single window alive that the Dock icon and the menu-bar
/// item can re-surface.
final class MainWindowCloseGuard: NSObject, NSWindowDelegate {
    /// `NSWindow.delegate` is weak, so we must retain the guards ourselves.
    private static var guards: [MainWindowCloseGuard] = []
    private static weak var trackedWindow: NSWindow?

    private weak var forwardingDelegate: NSWindowDelegate?

    static func install(on window: NSWindow) {
        trackedWindow = window
        guard !(window.delegate is MainWindowCloseGuard) else { return }
        let guardDelegate = MainWindowCloseGuard()
        guardDelegate.forwardingDelegate = window.delegate
        window.delegate = guardDelegate
        guards.append(guardDelegate)
    }

    static func installOnMainWindows() {
        for window in NSApp.windows where window.canBecomeMain && !(window is CommandPalettePanel) {
            install(on: window)
        }
    }

    @MainActor
    static var mainWindow: NSWindow? {
        if let trackedWindow { return trackedWindow }
        return NSApp.windows.first { window in
            window.canBecomeMain && !(window is CommandPalettePanel)
        }
    }

    @MainActor
    static func surfaceMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let mainWindow {
            if mainWindow.isMiniaturized { mainWindow.deminiaturize(nil) }
            mainWindow.makeKeyAndOrderFront(nil)
        } else {
            MainWindowOpener.open?()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || (forwardingDelegate?.responds(to: aSelector) ?? false)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if forwardingDelegate?.responds(to: aSelector) == true {
            return forwardingDelegate
        }
        return super.forwardingTarget(for: aSelector)
    }
}

@main
struct LmRApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var repoStore = RepoStore()
    @State private var foldersStore = FoldersStore()
    @State private var launcherAppsStore = LauncherAppsStore()
    @State private var gitStatusCache = GitStatusCache()
    @State private var favoritesStore = FavoritesStore()
    @State private var tagsStore = TagsStore()
    @State private var folderWatcher: FolderWatcher?
    @State private var hotKey = GlobalHotKey()
    @State private var updater = UpdateChecker()

    @AppStorage(AppStorageKey.scanMaxDepth.rawValue) private var scanMaxDepth: Int = 6
    @AppStorage(KeyShortcut.StorageKey.enabled) private var hotKeyEnabled: Bool = true
    @AppStorage(KeyShortcut.StorageKey.keyCode) private var hotKeyCode: Int = KeyShortcut.defaultKeyCode
    @AppStorage(KeyShortcut.StorageKey.modifiers) private var hotKeyModifiers: Int = KeyShortcut.defaultModifiers

    var body: some Scene {
        Window("Launch my Repo", id: "main") {
            ContentView()
                .environment(repoStore)
                .environment(foldersStore)
                .environment(launcherAppsStore)
                .environment(gitStatusCache)
                .environment(favoritesStore)
                .environment(tagsStore)
                .environment(updater)
                .onAppear {
                    repoStore.load()
                    Task { await repoStore.rescanAll(folders: foldersStore.folders.paths, maxDepth: scanMaxDepth) }
                    startWatchingIfNeeded()
                    configurePalette()
                    hotKey.onTrigger = {
                        CommandPaletteController.shared.toggle()
                    }
                    applyHotKey()
                }
                .onChange(of: foldersStore.folders.paths) { _, paths in
                    folderWatcher?.setWatchedPaths(paths)
                }
                .onChange(of: hotKeyEnabled) { _, _ in applyHotKey() }
                .onChange(of: hotKeyCode) { _, _ in applyHotKey() }
                .onChange(of: hotKeyModifiers) { _, _ in applyHotKey() }
                .task { updater.checkAtLaunchIfNeeded() }
                .frame(minWidth: 990, maxWidth: 1320, minHeight: 390)
        }
        .defaultSize(width: 1080, height: 720)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    Task { await updater.check(userInitiated: true) }
                }
            }
            CommandGroup(after: .newItem) {
                Button("New Repository…") {
                    MainWindowCloseGuard.surfaceMainWindow()
                    NewRepoSheetRequester.present?()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(repoStore)
                .environment(foldersStore)
                .environment(launcherAppsStore)
                .environment(tagsStore)
                .environment(updater)
        }
    }

    private func startWatchingIfNeeded() {
        guard folderWatcher == nil else { return }
        let watcher = FolderWatcher { folder in
            Task { await repoStore.rescan(folder: folder, maxDepth: scanMaxDepth) }
        }
        watcher.setWatchedPaths(foldersStore.folders.paths)
        folderWatcher = watcher
    }

    private func configurePalette() {
        CommandPaletteController.shared.configure(.init(
            repoStore: repoStore,
            launcherAppsStore: launcherAppsStore,
            gitStatusCache: gitStatusCache,
            onOpen: { repo, app in
                do {
                    try RepoOpener.activate(repo, with: app)
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Could not open repo"
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
            }
        ))
    }

    private func applyHotKey() {
        let nsFlags = NSEvent.ModifierFlags(rawValue: UInt(hotKeyModifiers))
        hotKey.reconfigure(
            enabled: hotKeyEnabled,
            keyCode: UInt32(hotKeyCode),
            modifiers: KeyShortcut.carbonModifiers(from: nsFlags)
        )
        MenuBarStatusItem.shared.refreshMenu()
    }
}
