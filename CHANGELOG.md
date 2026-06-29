# Changelog

All notable changes to **LmR** ("Launch my Repo") are documented here, newest first.

## [1.2.0] — 2026-06-28

- **Drag a folder onto the window to add it.** Drop one or more folders anywhere on the main window, onto the empty-state placeholder, or onto the Dock icon, to add each as a watched root and scan it immediately, without opening Settings.
- **Clone a repo from a URL.** Paste a remote URL, pick an existing watched folder or "Choose another folder…" (which also lets you create a new one), and clone — the destination directory is derived from the URL's path (e.g. `org/module/part/repo`), while the clone itself still uses the original URL so SSH/scp remotes work as expected. A newly chosen folder is added as a watched root automatically. Available from a toolbar button and the File menu ("Clone Repository…", `⌘N`).
- **Repo detail panel.** An info button on each card (and "Show Details…" in the context menu on cards and rows) opens a sheet with the repo's status, recent commits, branches, remotes, and a rendered README.

## [1.1.0] — 2026-06-28

- **Open in browser button.** Repos with a web remote now show a browser button — the default browser's icon, right after Finder — on every card and list row, opening the repo's origin on the web (clicking the repo title still works too). It appears and disappears automatically as a repo gains or loses an upstream remote. In the command palette the same action is available via `⌘B` and in each repo's "Open in…" submenu.

## [1.0.0] — 2026-06-25

LmR ("Launch my Repo") is a native macOS dashboard for your local git repositories.

- **Repo dashboard.** Point LmR at one or more folders; it scans them recursively for git repos and shows each as a card or compact list row, switchable from the toolbar.
- **Instant filter.** Just start typing in the main window to filter repos by name, path, remote URL, branch, or tag. A status bar shows the live count.
- **Open anywhere.** Open a repo in Finder or any configured app (IDEs, terminals) from clickable icons on each card/row, with a default open action.
- **Live git status.** Branch, clean/dirty state, ahead/behind counts, and the last commit's subject + date, probed in the background and refreshable from the toolbar.
- **Live folder watching.** New repos appear and deleted ones disappear automatically — no manual refresh needed.
- **Open remotes on the web.** Click a repo's title to open its origin in the browser, with ssh/scp remotes converted to `https://`.
- **Command palette.** A global hotkey opens a floating search panel over any app to filter and launch a repo.
- **Favorites, tags & colors.** Star repos to pin them, and group them with 7 color tags — renamable, reorderable, and filterable.
- **Dock or menu bar.** Run with a Dock icon or as a menu-bar-only accessory app.
- **Self-updating.** Checks GitHub for new releases and installs them in place.

[1.2.0]: https://github.com/VladGavrila/LmR/releases/tag/v1.2.0
[1.1.0]: https://github.com/VladGavrila/LmR/releases/tag/v1.1.0
[1.0.0]: https://github.com/VladGavrila/LmR/releases/tag/v1.0.0
