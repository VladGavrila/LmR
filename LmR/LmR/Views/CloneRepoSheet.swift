import AppKit
import SwiftUI

struct CloneRepoSheet: View {
    @Environment(FoldersStore.self) private var foldersStore
    @Environment(RepoStore.self) private var repoStore
    @Environment(GitStatusCache.self) private var gitStatusCache
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppStorageKey.scanMaxDepth.rawValue) private var scanMaxDepth: Int = 6

    @State private var cloner = GitCloner()
    @State private var remoteURLText: String = ""
    @State private var selectedRoot: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Clone Repository")
                .font(.title3.bold())

            TextField("https://github.com/org/repo.git", text: $remoteURLText)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)

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

            if let plan {
                Text("Will clone into \(Self.homeRelative(plan.destination.path))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if selectedRoot == nil {
                Text("Choose a destination folder to continue.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if !remoteURLText.isEmpty {
                Text("Couldn't determine a destination from this URL.")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            if case .cloning = cloner.state {
                ProgressView("Cloning…")
                    .progressViewStyle(.linear)
            } else if case .error(let message) = cloner.state {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Clone") {
                    startClone()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(plan == nil || isCloning)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onChange(of: cloner.state) { _, newValue in
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

    private var isCloning: Bool {
        if case .cloning = cloner.state { return true }
        return false
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

    /// Opens a folder picker (allowing creation of a new folder) for cloning
    /// into a location that isn't an existing watched folder yet. The chosen
    /// folder is added as a watched root and scanned immediately, the same as
    /// adding one from Settings, so the cloned repo shows up afterward.
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
    CloneRepoSheet()
        .environment(FoldersStore())
        .environment(RepoStore())
        .environment(GitStatusCache())
}
