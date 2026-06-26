import Testing
@testable import LmRModels

@Suite("AppStorageKey")
struct AppStorageKeyTests {

    @Test func allKeysAreUnique() {
        let keys = AppStorageKey.allCases.map(\.rawValue)
        #expect(keys.count == Set(keys).count,
                "Duplicate UserDefaults key found — silent data loss risk")
    }

    @Test func keyCountMatchesExpected() {
        // Guard against accidentally adding a duplicate or removing a key.
        // Update this number whenever a key is intentionally added or removed.
        #expect(AppStorageKey.allCases.count == 17)
    }

    @Test func knownKeysHaveCorrectRawValues() {
        #expect(AppStorageKey.watchedFolders.rawValue   == "watchedFolders")
        #expect(AppStorageKey.launcherApps.rawValue      == "launcherApps")
        #expect(AppStorageKey.defaultOpenAction.rawValue == "defaultOpenAction")
        #expect(AppStorageKey.reposViewMode.rawValue     == "reposViewMode")
        #expect(AppStorageKey.scanMaxDepth.rawValue      == "scanMaxDepth")
        #expect(AppStorageKey.paletteHotKeyEnabled.rawValue   == "paletteHotKeyEnabled")
        #expect(AppStorageKey.paletteHotKeyKeyCode.rawValue   == "paletteHotKeyKeyCode")
        #expect(AppStorageKey.paletteHotKeyModifiers.rawValue == "paletteHotKeyModifiers")
        #expect(AppStorageKey.paletteHotKeyDisplay.rawValue   == "paletteHotKeyDisplay")
        #expect(AppStorageKey.appPresentation.rawValue        == "appPresentation")
        #expect(AppStorageKey.favoriteRepos.rawValue          == "favoriteRepos")
        #expect(AppStorageKey.repoTags.rawValue               == "repoTags")
        #expect(AppStorageKey.repoTagOrder.rawValue           == "repoTagOrder")
        #expect(AppStorageKey.repoTagNames.rawValue           == "repoTagNames")
        #expect(AppStorageKey.autoCheckForUpdates.rawValue    == "autoCheckForUpdates")
        #expect(AppStorageKey.updateLastCheck.rawValue        == "updateLastCheck")
        #expect(AppStorageKey.skippedUpdateVersion.rawValue   == "skippedUpdateVersion")
    }
}
