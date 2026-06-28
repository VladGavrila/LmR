import SwiftUI

struct CommandPaletteView: View {
    let repos: [GitRepo]
    let apps: [LauncherApp]
    let defaultApp: LauncherApp
    let onOpen: (GitRepo, LauncherApp) -> Void
    let onClose: () -> Void

    @Environment(GitStatusCache.self) private var gitStatusCache

    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @State private var appPickerRepo: GitRepo?
    @State private var appPickerIndex: Int = 0
    @FocusState private var queryFocused: Bool

    private let maxResults = 8
    private let approxRowHeight: CGFloat = 46
    private let minVisibleRows: CGFloat = 4
    private let maxVisibleRows: CGFloat = 7

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search repos…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($queryFocused)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            Group {
                if let repo = appPickerRepo {
                    appPickerContent(for: repo)
                } else if results.isEmpty {
                    Text(repos.isEmpty ? "No repos indexed yet." : "No matches for \"\(query)\".")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(results.enumerated()), id: \.element.id) { index, repo in
                                    row(for: repo, index: index)
                                        .id(repo.id)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .top)
                        }
                        .onChange(of: selectedIndex) { _, newValue in
                            if results.indices.contains(newValue) {
                                withAnimation(.easeOut(duration: 0.1)) {
                                    proxy.scrollTo(results[newValue].id, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .frame(
                minHeight: approxRowHeight * minVisibleRows,
                maxHeight: approxRowHeight * maxVisibleRows,
                alignment: .top
            )

            Divider()

            HStack(spacing: 14) {
                if appPickerRepo != nil {
                    hint("↵", "Open")
                    hint("⌘1-9", "Open in app")
                    hint("Esc", "Back")
                } else {
                    hint("↵", "Open")
                    if selectedRepo.flatMap({ BrowserLauncher.app(for: $0) }) != nil {
                        hint("⌘B", "Open in Browser")
                    }
                    hint("⌘↵", "Open in…")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 600)
        .onChange(of: query) { _, _ in
            selectedIndex = 0
            dismissAppPicker()
        }
        .onAppear { queryFocused = true }
        .onKeyPress(.downArrow) {
            if appPickerRepo != nil {
                moveAppPicker(by: 1)
            } else {
                move(by: 1)
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if appPickerRepo != nil {
                moveAppPicker(by: -1)
            } else {
                move(by: -1)
            }
            return .handled
        }
        .onKeyPress(.escape) {
            if appPickerRepo != nil {
                dismissAppPicker()
            } else {
                onClose()
            }
            return .handled
        }
        .onKeyPress(keys: [.return]) { press in
            guard appPickerRepo == nil else {
                activateAppPicker()
                return .handled
            }
            if press.modifiers.contains(.command) {
                openAppPicker()
                return .handled
            }
            activateDefault()
            return .handled
        }
        .onKeyPress(keys: ["b"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            let target = appPickerRepo ?? selectedRepo
            guard let target, let browser = BrowserLauncher.app(for: target) else { return .ignored }
            onOpen(target, browser)
            dismissAppPicker()
            return .handled
        }
        .onKeyPress(keys: ["1", "2", "3", "4", "5", "6", "7", "8", "9"]) { press in
            // ⌘1-9 only acts inside the "Open in…" submenu (reached via ⌘↵).
            guard press.modifiers.contains(.command),
                  let repo = appPickerRepo,
                  let digit = press.characters.first.flatMap({ Int(String($0)) }),
                  digit >= 1, digit <= 9 else { return .ignored }
            let list = pickerApps(for: repo)
            let index = digit - 1
            guard list.indices.contains(index) else { return .handled }
            onOpen(repo, list[index])
            dismissAppPicker()
            return .handled
        }
    }

    private func row(for repo: GitRepo, index: Int) -> some View {
        let isSelected = index == selectedIndex
        let status = gitStatusCache.status(for: repo.normalizedPath)

        return HStack(spacing: 10) {
            GitStatusBadge(status: status)
                .frame(width: 90, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(repo.name)
                    .font(.body)
                    .lineLimit(1)
                Text(repo.displayPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if isSelected {
                Image(systemName: "return")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        .onTapGesture { onOpen(repo, defaultApp) }
        .contextMenu {
            ForEach(pickerApps(for: repo)) { app in
                Button("Open in \(app.name)") { onOpen(repo, app) }
            }
        }
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
            Text(label)
        }
    }

    private var selectedRepo: GitRepo? {
        results.indices.contains(selectedIndex) ? results[selectedIndex] : nil
    }

    private func move(by delta: Int) {
        guard !results.isEmpty else { return }
        let next = selectedIndex + delta
        selectedIndex = max(0, min(results.count - 1, next))
    }

    private func activateDefault() {
        guard let repo = selectedRepo else { return }
        onOpen(repo, defaultApp)
    }

    private func openAppPicker() {
        guard let repo = selectedRepo else { return }
        appPickerRepo = repo
        appPickerIndex = 0
    }

    private func dismissAppPicker() {
        guard appPickerRepo != nil else { return }
        appPickerRepo = nil
        appPickerIndex = 0
    }

    private func moveAppPicker(by delta: Int) {
        guard let repo = appPickerRepo else { return }
        let count = pickerApps(for: repo).count
        guard count > 0 else { return }
        appPickerIndex = max(0, min(count - 1, appPickerIndex + delta))
    }

    private func activateAppPicker() {
        guard let repo = appPickerRepo else { return }
        let list = pickerApps(for: repo)
        guard list.indices.contains(appPickerIndex) else { return }
        onOpen(repo, list[appPickerIndex])
        dismissAppPicker()
    }

    /// The "Open in…" submenu's entries for `repo`: the configured apps plus the
    /// synthesized Browser entry (after Finder) when the repo has a web remote,
    /// so the browser is a first-class, selectable item with its own ⌘N.
    private func pickerApps(for repo: GitRepo) -> [LauncherApp] {
        var list = apps
        if let browser = BrowserLauncher.app(for: repo) {
            list.insert(browser, at: 1)
        }
        return list
    }

    @ViewBuilder
    private func appPickerContent(for repo: GitRepo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Open in")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(repo.name)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ForEach(Array(pickerApps(for: repo).enumerated()), id: \.offset) { index, app in
                let isSelected = index == appPickerIndex
                let isDefault = app.id == defaultApp.id
                HStack(spacing: 10) {
                    AppIcon.icon(for: app)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                    Text(app.name)
                        .font(.body)
                    if isDefault {
                        Text("default")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                    }
                    Spacer()
                    if index < 9 {
                        Text("⌘\(index + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                    }
                    if isSelected {
                        Image(systemName: "return")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
                .onTapGesture {
                    onOpen(repo, app)
                    dismissAppPicker()
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var results: [GitRepo] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let scored: [(repo: GitRepo, score: Int)]
        if trimmed.isEmpty {
            scored = repos.map { ($0, 0) }
        } else {
            scored = repos.compactMap { repo in
                let branch = gitStatusCache.branch(for: repo.normalizedPath)
                let s = RepoSearchScorer.score(repo: repo, query: trimmed, branch: branch)
                return trimmed.isEmpty || s > 0 ? (repo, s) : nil
            }
        }

        let ranked = scored.sorted { a, b in
            if a.score != b.score { return a.score > b.score }
            return a.repo.name.localizedCaseInsensitiveCompare(b.repo.name) == .orderedAscending
        }

        return Array(ranked.prefix(maxResults)).map(\.repo)
    }
}
