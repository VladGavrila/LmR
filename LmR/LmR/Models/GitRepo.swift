import Foundation

struct GitRepo: Identifiable, Hashable, Codable {
    var id: UUID
    /// Folder name (e.g. "LmR").
    var name: String
    var url: URL
    var remoteURL: String?
    /// Which watched root this repo was discovered under.
    var parentFolder: URL

    init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        remoteURL: String? = nil,
        parentFolder: URL
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.remoteURL = remoteURL
        self.parentFolder = parentFolder
    }

    /// Normalized absolute path, used as the dedupe/identity key for the repo's
    /// location independent of trailing slashes or symlink-insensitive resolution.
    var normalizedPath: String {
        url.standardizedFileURL.path
    }

    /// Home-relative display form, e.g. "~/src/LmR".
    var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.standardizedFileURL.path
        if path == home {
            return "~"
        }
        if path.hasPrefix(home + "/") {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
