import Foundation
import Observation

@MainActor
@Observable
final class FavoritesStore {
    private(set) var paths: Set<String>

    private let defaultsKey = AppStorageKey.favoriteRepos.rawValue
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: defaultsKey) ?? []
        self.paths = Set(stored)
    }

    func isFavorite(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        return paths.contains(path)
    }

    func toggle(_ path: String) {
        guard !path.isEmpty else { return }
        if paths.contains(path) {
            paths.remove(path)
        } else {
            paths.insert(path)
        }
        persist()
    }

    private func persist() {
        defaults.set(Array(paths), forKey: defaultsKey)
    }
}
