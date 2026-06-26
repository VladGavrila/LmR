import Foundation
import Observation

@MainActor
@Observable
final class FoldersStore {
    private(set) var folders: WatchedFolders

    private let defaultsKey = AppStorageKey.watchedFolders.rawValue
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: defaultsKey) ?? []
        self.folders = WatchedFolders(paths: stored)
    }

    func add(_ path: String) {
        folders.add(path)
        persist()
    }

    func remove(_ path: String) {
        folders.remove(path)
        persist()
    }

    private func persist() {
        defaults.set(folders.paths, forKey: defaultsKey)
    }
}
