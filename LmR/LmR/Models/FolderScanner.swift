import Foundation

/// Pure, testable traversal: finds every git repo under a root folder.
enum FolderScanner {
    static let defaultSkipDirectories: Set<String> = [
        "node_modules", ".build", "DerivedData", "Pods", "vendor", ".git"
    ]

    /// Recurses from `root`; when a directory contains `.git`, its URL is
    /// recorded as a repo root and traversal does not descend into it.
    /// Honors `maxDepth` (depth of `root` itself is 0) and skips any
    /// directory whose name is in `skipDirectories`.
    static func scan(
        root: URL,
        maxDepth: Int,
        skipDirectories: Set<String> = defaultSkipDirectories,
        fileManager: FileManager = .default
    ) -> [URL] {
        var results: [URL] = []
        scanRecursive(
            dir: root,
            depth: 0,
            maxDepth: maxDepth,
            skipDirectories: skipDirectories,
            fileManager: fileManager,
            results: &results
        )
        return results
    }

    private static func scanRecursive(
        dir: URL,
        depth: Int,
        maxDepth: Int,
        skipDirectories: Set<String>,
        fileManager: FileManager,
        results: inout [URL]
    ) {
        guard depth <= maxDepth else { return }

        let gitMarker = dir.appendingPathComponent(".git")
        if fileManager.fileExists(atPath: gitMarker.path) {
            results.append(dir)
            return
        }

        guard let children = try? fileManager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for child in children {
            guard let isDir = try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                  isDir else { continue }
            if skipDirectories.contains(child.lastPathComponent) { continue }
            scanRecursive(
                dir: child,
                depth: depth + 1,
                maxDepth: maxDepth,
                skipDirectories: skipDirectories,
                fileManager: fileManager,
                results: &results
            )
        }
    }
}
