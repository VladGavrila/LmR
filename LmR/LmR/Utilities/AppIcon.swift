import AppKit
import SwiftUI

enum AppIcon {
    /// Icon for `app`. Falls back to the Finder icon for the synthesized
    /// Finder entry (empty `appPath`).
    static func icon(for app: LauncherApp) -> Image {
        let path = app.appPath.isEmpty ? "/System/Library/CoreServices/Finder.app" : app.appPath
        let nsImage = NSWorkspace.shared.icon(forFile: path)
        return Image(nsImage: nsImage)
    }
}
