import Foundation
import Testing
@testable import LmRModels

@Suite("EmptyDirectoryCheck")
struct EmptyDirectoryCheckTests {

    @Test func trulyEmptyDirectoryIsRemovable() {
        #expect(EmptyDirectoryCheck.isRemovable(path: "/a/b", contents: [], watchedPaths: []))
    }

    @Test func directoryContainingOnlyDSStoreIsRemovable() {
        #expect(EmptyDirectoryCheck.isRemovable(path: "/a/b", contents: [".DS_Store"], watchedPaths: []))
    }

    @Test func directoryWithRealContentIsNotRemovable() {
        #expect(!EmptyDirectoryCheck.isRemovable(path: "/a/b", contents: [".DS_Store", "repo"], watchedPaths: []))
        #expect(!EmptyDirectoryCheck.isRemovable(path: "/a/b", contents: ["repo"], watchedPaths: []))
    }

    @Test func watchedFolderIsNeverRemovableEvenWhenEmpty() {
        #expect(!EmptyDirectoryCheck.isRemovable(path: "/a/b", contents: [], watchedPaths: ["/a/b"]))
        #expect(!EmptyDirectoryCheck.isRemovable(path: "/a/b", contents: [".DS_Store"], watchedPaths: ["/a/b"]))
    }

    @Test func onlyExactPathMatchIsProtected() {
        // A watched folder elsewhere in the tree doesn't protect an unrelated
        // empty directory that happens to share no path with it.
        #expect(EmptyDirectoryCheck.isRemovable(path: "/a/b", contents: [], watchedPaths: ["/a/c"]))
    }
}
