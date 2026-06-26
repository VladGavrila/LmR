# AGENTS.md — LmR

Guidance for AI agents (and humans) maintaining and extending this repository.

## What this is

**LmR** ("Launch my Repo") is a native macOS app, that presents the user's local git repositories as a searchable card/list dashboard. The user picks one or more top-level folders; LmR scans them recursively for `.git` roots and shows every repo as a card, filterable as-you-type, openable in Finder or any number of user-configured apps (IDEs, terminals).

- Bundle ID: `com.vgdev.lmr` · Display name: "Launch my Repo"
- Min OS: **macOS 15.0** · Swift 6.0 (Package.swift) · Apple Silicon only

## Repository layout

```
LmR/                        ← repo root
├── README.md                ← user-facing description
├── AGENTS.md / CLAUDE.md     ← this file (CLAUDE.md is a symlink to AGENTS.md)
├── CHANGELOG.md              ← user-visible changes, newest first
├── Package.swift             ← SPM targets wrapping the pure Foundation-only model/utility layers
├── Tests/LmRTests/           ← Swift Testing suite for those layers
├── scripts/                  ← build-release.sh + ExportOptions.plist (sign/notarize/export)
└── LmR/                       ← the Xcode project lives one level down
    ├── LmR.xcodeproj          ← project (scheme: LmR)
    └── LmR/                   ← all Swift source
        ├── LmRApp.swift        ← @main App, AppDelegate, environment wiring
        ├── ContentView.swift   ← main window: grid/list, search, probe orchestration
        ├── Models/             ← pure data + parsing (no UI, mostly no AppKit) — in LmRModels SPM target
        ├── Stores/             ← @Observable state holders (the "view models")
        ├── Utilities/          ← side-effecting helpers (open-in-app, FSEvents, git Process calls)
        └── Views/              ← SwiftUI views
```

Note the **double `LmR/LmR/`** nesting: the project file is at `LmR/LmR.xcodeproj`, sources are at `LmR/LmR/`. Paths in build commands must account for this.

## Architecture

### Data model

- `Models/GitRepo.swift` — one discovered repo: `id`, `name`, `url`, `remoteURL?`, `parentFolder`. `normalizedPath` (standardized absolute path) is the dedupe/identity key used everywhere a repo needs to be looked up by location; `displayPath` is the home-relative form shown in the UI.
- `Models/RepoIndex.swift` — the JSON-codable container persisted to `~/Library/Application Support/LmR/repos.json`; dedupes by `normalizedPath`, supports `removeAll(under:)` so a folder rescan can fully replace its contents.
- `Models/FolderScanner.swift` — pure, testable recursive traversal: stops descending at the first `.git` it finds, honors a depth cap, skips noise directories (`node_modules`, `.build`, `DerivedData`, `Pods`, `vendor`, `.git`).
- `Models/WatchedFolders.swift` — pure dedupe/normalize logic for the watched-root list; `FoldersStore` adds `UserDefaults` persistence on top.
- `Models/RepoListFilter.swift` — pure sort/filter for the dashboard. Favorites and tag-rank are accepted as closures (stubbed to constants until phase 4 wires real stores); the search haystack is name, display path, remote URL, and (since phase 2) the cached branch name via another injected closure.
- `Models/GitStatusParser.swift` — pure parsing of `git` CLI output (branch / detached HEAD, dirty porcelain, ahead/behind, last commit subject + relative date). Process invocation lives in `GitStatusCache`, not here — keep that split so this stays unit-testable.
- `Models/RemoteURLConverter.swift` — pure conversion of a `git remote.origin.url` value (scp shorthand, `ssh://`, `git://`, `http(s)://`) into the `https://` URL for browsing it on the web; host-agnostic (GitHub, GitLab, Bitbucket, self-hosted, …), returns `nil` for remotes with no web host (e.g. a local path).
- `Models/RepoDisplayNames.swift` — pure disambiguation for repos that share a folder name: groups by `name`, then expands each colliding group's displayed suffix (e.g. `hub/test/user` vs `lab/test/user`) by parent-path components, uniformly within the group, until every member is distinct.
- `Models/LauncherApp.swift` / `Models/AppStorageKey.swift` — a user-configured "open with" app, and the central registry of every `UserDefaults`/`@AppStorage` key.
- `Models/RepoTag.swift` — the 7-color tag enum a repo can be assigned in card view (color, display name, default sort order). Depends on SwiftUI's `Color`, so it's **not** part of the Foundation-only `LmRModels` SPM target; verify it by building/running.

### State: `@Observable` stores (the "view models")

Stores live in `Stores/`, are `@MainActor @Observable final class`, instantiated once in `LmRApp` as `@State`, and injected via `.environment(...)`. Views read them with `@Environment(StoreType.self)`.

| Store | Responsibility | Persistence |
|---|---|---|
| `RepoStore` | Scan folders, own the repo list, persist the index | `~/Library/Application Support/LmR/repos.json` |
| `FoldersStore` | Watched root folder paths | `UserDefaults: watchedFolders` |
| `LauncherAppsStore` | User-configured "open in" apps | `UserDefaults: launcherApps` |
| `GitStatusCache` | Per-repo git branch/dirty/ahead-behind/last-commit, keyed by `normalizedPath` | in-memory only (epoch-based invalidation) |
| `FavoritesStore` | Set of favorited repo paths (card view only) | `UserDefaults: favoriteRepos` |
| `TagsStore` | Per-repo color tag, tag sort order, custom tag names (card view only) | `UserDefaults: repoTags` / `repoTagOrder` / `repoTagNames` |
| `UpdateChecker` | Polls GitHub releases, drives the download/install state machine | `UserDefaults: autoCheckForUpdates` / `updateLastCheck` / `skippedUpdateVersion` |

`RepoStore.rescan(folder:maxDepth:)` is the single mutation point for a folder's contents: it removes every indexed repo under that root and re-adds whatever `FolderScanner` finds, so both manual re-index and FSEvents-triggered rescans get auto-add *and* prune for free.

### Key utilities (`Utilities/`)

- **`RepoOpener`** — single entry point for "open this repo": Finder (`NSWorkspace.shared.open`) or a configured app (`NSWorkspace.open(_:withApplicationAt:)`). Will be shared by the main window and the future command palette (phase 3) — go through this, not `NSWorkspace` directly.
- **`GitStatusCache`** (in `Stores/`, not `Utilities/`, but the Process-invocation rules below apply) — runs `git -C <path> ...` via `Process`, `nonisolated` + `Task.detached(priority: .utility)`, writing results back on the main actor: a tiny synchronous `run(_:cwd:)` helper wrapping `Process`, called from inside the detached task.
- **`FolderWatcher`** — one `FSEventStream` per watched root (CoreServices), 0.5s debounce, calls back into `RepoStore.rescan(folder:)`. Each stream's C callback receives the watched root path via a small `StreamBox` passed through `FSEventStreamContext.info` (the callback itself can't capture a Swift closure). Started/torn down from `LmRApp` (`onAppear` / `onChange(of: foldersStore.folders.paths)`).
- **`AppIcon`** — resolves an app icon image for `LauncherApp` rows/cards.
- **`SemanticVersion`** — pure, Comparable major.minor.patch parsing (`v`/`V` prefix, `-pre`/`+build` suffixes stripped); in the Foundation-only `LmRUtilities` SPM target alongside its tests.
- **`UpdateChecker`** — polls `api.github.com/repos/VladGavrila/LmR/releases` for the newest published release shipping an asset named exactly `LmR.zip`, streams the download with progress, and is the single `State` machine (`idle`/`checking`/`upToDate`/`available`/`downloading`/`installing`/`error`) the Updates UI renders.
- **`AppInstaller`** — given a downloaded zip: extracts via `ditto`, verifies codesign + bundle id (`com.vgdev.lmr`), then hands off to a detached `install.sh` that waits for this process to quit, swaps the bundle, and relaunches.

### Notable UI pieces (`Views/`)

- `ContentView` — owns search (`searchText`, with a type-ahead `NSEvent` monitor that captures keystrokes into the filter), grid vs list mode, the git-status probe orchestration (`probeFleetKey` task), the Refresh button (rescans folders *and* clears `GitStatusCache` to force re-probing), and the update-available sheet/alerts driven by `UpdateChecker.state`.
- `RepoCardView` / `RepoRowView` — the two repo presentations; both take the same `onReveal`/`onOpenIn` closures. **Card-only features stay card-only**: `GitStatusBadge`'s ahead/behind counts are gated by a `showsAheadBehind` flag that only `RepoCardView` sets — keep new card-only features (favorites, tags) behind the same kind of flag rather than duplicating logic into `RepoRowView`. The last-commit subject line is the deliberate exception — it's shown unconditionally in both, with a `.help` tooltip (exact date + committer name) on hover.
- `GitStatusBadge` — dot (colored by `GitState`) + branch label, with a pulsing-while-checking animation.
- `SettingsView` — the `Settings` scene: Folders tab (watched roots, max scan depth, per-folder re-index/remove), Apps tab (configured "open with" apps, default action), Tags tab, and Updates tab (current version, last-check time, auto-check toggle, manual check button).
- `UpdateAvailableSheet` + `MarkdownView` — the update sheet renders the (possibly multi-version) release notes through a small hand-rolled Markdown renderer (headings/paragraphs/lists/code blocks/rules) rather than pulling in a dependency.

## Building & running

There is **no CI config in-repo.** Building the app requires **full Xcode** (not just Command Line Tools); the pure model layer can be tested with just `swift test`.

### Debug build (what you build/run while iterating)

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project LmR/LmR.xcodeproj -scheme LmR -configuration Debug \
  -derivedDataPath .build/DerivedData -destination 'generic/platform=macOS' \
  build CODE_SIGNING_ALLOWED=NO
```

Output lands at `.build/DerivedData/Build/Products/Debug/LmR.app`.

### Running a freshly built copy

macOS won't launch a second instance with the same bundle ID. Stop any prior copy first:
```bash
pkill -x LmR 2>/dev/null
open .build/DerivedData/Build/Products/Debug/LmR.app
```

> **SourceKit caveat:** in-editor "Cannot find type X in scope" diagnostics are often spurious (files analyzed without module context). Trust the `xcodebuild` result, not isolated diagnostics.

## Testing

`Package.swift` at the repo root compiles the pure, Foundation-only files under `LmR/LmR/Models/` and `LmR/LmR/Utilities/` (explicitly listed in the `LmRModels`/`LmRUtilities` targets' `sources`) into library targets; `Tests/LmRTests/` covers them with `@testable import LmRModels`/`LmRUtilities`.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test   # from repo root
```

- **Run the suite before making changes** to confirm your starting point is green, and **again after** to confirm nothing broke — it's well under a second, no excuse to skip either side.
- **Add or update tests for any new/changed functionality in a file already listed in `Package.swift`** (currently: `AppStorageKey`, `GitRepo`, `RepoIndex`, `FolderScanner`, `RepoListFilter`, `LauncherApp`, `WatchedFolders`, `GitStatusParser`, `RemoteURLConverter`, `RepoDisplayNames`, `RepoSearchScorer`, `SemanticVersion`). Follow the existing per-type `@Suite`/`@Test` structure in `Tests/LmRTests/`.
- If a new pure, Foundation-only file is added to `Models/` or `Utilities/` and deserves coverage, add it to the relevant target's `sources` list in `Package.swift` first.
- Files that depend on AppKit/SwiftUI/CoreServices/Process/Network (`Stores/`, most of `Utilities/`, all of `Views/`) aren't part of the SPM package and can't be unit tested this way — verify those by building and running the app, per the section above. For git-status / folder-watching changes specifically, a quick non-GUI sanity check is to watch `~/Library/Application Support/LmR/repos.json` while you `git init` / `rm -rf` a repo under a watched folder. `UpdateChecker`/`AppInstaller` (network, codesign, subprocess) are verified manually against a real test release, not unit-tested.
- A new `AppStorageKey` case should get a corresponding assertion in `AppStorageKeyTests.swift` (a loud-failure-on-unannounced-change pattern).

## Release process

1. Bump `MARKETING_VERSION` (and `CURRENT_PROJECT_VERSION` if needed) in the project — or pass `BUNDLE_SHORT_VERSION` / `BUNDLE_VERSION` env vars to the build script.
2. Update CHANGELOG.md (this becomes the GitHub release body, rendered in-app by `MarkdownView`).
3. Run `scripts/build-release.sh` **with signing/notarization env vars** set: `DEVELOPER_ID_CERT_BASE64`, `DEVELOPER_ID_CERT_PASSWORD`, `NOTARIZE_APPLE_ID`, `NOTARIZE_TEAM_ID`, `NOTARIZE_APP_PASSWORD` (team defaults to `2RZL73M634`). It imports the cert into a temporary keychain, archives with `--timestamp --options=runtime`, exports developer-id, notarizes (`notarytool --wait`), and staples — producing `dist/LmR.app` + `dist/LmR.zip`.
4. Create the GitHub release tagged `vX.Y.Z` with `LmR.zip` attached as an asset named exactly **`LmR.zip`** (the updater looks for that name). Tag must parse as a semver (`SemanticVersion`).

## Keeping CHANGELOG.md current

**Every user-visible change must be reflected in `CHANGELOG.md`.** This includes follow-up fixes/tweaks made within the same conversation — don't leave the entry describing behavior that's since changed; update it in place rather than appending a near-duplicate bullet.

- Before adding or amending an entry, **ask the user which version this work belongs to** (a new release, or a fix folded into the version still in progress) — don't guess or default to bumping automatically.
- If the user names a new version, bump `MARKETING_VERSION` in `LmR/LmR.xcodeproj/project.pbxproj` (both build configurations) to match, and add a new `## [X.Y.Z] — <date>` section at the top of the file.
- If the work folds into the version already at the top of the file, edit that section's existing bullets directly so they describe the current behavior.

## Conventions & gotchas

- **Swift style:** `@MainActor @Observable final class` for stores; `enum` namespaces for stateless utilities (`RepoOpener`, `GitStatusParser`); `nonisolated` + `Task.detached` for blocking subprocess/IO work off the main actor (`GitStatusCache.probe`, `RepoStore`'s scan). Match the surrounding file's comment density — comment the *why* (hidden constraints, subtle invariants), not the *what*.
- **`RepoListFilter`'s closures are a deliberate seam.** Favorites/tag-rank/branch are injected as `(String) -> T` closures keyed by `normalizedPath` rather than the filter depending on the concrete stores, so it stays pure and testable. Add new filterable fields the same way.
- **Card-view-only features stay card-only** (per `plans/OVERVIEW.md`): favorites, tags/colors, and `GitStatusBadge`'s rich info are gated by a flag/parameter rather than rendered unconditionally — `RepoRowView` stays compact.
- **`UserDefaults` keys are an informal API**, centralized in `AppStorageKey` — don't introduce a raw string literal for a new key, and don't rename an existing case without checking `AppStorageKeyTests.swift`.
- **App is not sandboxed** and shells out to `/usr/bin/git` via `Process` — keep that in mind before assuming sandbox-style file access restrictions apply.
- **Automated tests exist for the pure model layer only** (see Testing above). For `Stores/`/`Utilities/`/`Views/` changes, verify by building and running the app, exercising the affected flow — and prefer a non-GUI check (watching `repos.json`, shelling out to `git` directly to compare against parser expectations) when GUI automation access isn't available.
