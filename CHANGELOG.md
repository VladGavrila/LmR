# Changelog

All notable changes to **LmR** ("Launch my Repo") are documented here, newest first.

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

[1.0.0]: https://github.com/VladGavrila/LmR/releases/tag/v1.0.0
