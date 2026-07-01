import AppKit
import SwiftUI

struct RepoDetailSheet: View {
    let repo: GitRepo
    let displayName: String

    @Environment(GitStatusCache.self) private var gitStatusCache
    @Environment(RepoStore.self) private var repoStore
    @Environment(\.dismiss) private var dismiss
    @State private var loader = RepoDetailLoader()
    @State private var remoteAdder = RemoteAdder()
    @State private var isAddingRemote = false
    @State private var newRemoteName = "origin"
    @State private var newRemoteURL = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GitStatusBadge(status: gitStatusCache.status(for: repo.normalizedPath), showsAheadBehind: true)
                    commitsSection
                    branchesSection
                    remotesSection
                    readmeSection
                }
                .padding(16)
            }
        }
        .frame(minWidth: 520, idealWidth: 600, minHeight: 480, idealHeight: 640)
        .task(id: repo.normalizedPath) {
            await loader.load(for: repo)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                titleView
                Text(repo.displayPath)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    private var titleView: some View {
        Text(displayName).font(.title3).bold()
    }

    @ViewBuilder
    private var commitsSection: some View {
        sectionHeader("Recent Commits")
        if loader.commits.isEmpty {
            placeholder(loader.isLoading ? "Loading…" : "No commits yet.")
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(loader.commits.prefix(5), id: \.shortHash) { commit in
                    HStack(spacing: 8) {
                        Text(commit.shortHash)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        Text(commit.subject)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 8)
                        Text(commit.relativeDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .help("By \(commit.authorName)")
                }
                if loader.commits.count > 5 {
                    moreCommitsButton
                }
            }
        }
    }

    @ViewBuilder
    private var moreCommitsButton: some View {
        if let remoteURL = repo.remoteURL, let httpsURL = RemoteURLConverter.httpsURL(from: remoteURL) {
            Button {
                NSWorkspace.shared.open(httpsURL.appendingPathComponent("commits"))
            } label: {
                Text("…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("View all commits")
        } else {
            Text("…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var branchesSection: some View {
        sectionHeader("Branches")
        if loader.branches.isEmpty {
            placeholder(loader.isLoading ? "Loading…" : "No branches.")
        } else {
            Text(loader.branches.joined(separator: ", "))
                .font(.callout)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var remotesSection: some View {
        sectionHeader("Remotes")
        if loader.remotes.isEmpty {
            if isAddingRemote {
                addRemoteForm
            } else {
                HStack {
                    placeholder(loader.isLoading ? "Loading…" : "No remotes.")
                    if !loader.isLoading {
                        Spacer()
                        Button("Add Remote…") { isAddingRemote = true }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(loader.remotes, id: \.name) { remote in
                    HStack(spacing: 6) {
                        Text(remote.name)
                            .font(.callout)
                            .bold()
                        if let httpsURL = RemoteURLConverter.httpsURL(from: remote.url) {
                            Button {
                                NSWorkspace.shared.open(httpsURL)
                            } label: {
                                Text(remote.url)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .buttonStyle(.plain)
                            .help(httpsURL.absoluteString)
                        } else {
                            Text(remote.url)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
        }
    }

    /// Only shown when `loader.remotes` is empty — adding to a repo that
    /// already has a remote (or editing an existing one) is out of scope.
    @ViewBuilder
    private var addRemoteForm: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                TextField("Name", text: $newRemoteName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                TextField("https://github.com/org/repo.git", text: $newRemoteURL)
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)
            }
            if case .error(let message) = remoteAdder.state {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") {
                    isAddingRemote = false
                    newRemoteURL = ""
                    remoteAdder.reset()
                }
                Button("Save") {
                    Task { await saveRemote() }
                }
                .disabled(isSavingRemote || trimmedNewRemoteName.isEmpty || trimmedNewRemoteURL.isEmpty)
            }
        }
    }

    private var trimmedNewRemoteName: String {
        newRemoteName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNewRemoteURL: String {
        newRemoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSavingRemote: Bool {
        if case .saving = remoteAdder.state { return true }
        return false
    }

    /// Adds the remote, then syncs it into `RepoStore` (so the card/row's
    /// browser button appears without a manual refresh) and re-runs `loader`
    /// to repopulate `remotesSection` from the newly-added remote.
    private func saveRemote() async {
        let name = trimmedNewRemoteName
        let url = trimmedNewRemoteURL
        let ok = await remoteAdder.addRemote(name: name, url: url, at: repo.normalizedPath)
        guard ok else { return }
        repoStore.updateRemoteURL(url, forPath: repo.url)
        await loader.load(for: repo)
        isAddingRemote = false
        newRemoteURL = ""
    }

    @ViewBuilder
    private var readmeSection: some View {
        if let readmeText = loader.readmeText, !readmeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sectionHeader("README")
            ScrollView {
                MarkdownView(text: readmeText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 200, maxHeight: 320)
            .padding(10)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        } else if loader.readmeText == nil {
            sectionHeader("README")
            placeholder(loader.isLoading ? "Loading…" : "No README found.")
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
    }
}
