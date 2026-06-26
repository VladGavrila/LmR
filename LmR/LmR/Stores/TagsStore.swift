import Foundation
import Observation

@MainActor
@Observable
final class TagsStore {
    private(set) var tags: [String: RepoTag]
    private(set) var tagOrder: [RepoTag]
    private(set) var tagNames: [RepoTag: String]

    private let tagsKey  = AppStorageKey.repoTags.rawValue
    private let orderKey = AppStorageKey.repoTagOrder.rawValue
    private let namesKey = AppStorageKey.repoTagNames.rawValue
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        var parsed: [String: RepoTag] = [:]
        if let raw = defaults.dictionary(forKey: tagsKey) as? [String: String] {
            for (path, value) in raw {
                if let tag = RepoTag(rawValue: value) {
                    parsed[path] = tag
                }
            }
        }
        self.tags = parsed

        if let stored = defaults.stringArray(forKey: orderKey) {
            var seen = Set<RepoTag>()
            var order: [RepoTag] = []
            for raw in stored {
                if let tag = RepoTag(rawValue: raw), seen.insert(tag).inserted {
                    order.append(tag)
                }
            }
            for tag in RepoTag.defaultOrder where !seen.contains(tag) {
                order.append(tag)
            }
            self.tagOrder = order
        } else {
            self.tagOrder = RepoTag.defaultOrder
        }

        var names: [RepoTag: String] = [:]
        if let rawNames = defaults.dictionary(forKey: namesKey) as? [String: String] {
            for (key, value) in rawNames {
                if let tag = RepoTag(rawValue: key) {
                    names[tag] = value
                }
            }
        }
        self.tagNames = names
    }

    func rank(for tag: RepoTag?) -> Int {
        guard let tag else { return tagOrder.count }
        return tagOrder.firstIndex(of: tag) ?? tagOrder.count
    }

    func move(tag: RepoTag, before target: RepoTag) {
        guard tag != target,
              let srcIndex = tagOrder.firstIndex(of: tag) else { return }
        tagOrder.remove(at: srcIndex)
        guard let dstIndex = tagOrder.firstIndex(of: target) else {
            tagOrder.insert(tag, at: srcIndex)
            return
        }
        tagOrder.insert(tag, at: dstIndex)
        persistOrder()
    }

    func moveToEnd(tag: RepoTag) {
        guard let srcIndex = tagOrder.firstIndex(of: tag) else { return }
        tagOrder.remove(at: srcIndex)
        tagOrder.append(tag)
        persistOrder()
    }

    func resetOrder() {
        tagOrder = RepoTag.defaultOrder
        persistOrder()
    }

    func displayName(for tag: RepoTag) -> String {
        if let custom = tagNames[tag],
           !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return custom
        }
        return tag.displayName
    }

    func customName(for tag: RepoTag) -> String? {
        tagNames[tag]
    }

    func rename(tag: RepoTag, to name: String) {
        if name.isEmpty {
            tagNames.removeValue(forKey: tag)
        } else {
            tagNames[tag] = name
        }
        persistNames()
    }

    func tag(for path: String) -> RepoTag? {
        guard !path.isEmpty else { return nil }
        return tags[path]
    }

    func set(_ tag: RepoTag?, for path: String) {
        guard !path.isEmpty else { return }
        if let tag {
            tags[path] = tag
        } else {
            tags.removeValue(forKey: path)
        }
        persist()
    }

    func remove(path: String) {
        guard !path.isEmpty, tags[path] != nil else { return }
        tags.removeValue(forKey: path)
        persist()
    }

    private func persist() {
        let raw = tags.mapValues { $0.rawValue }
        defaults.set(raw, forKey: tagsKey)
    }

    private func persistOrder() {
        defaults.set(tagOrder.map(\.rawValue), forKey: orderKey)
    }

    private func persistNames() {
        let raw = Dictionary(uniqueKeysWithValues: tagNames.map { ($0.key.rawValue, $0.value) })
        defaults.set(raw, forKey: namesKey)
    }
}
