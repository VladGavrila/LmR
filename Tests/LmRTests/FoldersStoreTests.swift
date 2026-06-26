import Foundation
import Testing
@testable import LmRModels

// FoldersStore is a @MainActor/@Observable class that lives in the Xcode
// target, not the LmRModels SPM target. These tests exercise the pure
// dedupe/normalize layer it delegates to.

@Suite("WatchedFolders – dedupe/normalize (FoldersStore's model layer)")
struct FoldersStoreTests {

    @Test func addNormalizesTrailingSlash() {
        var folders = WatchedFolders()
        folders.add("/tmp/repos/")
        #expect(folders.paths == ["/tmp/repos"])
    }

    @Test func addDedupesEquivalentPaths() {
        var folders = WatchedFolders()
        folders.add("/tmp/repos")
        folders.add("/tmp/repos/")
        #expect(folders.paths.count == 1)
    }

    @Test func addIgnoresEmptyPath() {
        var folders = WatchedFolders()
        folders.add("")
        #expect(folders.paths.isEmpty)
    }

    @Test func remove() {
        var folders = WatchedFolders(paths: ["/tmp/a", "/tmp/b"])
        folders.remove("/tmp/a")
        #expect(folders.paths == ["/tmp/b"])
    }

    @Test func preservesInsertionOrder() {
        var folders = WatchedFolders()
        folders.add("/tmp/b")
        folders.add("/tmp/a")
        #expect(folders.paths == ["/tmp/b", "/tmp/a"])
    }
}
