import Foundation
import SwiftUI

@main
struct KansolendarApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .appTheme()
        }
        .defaultSize(width: 1_400, height: 860)
        .windowResizability(.contentMinSize)

        WindowGroup("Kansolendar Vault", id: "kanso-vault", for: URL.self) { $url in
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
