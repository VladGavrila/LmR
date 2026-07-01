import AppKit

@MainActor
enum MainWindowOpener {
    static var open: (() -> Void)?
}

@MainActor
enum SettingsOpener {
    static var open: (() -> Void)?
}

@MainActor
enum UpdateCheckRequester {
    static var check: (() -> Void)?
}

@MainActor
enum NewRepoSheetRequester {
    static var present: (() -> Void)?
}

/// Bridges `AppDelegate.application(_:open:)` (Dock-icon drag-and-drop, "Open
/// With") to `ContentView`'s folder-adding logic, which needs `FoldersStore`/
/// `RepoStore` from the environment and so can't live in the delegate itself.
@MainActor
enum DockDropHandler {
    static var handle: (([URL]) -> Void)?
}

@MainActor
final class MenuBarStatusItem: NSObject {
    static let shared = MenuBarStatusItem()

    private var statusItem: NSStatusItem?

    private override init() { super.init() }

    func apply(_ presentation: AppPresentation) {
        switch presentation {
        case .dock:
            uninstall()
        case .menuBar:
            install()
        }
    }

    func refreshMenu() {
        statusItem?.menu = buildMenu()
    }

    private func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "LmR")
            image?.isTemplate = true
            button.image = image
        }
        item.menu = buildMenu()
        statusItem = item
    }

    private func uninstall() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let palette = NSMenuItem(
            title: "Open Command Palette",
            action: #selector(openPalette(_:)),
            keyEquivalent: ""
        )
        if let shortcut = KeyShortcut.menuKeyEquivalent(for: .palette) {
            palette.keyEquivalent = shortcut.key
            palette.keyEquivalentModifierMask = shortcut.mask
        }
        palette.target = self
        menu.addItem(palette)

        let mainWindow = NSMenuItem(
            title: "Show Main Window",
            action: #selector(showMainWindow(_:)),
            keyEquivalent: ""
        )
        mainWindow.target = self
        menu.addItem(mainWindow)

        menu.addItem(.separator())

        let checkForUpdates = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkForUpdates.target = self
        menu.addItem(checkForUpdates)

        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settings.keyEquivalentModifierMask = [.command]
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit LmR",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.keyEquivalentModifierMask = [.command]
        menu.addItem(quit)

        return menu
    }

    @objc private func openPalette(_ sender: Any?) {
        CommandPaletteController.shared.toggle()
    }

    @objc private func showMainWindow(_ sender: Any?) {
        MainWindowCloseGuard.surfaceMainWindow()
    }

    @objc private func openSettings(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        SettingsOpener.open?()
    }

    @objc private func checkForUpdates(_ sender: Any?) {
        // Update results (sheet, alerts) are presented by ContentView, so ensure
        // a main window is visible and the app is active before kicking off the
        // check — otherwise, triggered while LmR is in the background, nothing
        // would appear on screen.
        MainWindowCloseGuard.surfaceMainWindow()
        UpdateCheckRequester.check?()
    }
}
