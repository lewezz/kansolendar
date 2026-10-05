import AppKit
import Foundation
import SwiftUI

@main
struct KansolendarApp: App {
    // Vaults use independent windows rather than a tab bar with a second "+" action.
    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup("Kansolendar") {
            RootView()
                .appTheme()
        }
        .defaultSize(width: 1_400, height: 860)
        .windowResizability(.contentMinSize)

        WindowGroup("Kansolendar", id: "kanso-vault", for: URL.self) { $url in
            RootView(portableFileURL: url)
                .appTheme()
        }
        .defaultSize(width: 1_400, height: 860)
        .windowResizability(.contentMinSize)

        Settings {
            AppearanceSettingsView()
                .appTheme()
        }
    }
}
