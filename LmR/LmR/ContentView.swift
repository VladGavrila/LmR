import SwiftUI
import AppKit

enum ReposViewMode: String {
    case card, list
}

struct ContentView: View {
    @Environment(RepoStore.self) private var store
    @Environment(FoldersStore.self) private var foldersStore
    @Environment(LauncherAppsStore.self) private var launcherAppsStore
    @Environment(GitStatusCache.self) private var gitStatusCache
    @Environment(FavoritesStore.self) private var favoritesStore
    @Environment(TagsStore.self) private var tagsStore
    @Environment(UpdateChecker.self) private var updater

    @AppStorage(AppStorageKey.scanMaxDepth.rawValue) private var scanMaxDepth: Int = 6
    @AppStorage(AppStorageKey.reposViewMode.rawValue) private var viewModeRaw: String = ReposViewMode.card.rawValue

    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    @State private var searchText: String = ""
    @State private var openError: String?
    @State private var typeAheadMonitor: Any?
    @State private var repoPendingRemoval: GitRepo?
    @State private var tagFilter: RepoTag?
    @State private var presentedRelease: UpdateChecker.Release?

    private var viewMode: ReposViewMode {
        ReposViewMode(rawValue: viewModeRaw) ?? .card
    }

    var body: some View {
        baseView
            .alert(
                "Could not open repo",
                isPresented: Binding(get: { openError != nil }, set: { if !$0 { openError = nil } }),
                presenting: openError
            ) { _ in
                Button("OK") { openError = nil }
            } message: { msg in
                Text(msg)
            }
            .alert(
                "Error",
                isPresented: Binding(get: { store.loadError != nil }, set: { if !$0 { store.loadError = nil } }),
                presenting: store.loadError
            ) { _ in
                Button("OK") { store.loadError = nil }
            } message: { msg in
                Text(msg)
            }
            .sheet(item: $presentedRelease, onDismiss: {
                if case .downloading = updater.state {
                    updater.cancelDownload()
                }
                updater.dismissTransient()
            }) { release in
                @Bindable var binding = updater
                UpdateAvailableSheet(checker: binding, release: release)
            }
            .alert("No update available", isPresented: standaloneInfoBinding) {
                Button("OK") { updater.dismissTransient() }
            } message: {
                Text("LmR \(updater.currentVersionString) is the latest version.")
            }
            .alert("Update check failed", isPresented: standaloneErrorBinding) {
                Button("OK") { updater.dismissTransient() }
            } message: {
                if case .error(let msg) = updater.state {
                    Text(msg)
                }
            }
            .onChange(of: updateStateMarker) { _, _ in
                syncPresentedRelease()
            }
            .onAppear {
                let open = openWindow
                MainWindowOpener.open = { open(id: "main") }
                let openSettingsAction = openSettings
                SettingsOpener.open = { openSettingsAction() }
                UpdateCheckRequester.check = { Task { await updater.check(userInitiated: true) } }
                installTypeAheadMonitor()
                DispatchQueue.main.async { MainWindowCloseGuard.installOnMainWindows() }
                syncPresentedRelease()
            }
            .onDisappear { removeTypeAheadMonitor() }
            .task(id: probeFleetKey) {
                let snapshot = store.repos
                for repo in snapshot {
                    Task { await gitStatusCache.runProbe(for: repo) }
                }
            }
    }

    private var updateStateMarker: Int {
        switch updater.state {
        case .idle: return 0
        case .checking: return 1
        case .upToDate: return 2
        case .available(let r): return 3 &+ r.tag.hashValue
        case .downloading: return 4
        case .installing: return 5
        case .error(let m): return 6 &+ m.hashValue
        }
    }

    private func syncPresentedRelease() {
        switch updater.state {
        case .available(let release):
            if presentedRelease?.tag != release.tag {
                presentedRelease = release
            }
        case .upToDate, .idle:
            presentedRelease = nil
        case .checking, .downloading, .installing, .error:
            break
        }
    }

    private var standaloneInfoBinding: Binding<Bool> {
        Binding(
            get: { presentedRelease == nil && { if case .upToDate = updater.state { return true }; return false }() },
            set: { if !$0 { updater.dismissTransient() } }
        )
    }

    private var standaloneErrorBinding: Binding<Bool> {
        Binding(
            get: { presentedRelease == nil && { if case .error = updater.state { return true }; return false }() },
            set: { if !$0 { updater.dismissTransient() } }
        )
    }

    private var tagFilterMenu: some View {
        Menu {
            Button("All Tags") { tagFilter = nil }
            Divider()
            ForEach(tagsStore.tagOrder) { tag in
                Button {
                    tagFilter = tag
                } label: {
                    Image(nsImage: Self.dotImage(for: tag.color))
                    Text(tagsStore.displayName(for: tag))
                    if tagFilter == tag {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            Label("Filter by Tag", systemImage: tagFilter == nil ? "tag" : "tag.fill")
        }
        .help(tagFilter.map { "Filtering by tag: \(tagsStore.displayName(for: $0))" } ?? "Filter by tag")
    }

    /// `Menu`/`NSMenuItem` renders SF Symbol icons as monochrome template
    /// images, discarding any SwiftUI color modifier — so the tag swatches
    /// must be a non-template bitmap `NSImage` instead of a colored
    /// `Image(systemName:)`.
    private static func dotImage(for color: Color) -> NSImage {
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor(color).setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    private var probeFleetKey: String {
        let paths = store.repos.map(\.normalizedPath).sorted().joined(separator: ",")
        return "\(gitStatusCache.epoch)|\(paths)"
    }

    private func installTypeAheadMonitor() {
        guard typeAheadMonitor == nil else { return }
        typeAheadMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleTypeAhead(event)
        }
    }

    private func removeTypeAheadMonitor() {
        if let monitor = typeAheadMonitor {
            NSEvent.removeMonitor(monitor)
            typeAheadMonitor = nil
        }
    }

    private func handleTypeAhead(_ event: NSEvent) -> NSEvent? {
        guard let win = event.window, win === NSApp.mainWindow else { return event }
        guard win.attachedSheet == nil else { return event }
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if let responder = win.firstResponder, responder.isKind(of: NSText.self) {
            return event
        }
        if mods.contains(.command) || mods.contains(.control) || mods.contains(.option) {
            return event
        }

        switch event.keyCode {
        case 51: // Backspace
            guard !searchText.isEmpty else { return event }
            searchText.removeLast()
            return nil
        case 53: // Escape
            guard !searchText.isEmpty else { return event }
            searchText = ""
            return nil
        default:
            break
        }

        guard
            let chars = event.charactersIgnoringModifiers,
            let scalar = chars.unicodeScalars.first
        else { return event }
        if scalar.value < 0x20 || scalar.value == 0x7F { return event }
        if scalar.value >= 0xF700 && scalar.value <= 0xF8FF { return event }

        searchText.append(chars)
        return nil
    }

    private var baseView: some View {
        reposContent
            .id(listIdentity)
            .frame(minWidth: 990, maxWidth: 1320, minHeight: 320)
            .navigationTitle("Launch my Repo")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if viewMode == .card {
                        tagFilterMenu
                    }

                    Button {
                        viewModeRaw = (viewMode == .card ? ReposViewMode.list : .card).rawValue
                    } label: {
                        Label(
                            viewMode == .card ? "Switch to List" : "Switch to Grid",
                            systemImage: viewMode == .card ? "list.bullet" : "square.grid.2x2"
                        )
                    }
                    .help(viewMode == .card ? "Switch to list view" : "Switch to grid view")

                    Button {
                        gitStatusCache.clear()
                        Task { await store.rescanAll(folders: foldersStore.folders.paths, maxDepth: scanMaxDepth) }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .help("Rescan watched folders and re-check git status")
                }
            }
            .searchable(text: $searchText, prompt: "Filter repos")
            .overlay(alignment: .center) {
                if foldersStore.folders.paths.isEmpty {
                    emptyState
                } else if sortedRepos.isEmpty {
                    noMatchesState
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                statusBar
            }
    }

    /// Bottom status bar: count of currently displayed repos. Derived from
    /// `sortedRepos`, so it tracks the search/tag filter live; when a filter is
    /// active it also shows the unfiltered total ("N of M").
    private var statusBar: some View {
        let shown = sortedRepos.count
        let total = store.repos.count
        let isFiltered = shown != total
        return Text(statusText(shown: shown, total: total, isFiltered: isFiltered))
            .font(.callout)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private func statusText(shown: Int, total: Int, isFiltered: Bool) -> String {
        let noun = total == 1 ? "repo" : "repos"
        if isFiltered {
            return "\(shown) of \(total) \(noun)"
        }
        return "\(shown) \(shown == 1 ? "repo" : "repos")"
    }

    private var sortedRepos: [GitRepo] {
        let filtered = RepoListFilter(searchText: searchText)
            .apply(
                repos: store.repos,
                isFavorite: { favoritesStore.isFavorite($0) },
                tagRank: { tagsStore.rank(for: tagsStore.tag(for: $0)) },
                branch: { gitStatusCache.branch(for: $0) },
                tagName: { tagsStore.tag(for: $0).map { tagsStore.displayName(for: $0) } }
            )
        guard viewMode == .card, let tagFilter else { return filtered }
        return filtered.filter { tagsStore.tag(for: $0.normalizedPath) == tagFilter }
    }

    /// Disambiguated against the full repo list, not just `sortedRepos`, so a
    /// repo's displayed name doesn't change as the user types a search filter.
    private var displayNames: [String: String] {
        RepoDisplayNames.compute(for: store.repos)
    }

    private var listIdentity: String {
        "\(viewModeRaw)|\(searchText)"
    }

    @ViewBuilder
    private var reposContent: some View {
        switch viewMode {
        case .card: repoGrid
        case .list: repoList
        }
    }

    private var repoGrid: some View {
        GeometryReader { proxy in
            let columnCount = max(1, Int(proxy.size.width / 330))
            let columns = Array(repeating: GridItem(.fixed(330), spacing: 0), count: columnCount)
            ScrollView(.vertical) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
                    ForEach(sortedRepos) { repo in
                        RepoCardView(
                            repo: repo,
                            displayName: displayNames[repo.normalizedPath] ?? repo.name,
                            apps: launcherAppsStore.selectableApps(for: repo),
                            onReveal: { RepoOpener.revealInFinder(repo) },
                            onOpenIn: { app in openRepo(repo, with: app) }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    private var repoList: some View {
        List {
            ForEach(sortedRepos) { repo in
                RepoRowView(
                    repo: repo,
                    displayName: displayNames[repo.normalizedPath] ?? repo.name,
                    apps: launcherAppsStore.selectableApps(for: repo),
                    onReveal: { RepoOpener.revealInFinder(repo) },
                    onOpenIn: { app in openRepo(repo, with: app) }
                )
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.visible)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        repoPendingRemoval = repo
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .confirmationDialog(
            "Remove Repo",
            isPresented: Binding(
                get: { repoPendingRemoval != nil },
                set: { if !$0 { repoPendingRemoval = nil } }
            ),
            presenting: repoPendingRemoval
        ) { repo in
            Button("Move \"\(displayNames[repo.normalizedPath] ?? repo.name)\" to Trash", role: .destructive) {
                removeAndTrash(repo)
                repoPendingRemoval = nil
            }
            Button("Cancel", role: .cancel) {
                repoPendingRemoval = nil
            }
        } message: { _ in
            Text("This moves the repo's folder to the Trash and removes it from LmR's list.")
        }
    }

    private func removeAndTrash(_ repo: GitRepo) {
        let url = URL(fileURLWithPath: repo.normalizedPath)
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        } catch {
            openError = "Couldn't move \"\(repo.name)\" to Trash: \(error.localizedDescription)"
            return
        }
        store.remove(path: url)
    }

    private func openRepo(_ repo: GitRepo, with app: LauncherApp) {
        do {
            try RepoOpener.activate(repo, with: app)
        } catch {
            openError = error.localizedDescription
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No folders watched yet")
                .font(.title3)
            Text("Open Settings → Folders to choose a folder to scan for repos.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings…") { openSettings() }
        }
        .padding(32)
    }

    private var noMatchesState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No matching repos")
                .font(.title3)
            Text(searchText.isEmpty ? "No repos found yet." : "No repos match \"\(searchText)\".")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

#Preview {
    ContentView()
        .environment(RepoStore())
        .environment(FoldersStore())
        .environment(LauncherAppsStore())
        .environment(GitStatusCache())
        .environment(FavoritesStore())
        .environment(TagsStore())
        .environment(UpdateChecker())
}
