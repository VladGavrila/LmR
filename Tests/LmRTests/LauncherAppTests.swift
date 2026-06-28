import Foundation
import Testing
@testable import LmRModels

@Suite("LauncherApp")
struct LauncherAppTests {

    @Test func codableRoundTrip() throws {
        let app = LauncherApp(name: "VS Code", appPath: "/Applications/Visual Studio Code.app")
        let data = try JSONEncoder().encode(app)
        let decoded = try JSONDecoder().decode(LauncherApp.self, from: data)
        #expect(decoded.name == "VS Code")
        #expect(decoded.appPath == app.appPath)
        #expect(decoded.id == app.id)
    }

    /// The two synthesized-entry sentinels must stay distinct: `RepoOpener`
    /// routes Finder vs Browser purely by these names, so a collision (or a
    /// rename that drifts from `RepoOpener`/`BrowserLauncher`) would silently
    /// misroute one as the other.
    @Test func synthesizedSentinelsAreDistinct() {
        #expect(LauncherApp.finderName == "Finder")
        #expect(LauncherApp.browserName == "Browser")
        #expect(LauncherApp.finderName != LauncherApp.browserName)
    }
}
