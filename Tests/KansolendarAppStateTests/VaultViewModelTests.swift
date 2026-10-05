import Foundation
import AppKit
import KansolendarStorage
@testable import KansolendarAppState
import Testing

@Suite("Vault presentation privacy", .serialized)
@MainActor
struct VaultViewModelTests {
    private func waitUntilIdle(_ model: VaultViewModel) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while model.isBusy {
            guard ContinuousClock.now < deadline else { throw TestFailure.timeout }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private enum TestFailure: Error { case timeout }
    private final class TestClock { var seconds = 0.0 }

    @Test("locking queued creation never restores an unlocked session or password sheet")
    func lockDuringCreation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = VaultViewModel(portableFileURL: directory.appendingPathComponent("Synthetic.kanso"))
        defer { model.closeDocument() }
        await model.start()
        let password = "synthetic creation private phrase"
        model.passwordInput = password
        model.passwordConfirmation = password
        model.createVault()
        model.lock()
        try await waitUntilIdle(model)
        #expect(model.vaultState == .locked)
        #expect(model.passwordInput.isEmpty)
        #expect(model.passwordToSave == nil)
        #expect(model.passwordSheet == nil)
        #expect(model.calendars.isEmpty)
        model.unlock(password: password)
        try await waitUntilIdle(model)
        #expect(model.vaultState == .unlocked)
    }

    @Test("independent unlocked documents keep contents, passwords and locking separate")
    func independentSessions() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = VaultViewModel(portableFileURL: directory.appendingPathComponent("First.kanso"))
        let second = VaultViewModel(portableFileURL: directory.appendingPathComponent("Second.kanso"))
        defer { first.closeDocument(); second.closeDocument() }
        for (model, password) in [(first, "synthetic first independent phrase"), (second, "synthetic second independent phrase")] {
            await model.start()
            model.passwordInput = password
            model.passwordConfirmation = password
            model.createVault()
            try await waitUntilIdle(model)
        }
        #expect(await first.createCalendar(name: "Only first", color: .blue))
        #expect(await second.createCalendar(name: "Only second", color: .blue))
        #expect(first.calendars.map(\.name) == ["Only first"])
        #expect(second.calendars.map(\.name) == ["Only second"])
        first.lock()
        try await waitUntilIdle(first)
        #expect(first.calendars.isEmpty)
        #expect(second.vaultState == .unlocked)
        #expect(second.calendars.map(\.name) == ["Only second"])
        first.unlock(password: "synthetic second independent phrase")
        try await waitUntilIdle(first)
        #expect(first.vaultState == .locked)
        #expect(first.calendars.isEmpty)
        first.unlock(password: "synthetic first independent phrase")
        try await waitUntilIdle(first)
        #expect(first.calendars.map(\.name) == ["Only first"])
        #expect(second.calendars.map(\.name) == ["Only second"])
    }

    @Test("new password presentation is concealed and cleared on dismissal or lock")
    func passwordVisibility() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = VaultViewModel(portableFileURL: directory.appendingPathComponent("Synthetic.kanso"))
        defer { model.closeDocument() }
        await model.start()
        model.passwordInput = "synthetic hidden password phrase"
        model.passwordConfirmation = model.passwordInput
        model.createVault()
        try await waitUntilIdle(model)
        #expect(!model.isPasswordRevealed)
        #expect(model.passwordSheet == .save)
        #expect(model.passwordToSave != nil)
        model.isPasswordRevealed = true
        model.finishPasswordPresentation()
        #expect(!model.isPasswordRevealed)
        #expect(model.passwordToSave == nil)
        #expect(model.passwordSheet == nil)
        model.isPasswordRevealed = true
        model.lock()
        #expect(!model.isPasswordRevealed)
        try await waitUntilIdle(model)
    }

    @Test("open panel enables current-extension files regardless of registered type")
    func fileSelection() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (panel, filter) = VaultFilePanel.makeKansoOpenPanel()
        #expect(panel.allowedContentTypes.map(\.identifier) == ["public.item"])
        #expect(panel.canChooseFiles && !panel.canChooseDirectories)
        #expect(filter.panel(panel, shouldEnable: directory))
        for name in ["Personal.kanso", "Work.KANSO", "Unregistered.kanso"] {
            let url = directory.appendingPathComponent(name)
            try Data().write(to: url)
            #expect(KansoOpenPanelFilter.accepts(url))
            #expect(filter.panel(NSOpenPanel(), shouldEnable: url))
        }
        for name in ["old.sqlite", "calendar.ics", "old.kansobackup", "readme.txt"] {
            let url = directory.appendingPathComponent(name)
            try Data().write(to: url)
            #expect(!filter.panel(NSOpenPanel(), shouldEnable: url))
        }
        #expect(!KansoOpenPanelFilter.accepts(URL(string: "https://example.test/file.kanso")!))
    }

    @Test("chooser never automatically opens or authenticates a local vault")
    func chooser() async {
        let model = VaultViewModel()
        await model.start()
        #expect(model.vaultState == nil)
        #expect(model.calendars.isEmpty)
        #expect(model.events.isEmpty)
        #expect(!model.isBusy)
    }

    @Test("external write failure clears decrypted presentation and passwords")
    func failedWriteLocksPresentation() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("Synthetic.kanso")
        let model = VaultViewModel(portableFileURL: url)
        await model.start()
        model.passwordInput = "synthetic private calendar phrase"
        model.passwordConfirmation = model.passwordInput
        model.createVault()
        try await waitUntilIdle(model)
        #expect(model.vaultState == .unlocked)
        #expect(await model.createCalendar(name: "Synthetic private data", color: .blue))
        #expect(model.calendars.count == 1)
        var modified = try Data(contentsOf: url)
        modified[modified.count - 1] ^= 1
        try modified.write(to: url)
        #expect(await !model.createCalendar(name: "Should not commit", color: .blue))
        #expect(model.vaultState == .locked)
        #expect(model.calendars.isEmpty)
        #expect(model.events.isEmpty)
        #expect(model.passwordToSave == nil)
        #expect(model.passwordSheet == nil)
        #expect(try Data(contentsOf: url) == modified)
        model.closeDocument()
    }

    @Test("manual lock clears private state and allows a new password session")
    func lockAndUnlock() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let model = VaultViewModel(portableFileURL: dir.appendingPathComponent("Synthetic.kanso"))
        await model.start()
        let password = "synthetic private calendar phrase"
        model.passwordInput = password
        model.passwordConfirmation = password
        model.createVault()
        try await waitUntilIdle(model)
        #expect(await model.createCalendar(name: "Survives locking", color: .blue))
        model.lock()
        #expect(model.calendars.isEmpty)
        #expect(model.passwordToSave == nil)
        try await waitUntilIdle(model)
        model.unlock(password: password)
        try await waitUntilIdle(model)
        #expect(model.vaultState == .unlocked)
        #expect(model.calendars.count == 1)
        model.closeDocument()
    }
    @Test("idle, sleep and screen-lock events lock; application switching does not")
    func lifecycleLocks() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let model = VaultViewModel(portableFileURL: dir.appendingPathComponent("Synthetic.kanso"))
        await model.start()
        let password = "synthetic private calendar phrase"
        model.passwordInput = password
        model.passwordConfirmation = password
        model.createVault()
        try await waitUntilIdle(model)
        let clock = TestClock()
        let workspace = NotificationCenter()
        let screen = NotificationCenter()
        let lifecycle = VaultLifecycle(model: model, now: { clock.seconds }, minutes: { 1 }, workspaceNotifications: workspace, screenNotifications: screen)
        defer { lifecycle.stop(); model.closeDocument() }
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: nil)
        #expect(model.vaultState == .unlocked)
        clock.seconds = 59
        lifecycle.checkIdle()
        #expect(model.vaultState == .unlocked)
        lifecycle.recordActivity()
        clock.seconds = 118
        lifecycle.checkIdle()
        #expect(model.vaultState == .unlocked)
        clock.seconds = 119
        lifecycle.checkIdle()
        #expect(model.vaultState == .locked)
        try await waitUntilIdle(model)
        model.unlock(password: password)
        try await waitUntilIdle(model)
        screen.post(name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        #expect(model.vaultState == .locked)
        try await waitUntilIdle(model)
        model.unlock(password: password)
        try await waitUntilIdle(model)
        workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        // The real publisher delivers through the main run loop.
        try await Task.sleep(for: .milliseconds(30))
        #expect(model.vaultState == .locked)
        try await waitUntilIdle(model)
    }

    @Test("password clipboard expires without erasing a subsequent user copy")
    func clipboardExpiry() async throws {
        // Isolated test pasteboard; never read or alter the user's clipboard.
        let board = NSPasteboard(name: NSPasteboard.Name("kanso-test-\(UUID().uuidString)"))
        defer { board.releaseGlobally() }
        VaultPasswordClipboard.copy("synthetic password", to: board, lifetime: .milliseconds(10))
        #expect(board.string(forType: .string) == "synthetic password")
        try await Task.sleep(for: .milliseconds(40))
        #expect(board.string(forType: .string) == nil)
        VaultPasswordClipboard.copy("synthetic password", to: board, lifetime: .milliseconds(10))
        board.clearContents()
        board.setString("later copy", forType: .string)
        try await Task.sleep(for: .milliseconds(40))
        #expect(board.string(forType: .string) == "later copy")
    }

}
