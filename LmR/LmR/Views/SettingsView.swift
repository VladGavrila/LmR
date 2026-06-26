import SwiftUI
import AppKit
import UniformTypeIdentifiers
import CoreTransferable

extension LauncherApp: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

struct SettingsView: View {
    enum Tab: Hashable {
        case general, folders, apps, tags, updates
    }

    @Environment(FoldersStore.self) private var foldersStore
    @State private var selection: Tab = .general

    var body: some View {
        TabView(selection: $selection) {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(Tab.general)
            FoldersSettingsTab()
                .tabItem { Label("Folders", systemImage: "folder") }
                .tag(Tab.folders)
            AppsSettingsTab()
                .tabItem { Label("Apps", systemImage: "app.badge") }
                .tag(Tab.apps)
            TagsSettingsTab()
                .tabItem { Label("Tags", systemImage: "tag") }
                .tag(Tab.tags)
            UpdatesSettingsTab()
                .tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
                .tag(Tab.updates)
        }
        .frame(width: 520, height: 420)
        .onAppear {
            // On a fresh instance (no watched folders yet), land on Folders so the
            // first thing the user sees is where to add one, not General.
            if foldersStore.folders.paths.isEmpty {
                selection = .folders
            }
        }
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @AppStorage(AppPresentation.storageKey) private var presentationRaw: String = AppPresentation.dock.rawValue
    @AppStorage(KeyShortcut.StorageKey.enabled) private var hotKeyEnabled: Bool = true

    var body: some View {
        Form {
            Section {
                Picker("Show LmR as", selection: $presentationRaw) {
                    ForEach(AppPresentation.allCases) { option in
                        Text(option.label).tag(option.rawValue)
                    }
                }
                .onChange(of: presentationRaw) { _, newValue in
                    let presentation = AppPresentation(rawValue: newValue) ?? .dock
                    NSApp.setActivationPolicy(presentation.activationPolicy)
                    MenuBarStatusItem.shared.apply(presentation)
                    if presentation == .dock {
                        // Switching back from accessory to regular needs a re-activate
                        // for the Dock icon to actually reappear immediately.
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
            } header: {
                Text("App Presentation")
            }

            Section {
                Toggle("Enable global shortcut", isOn: $hotKeyEnabled)
                LabeledContent("Open command palette") {
                    ShortcutRecorderView(definition: .palette)
                }
                .disabled(!hotKeyEnabled)
            } header: {
                Text("Command Palette")
            } footer: {
                Text("Opens a floating search panel over any app to quickly launch a repo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Folders

private struct FoldersSettingsTab: View {
    @Environment(FoldersStore.self) private var foldersStore
    @Environment(RepoStore.self) private var repoStore

    @AppStorage(AppStorageKey.scanMaxDepth.rawValue) private var scanMaxDepth: Int = 6

    var body: some View {
        Form {
            Section {
                ForEach(foldersStore.folders.paths, id: \.self) { path in
                    folderRow(path)
                }
                Button {
                    addFolder()
                } label: {
                    Label("Add Folder…", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            } header: {
                Text("Watched Folders")
            } footer: {
                Text("LmR scans each folder recursively for git repositories.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Stepper("Max scan depth: \(scanMaxDepth)", value: $scanMaxDepth, in: 1...20)
            } header: {
                Text("Scanning")
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func folderRow(_ path: String) -> some View {
        HStack {
            Text(path)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Re-index") {
                Task { await repoStore.rescan(folder: URL(fileURLWithPath: path), maxDepth: scanMaxDepth) }
            }
            Button(role: .destructive) {
                foldersStore.remove(path)
                repoStore.removeAll(under: URL(fileURLWithPath: path))
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
        }
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        foldersStore.add(url.path)
        Task { await repoStore.rescan(folder: url, maxDepth: scanMaxDepth) }
    }
}

// MARK: - Apps

private struct AppsSettingsTab: View {
    @Environment(LauncherAppsStore.self) private var launcherAppsStore
    @AppStorage(AppStorageKey.defaultOpenAction.rawValue) private var defaultOpenAction: String = "finder"

    @State private var dropTargetApp: LauncherApp?
    @State private var draggingApp: LauncherApp?
    @State private var endDropTargeted: Bool = false

    var body: some View {
        Form {
            Section {
                Picker("Default open action", selection: $defaultOpenAction) {
                    Text(LauncherApp.finderName).tag("finder")
                    ForEach(launcherAppsStore.apps) { app in
                        Text(app.name).tag(app.id.uuidString)
                    }
                }
            } header: {
                Text("Default Action")
            }

            Section {
                ForEach(launcherAppsStore.apps) { app in
                    appRow(app)
                }
                endDropZone
                Button {
                    addApp()
                } label: {
                    Label("Add App", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            } header: {
                Text("Apps")
            } footer: {
                Text("Shown as icons on each repo card/row, in this order. Drag the rows to reorder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var endDropZone: some View {
        Rectangle()
            .fill(endDropTargeted ? Color.accentColor.opacity(0.25) : Color.clear)
            .frame(height: 8)
            .contentShape(Rectangle())
            .dropDestination(for: LauncherApp.self) { items, _ in
                endDropTargeted = false
                draggingApp = nil
                guard let source = items.first else { return false }
                launcherAppsStore.moveToEnd(app: source)
                return true
            } isTargeted: { value in
                endDropTargeted = value
            }
    }

    @ViewBuilder
    private func appRow(_ app: LauncherApp) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .help("Drag to reorder")
            AppIcon.icon(for: app)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
            Text(app.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Choose…") { chooseApp(app) }
            Button(role: .destructive) {
                removeApp(app)
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .opacity(draggingApp == app ? 0.4 : 1.0)
        .overlay(alignment: .top) {
            if dropTargetApp == app {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
            }
        }
        .draggable(app) {
            HStack(spacing: 6) {
                AppIcon.icon(for: app)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                Text(app.name).font(.callout)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            .onAppear { draggingApp = app }
            .onDisappear { draggingApp = nil }
        }
        .dropDestination(for: LauncherApp.self) { items, _ in
            dropTargetApp = nil
            draggingApp = nil
            guard let source = items.first else { return false }
            launcherAppsStore.move(app: source, before: app)
            return true
        } isTargeted: { isTargeted in
            dropTargetApp = isTargeted ? app : (dropTargetApp == app ? nil : dropTargetApp)
        }
    }

    /// Falls back the default open action to Finder if the removed app was it.
    private func removeApp(_ app: LauncherApp) {
        if defaultOpenAction == app.id.uuidString {
            defaultOpenAction = "finder"
        }
        launcherAppsStore.remove(id: app.id)
    }

    private func pickApp() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose App"
        panel.allowedContentTypes = [UTType.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return url
    }

    /// Shows the app picker immediately; adds a fully-formed entry only if the
    /// user actually picks an app, so cancelling never leaves a blank row.
    private func addApp() {
        guard let url = pickApp() else { return }
        launcherAppsStore.add(name: FileManager.default.displayName(atPath: url.path), appPath: url.path)
    }

    private func chooseApp(_ app: LauncherApp) {
        guard let url = pickApp() else { return }
        var updated = app
        updated.appPath = url.path
        updated.name = FileManager.default.displayName(atPath: url.path)
        launcherAppsStore.update(updated)
    }
}

// MARK: - Tags

private struct TagsSettingsTab: View {
    @Environment(TagsStore.self) private var tagsStore

    @State private var dropTargetTag: RepoTag?
    @State private var draggingTag: RepoTag?
    @State private var endDropTargeted: Bool = false

    var body: some View {
        Form {
            Section {
                ForEach(tagsStore.tagOrder) { tag in
                    tagOrderRow(tag: tag)
                }
                endDropZone
                HStack {
                    Spacer()
                    Button("Reset to Default") {
                        tagsStore.resetOrder()
                    }
                }
            } header: {
                Text("Tag Sort Order")
            } footer: {
                Text("Drag the rows to reorder. Repo cards are grouped by tag color in this order. Favorites always appear first; untagged repos last.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func nameBinding(for tag: RepoTag) -> Binding<String> {
        Binding(
            get: { tagsStore.customName(for: tag) ?? "" },
            set: { tagsStore.rename(tag: tag, to: $0) }
        )
    }

    private var endDropZone: some View {
        Rectangle()
            .fill(endDropTargeted ? Color.accentColor.opacity(0.25) : Color.clear)
            .frame(height: 8)
            .contentShape(Rectangle())
            .dropDestination(for: RepoTag.self) { items, _ in
                endDropTargeted = false
                draggingTag = nil
                guard let source = items.first else { return false }
                tagsStore.moveToEnd(tag: source)
                return true
            } isTargeted: { value in
                endDropTargeted = value
            }
    }

    @ViewBuilder
    private func tagOrderRow(tag: RepoTag) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .help("Drag to reorder")
            Circle()
                .fill(tag.color)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                )
                .help(tag.displayName)
            TextField(
                tag.displayName,
                text: nameBinding(for: tag),
                prompt: Text(tag.displayName)
            )
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 220)
            Spacer(minLength: 4)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .opacity(draggingTag == tag ? 0.4 : 1.0)
        .overlay(alignment: .top) {
            if dropTargetTag == tag {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
            }
        }
        .draggable(tag) {
            HStack(spacing: 6) {
                Circle().fill(tag.color).frame(width: 14, height: 14)
                Text(tag.displayName).font(.callout)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            .onAppear { draggingTag = tag }
            .onDisappear { draggingTag = nil }
        }
        .dropDestination(for: RepoTag.self) { items, _ in
            dropTargetTag = nil
            draggingTag = nil
            guard let source = items.first else { return false }
            tagsStore.move(tag: source, before: tag)
            return true
        } isTargeted: { isTargeted in
            dropTargetTag = isTargeted ? tag : (dropTargetTag == tag ? nil : dropTargetTag)
        }
    }
}

// MARK: - Updates

private struct UpdatesSettingsTab: View {
    @Environment(UpdateChecker.self) private var updater

    @AppStorage(AppStorageKey.autoCheckForUpdates.rawValue) private var autoCheck: Bool = true

    var body: some View {
        Form {
            Section {
                Toggle("Automatically check for updates", isOn: $autoCheck)
                    .onChange(of: autoCheck) { _, newValue in
                        updater.autoCheckForUpdates = newValue
                    }
                LabeledContent("Current version", value: updater.currentVersionString)
                LabeledContent("Last checked", value: lastCheckedDescription)
                HStack {
                    Spacer()
                    Button(checkButtonTitle) {
                        Task { await updater.check(userInitiated: true) }
                    }
                    .disabled(isChecking)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            autoCheck = updater.autoCheckForUpdates
        }
    }

    private var lastCheckedDescription: String {
        guard let date = updater.lastCheck else { return "Never" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private var isChecking: Bool {
        if case .checking = updater.state { return true }
        if case .downloading = updater.state { return true }
        if case .installing = updater.state { return true }
        return false
    }

    private var checkButtonTitle: String {
        isChecking ? "Checking…" : "Check for Updates Now"
    }
}

#Preview {
    SettingsView()
        .environment(FoldersStore())
        .environment(RepoStore())
        .environment(LauncherAppsStore())
        .environment(TagsStore())
        .environment(UpdateChecker())
}
