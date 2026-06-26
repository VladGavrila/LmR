import SwiftUI

struct RepoRowView: View {
    let repo: GitRepo
    let displayName: String
    let apps: [LauncherApp]
    let onReveal: () -> Void
    let onOpenIn: (LauncherApp) -> Void

    @Environment(GitStatusCache.self) private var gitStatusCache

    var body: some View {
        HStack(spacing: 10) {
            titleView
                .frame(minWidth: 140, alignment: .leading)

            GitStatusBadge(status: gitStatusCache.status(for: repo.normalizedPath), lastCommitInline: true)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                ForEach(apps) { app in
                    appButton(for: app)
                }
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var titleView: some View {
        let title = Text(displayName)
            .font(.headline)
            .lineLimit(1)
            .truncationMode(.tail)

        if let remoteURL = repo.remoteURL, RemoteURLConverter.httpsURL(from: remoteURL) != nil {
            Button {
                RepoOpener.openRemoteInBrowser(repo)
            } label: {
                title
            }
            .buttonStyle(.plain)
            .help(repo.displayPath)
        } else {
            title
                .help(repo.displayPath)
        }
    }

    private func appButton(for app: LauncherApp) -> some View {
        Button {
            app.name == LauncherApp.finderName ? onReveal() : onOpenIn(app)
        } label: {
            AppIcon.icon(for: app)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.borderless)
        .help(app.name)
    }
}
