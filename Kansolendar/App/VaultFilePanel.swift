import AppKit
import UniformTypeIdentifiers

@MainActor
enum VaultFilePanel {
    static let kansoType = UTType(exportedAs: "local.kansolendar.vault", conformingTo: .data)

    static func chooseKansoDestination() -> URL? {
        guard let selected = chooseDestination(
            title: "Create Calendar Vault",
            message: "Choose a name and location for this independent, password-protected vault file.",
            name: "Kansolendar",
            type: kansoType
        ) else { return nil }
        let url = selected.pathExtension.lowercased() == "kanso" ? selected : selected.appendingPathExtension("kanso")
        guard !FileManager.default.fileExists(atPath: url.path) else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "A file already exists at that location."
            alert.informativeText = "Choose a different name. Kansolendar will never overwrite an existing vault file."
            alert.runModal()
            return nil
        }
        return url
    }

    static func chooseKansoToOpen() -> URL? {
        let (panel, filter) = makeKansoOpenPanel()
        return withExtendedLifetime(filter) {
            guard panel.runModal() == .OK, let url = panel.url, KansoOpenPanelFilter.accepts(url) else { return nil }
            return url
        }
    }

    /// Configuration is shared by the actual dialog and native-panel verification.
    static func makeKansoOpenPanel() -> (NSOpenPanel, KansoOpenPanelFilter) {
        let panel = NSOpenPanel()
        panel.title = "Open Calendar Vault"
        panel.message = "Choose a .kanso file. Each file has its own password."
        panel.allowedContentTypes = [.item]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.resolvesAliases = false
        let filter = KansoOpenPanelFilter()
        panel.delegate = filter
        return (panel, filter)
    }

    private static func chooseDestination(title: String, message: String, name: String, type: UTType) -> URL? {
        let panel = NSSavePanel()
        panel.title = title
        panel.message = message
        panel.allowedContentTypes = [type]
        // AppKit manages the extension; provide only the base name after the type.
        panel.nameFieldStringValue = name
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.showsTagField = false
        return panel.runModal() == .OK ? panel.url : nil
    }


}

/// Finder metadata can identify an unregistered .kanso as generic data. Check the
/// extension directly instead of depending on LaunchServices type registration.
@MainActor
final class KansoOpenPanelFilter: NSObject, NSOpenSavePanelDelegate {
    static func accepts(_ url: URL) -> Bool {
        url.isFileURL && url.pathExtension.lowercased() == "kanso"
    }

    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { return true }
        return Self.accepts(url)
    }
}
