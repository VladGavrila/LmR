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
}
