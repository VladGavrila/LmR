// swift-tools-version: 6.0
// Compiles the pure Foundation-only model types into a library target so they
// can be covered by Swift Testing tests without the full Xcode app target.
// Run with: swift test   (from the repo root)
import PackageDescription

let package = Package(
    name: "LmRCore",
    platforms: [.macOS(.v15)],
    targets: [
        .target(
            name: "LmRModels",
            path: "LmR/LmR/Models",
            sources: [
                "AppStorageKey.swift",
                "GitRepo.swift",
                "RepoIndex.swift",
                "FolderScanner.swift",
                "RepoListFilter.swift",
                "LauncherApp.swift",
                "WatchedFolders.swift",
                "GitStatusParser.swift",
                "RemoteURLConverter.swift",
                "RepoDisplayNames.swift",
                "RepoSearchScorer.swift",
                "ClonePathPlanner.swift",
                "GitLogParser.swift",
                "NewRepoPathPlanner.swift",
                "EmptyDirectoryCheck.swift"
            ]
        ),
        .target(
            name: "LmRUtilities",
            path: "LmR/LmR/Utilities",
            sources: ["SemanticVersion.swift", "Git.swift"]
        ),
        .target(
            name: "LmRStores",
            dependencies: ["LmRModels", "LmRUtilities"],
            path: "LmR/LmR/Stores",
            sources: ["GitStatusCache.swift"]
        ),
        .testTarget(
            name: "LmRTests",
            dependencies: ["LmRModels", "LmRUtilities", "LmRStores"],
            path: "Tests/LmRTests"
        ),
    ]
)
