import SwiftUI

struct RepoCardView: View {
    let repo: GitRepo
    let displayName: String
    let apps: [LauncherApp]
    let onReveal: () -> Void
    let onOpenIn: (LauncherApp) -> Void

    @Environment(GitStatusCache.self) private var gitStatusCache
    @Environment(FavoritesStore.self) private var favoritesStore
    @Environment(TagsStore.self) private var tagsStore

    @State private var showTagPicker: Bool = false

    private var isFavorite: Bool {
        favoritesStore.isFavorite(repo.normalizedPath)
    }

    private var repoTag: RepoTag? {
        tagsStore.tag(for: repo.normalizedPath)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            GitStatusBadge(status: gitStatusCache.status(for: repo.normalizedPath), showsAheadBehind: true)

            Divider()

            HStack(spacing: 12) {
                tagButton
                Spacer()
                ForEach(apps) { app in
                    appButton(for: app)
                }
            }
        }
        .padding(14)
        .frame(minWidth: 300, maxWidth: 300, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(repoTag?.color ?? Color.clear, lineWidth: 2)
        )
        .padding(15)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                titleView
                Spacer()
                favoriteButton
            }
            Text(repo.displayPath)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(repo.displayPath)
        }
    }

    private var favoriteButton: some View {
        Button {
            favoritesStore.toggle(repo.normalizedPath)
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .foregroundStyle(isFavorite ? Color.yellow : Color.secondary)
                .frame(width: 14, height: 14)
        }
        .buttonStyle(.borderless)
        .help(isFavorite ? "Unpin from top" : "Pin to top")
    }

    private var tagButton: some View {
        Button {
            showTagPicker.toggle()
        } label: {
            Image(systemName: repoTag == nil ? "tag" : "tag.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(repoTag?.color ?? Color.secondary)
        }
        .buttonStyle(.borderless)
        .help(repoTag.map { "Tag: \(tagsStore.displayName(for: $0))" } ?? "Assign a tag")
        .popover(isPresented: $showTagPicker, arrowEdge: .bottom) {
            tagPickerPopover
        }
    }

    private var tagPickerPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(tagsStore.tagOrder) { tag in
                    Button {
                        tagsStore.set(tag, for: repo.normalizedPath)
                        showTagPicker = false
                    } label: {
                        ZStack {
                            Circle()
                                .fill(tag.color)
                                .frame(width: 22, height: 22)
                            if repoTag == tag {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay(
                            Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(tagsStore.displayName(for: tag))
                }
            }

            Divider()

            Button {
                tagsStore.set(nil, for: repo.normalizedPath)
                showTagPicker = false
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "nosign")
                    Text("No Tag")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
    }

    @ViewBuilder
    private var titleView: some View {
        let title = Text(displayName)
            .font(.headline)
            .lineLimit(1)
            .truncationMode(.tail)

        if let remoteURL = repo.remoteURL, let httpsURL = RemoteURLConverter.httpsURL(from: remoteURL) {
            Button {
                RepoOpener.openRemoteInBrowser(repo)
            } label: {
                title
            }
            .buttonStyle(.plain)
            .help(httpsURL.absoluteString)
        } else {
            title
        }
    }

    private func appButton(for app: LauncherApp) -> some View {
        Button {
            app.name == LauncherApp.finderName ? onReveal() : onOpenIn(app)
        } label: {
            AppIcon.icon(for: app)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.borderless)
        .help(app.name)
    }
}
