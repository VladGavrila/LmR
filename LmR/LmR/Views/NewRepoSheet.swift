import AppKit
import SwiftUI

struct NewRepoSheet: View {
    private enum SheetMode: String, CaseIterable, Identifiable {
        case clone, create
        var id: Self { self }
        var label: String { self == .clone ? "Clone" : "Create New" }
    }

    @Environment(FoldersStore.self) private var foldersStore
    @Environment(RepoStore.self) private var repoStore
    @Environment(GitStatusCache.self) private var gitStatusCache
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppStorageKey.scanMaxDepth.rawValue) private var scanMaxDepth: Int = 6

    @State private var mode: SheetMode = .clone
    @State private var cloner = GitCloner()
    @State private var creator = LocalRepoCreator()
    @State private var remoteURLText: String = ""
    @State private var repoNameText: String = ""
    @State private var selectedRoot: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(mode == .clone ? "Clone Repository" : "Create Repository")
                .font(.title3.bold())

            Picker("", selection: $mode) {
                ForEach(SheetMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if mode == .clone {
                TextField("https://github.com/org/repo.git", text: $remoteURLText)
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)
            } else {
                TextField("Repo name", text: $repoNameText)
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)
            }

            HStack(spacing: 8) {
                Text("Into folder")
                Menu {
                    ForEach(foldersStore.folders.paths, id: \.self) { path in
                        Button(Self.homeRelative(path)) {
                            selectedRoot = path
                        }
                    }
                    if !foldersStore.folders.paths.isEmpty {
                        Divider()
                    }
                    Button(chooseFolderLabel) {
                        pickAnotherFolder()
                    }
                } label: {
                    Text(selectedRoot.map(Self.homeRelative) ?? chooseFolderLabel)
                }
                .fixedSize()
                Spacer()
            }

            if let destinationPath {
                Text("Will \(mode == .clone ? "clone" : "create") into \(Self.homeRelative(destinationPath))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if selectedRoot == nil {
                Text("Choose a destination folder to continue.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if mode == .clone && !remoteURLText.isEmpty {
                Text("Couldn't determine a destination from this URL.")
                    .font(.callout)
                    .foregroundStyle(.orange)
            } else if mode == .create && !repoNameText.isEmpty {
                Text("Enter a valid repo name (no \"/\").")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            if isBusy {
                ProgressView(mode == .clone ? "Cloning…" : "Creating…")
                    .progressViewStyle(.linear)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(mode == .clone ? "Clone" : "Create") {
                    start()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(destinationPath == nil || isBusy)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onChange(of: cloner.state) { _, newValue in
            if case .done = newValue {
                dismiss()
            }
        }
        .onChange(of: creator.state) { _, newValue in
            if case .done = newValue {
                dismiss()
            }
        }
        .onAppear {
            if selectedRoot == nil {
                selectedRoot = foldersStore.folders.paths.first
            }
        }
    }

    private var isBusy: Bool {
        switch mode {
        case .clone:
            if case .cloning = cloner.state { return true }
            return false
        case .create:
            if case .creating = creator.state { return true }
            return false
        }
    }

    private var errorMessage: String? {
        switch mode {
        case .clone:
            if case .error(let message) = cloner.state { return message }
            return nil
        case .create:
            if case .error(let message) = creator.state { return message }
            return nil
        }
    }

    private var chooseFolderLabel: String {
        foldersStore.folders.paths.isEmpty ? "Choose a folder…" : "Choose another folder…"
    }

    private var plan: ClonePlan? {
        guard let selectedRoot else { return nil }
        let trimmed = remoteURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return ClonePathPlanner.plan(remoteURL: trimmed, into: URL(fileURLWithPath: selectedRoot))
    }

    private var newRepoDestination: URL? {
        guard let selectedRoot else { return nil }
        return NewRepoPathPlanner.plan(name: repoNameText, into: URL(fileURLWithPath: selectedRoot))
    }

    private var destinationPath: String? {
        switch mode {
        case .clone: return plan?.destination.path
        case .create: return newRepoDestination?.path
        }
    }

    private func start() {
        switch mode {
        case .clone: startClone()
        case .create: startCreate()
        }
    }

    private func startClone() {
        guard let plan else { return }
        let url = remoteURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await cloner.clone(remoteURL: url, plan: plan)
            if case .done = cloner.state, let selectedRoot {
                await repoStore.rescan(folder: URL(fileURLWithPath: selectedRoot), maxDepth: scanMaxDepth)
                // FolderWatcher's FSEvents can detect the new repo mid-clone (git
                // creates .git/ almost immediately) and cache an incomplete status
                // before this rescan runs. Clear so it gets re-probed with the
                // finished checkout, the same recovery the Refresh button uses.
                gitStatusCache.clear()
            }
        }
    }

    private func startCreate() {
        guard let newRepoDestination else { return }
        Task {
            await creator.create(at: newRepoDestination)
            if case .done = creator.state, let selectedRoot {
                await repoStore.rescan(folder: URL(fileURLWithPath: selectedRoot), maxDepth: scanMaxDepth)
                gitStatusCache.clear()
            }
        }
    }

    /// Opens a folder picker (allowing creation of a new folder) for cloning
    /// or creating into a location that isn't an existing watched folder yet.
    /// The chosen folder is added as a watched root and scanned immediately,
    /// the same as adding one from Settings, so the repo shows up afterward.
    private func pickAnotherFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let chosen = url.standardizedFileURL.path
        if !foldersStore.folders.paths.contains(chosen) {
            foldersStore.add(chosen)
            Task { await repoStore.rescan(folder: url, maxDepth: scanMaxDepth) }
        }
        selectedRoot = chosen
    }

    private static func homeRelative(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

#Preview {
    NewRepoSheet()
        .environment(FoldersStore())
        .environment(RepoStore())
        .environment(GitStatusCache())
}
