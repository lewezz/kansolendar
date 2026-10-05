import AppKit
import Combine
import Foundation
import SwiftUI
import KansolendarCore

enum VaultLockSettings {
    static let storageKey = "vaultIdleLockMinutes"
    static let choices = VaultIdlePolicy.minuteChoices
    static var minutes: Int {
        let stored = UserDefaults.standard.integer(forKey: storageKey)
        return VaultIdlePolicy.validatedMinutes(stored)
    }
}

/// Tracks input only for this window. Switching applications is not a lock event.
/// Storage writes are committed before model methods return, so locking never
/// schedules a plaintext flush or discards a partially persisted transaction.
@MainActor
final class VaultLifecycle {
    private weak var model: VaultViewModel?
    private var monitor: Any?
    private var timer: Timer?
    private var sleepSubscription: AnyCancellable?
    private var screenLockObserver: NSObjectProtocol?
    private var closeObserver: NSObjectProtocol?
    private var lastActivity: Double
    private let now: @MainActor () -> Double
    private let minutes: @MainActor () -> Int
    private let screenNotifications: NotificationCenter
    var windowNumber: Int?

    init(
        model: VaultViewModel,
        now: @escaping @MainActor () -> Double = { ProcessInfo.processInfo.systemUptime },
        minutes: @escaping @MainActor () -> Int = { VaultLockSettings.minutes },
        workspaceNotifications: NotificationCenter = NSWorkspace.shared.notificationCenter,
        screenNotifications: NotificationCenter = DistributedNotificationCenter.default()
    ) {
        self.model = model
        self.now = now
        self.minutes = minutes
        self.screenNotifications = screenNotifications
        lastActivity = now()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .mouseMoved, .leftMouseDragged, .scrollWheel]) { [weak self] event in
            MainActor.assumeIsolated {
                if let self, event.windowNumber == self.windowNumber { self.recordActivity() }
            }
            return event
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkIdle() }
        }
        sleepSubscription = workspaceNotifications.publisher(for: NSWorkspace.willSleepNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in MainActor.assumeIsolated { self?.model?.lock() } }
        screenLockObserver = screenNotifications.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.model?.lock() }
        }
    }

    func attach(to window: NSWindow) {
        guard windowNumber != window.windowNumber else { return }
        windowNumber = window.windowNumber
        window.acceptsMouseMovedEvents = true
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.model?.closeDocument() }
        }
    }

    func recordActivity() { lastActivity = now() }

    func checkIdle() {
        guard let model, model.vaultState == .unlocked || model.passwordSheet != nil || !model.passwordInput.isEmpty || !model.passwordConfirmation.isEmpty else { recordActivity(); return }
        if VaultIdlePolicy.shouldLock(elapsedSeconds: now() - lastActivity, minutes: minutes()) {
            model.lock()
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        timer?.invalidate()
        timer = nil
        sleepSubscription = nil
        if let screenLockObserver { screenNotifications.removeObserver(screenLockObserver) }
        screenLockObserver = nil
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = nil
    }
}

/// Obtain the actual hosting window without using the globally key window, which
/// would mix activity and close handling between independent vaults.
struct VaultWindowAttachment: NSViewRepresentable {
    let model: VaultViewModel

    final class AttachmentView: NSView {
        var model: VaultViewModel?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { model?.attach(to: window) }
        }
    }

    func makeNSView(context: Context) -> AttachmentView {
        let view = AttachmentView()
        view.model = model
        return view
    }

    func updateNSView(_ nsView: AttachmentView, context: Context) {
        if let window = nsView.window { model.attach(to: window) }
    }
}

/// Opt-in only: bookmark history may reveal filenames and paths. It contains no
/// credentials or calendar content, and is erased when the preference is disabled.
@MainActor
enum VaultRecentFiles {
    static let enabledKey = "rememberRecentVaultFiles"
    static let entriesKey = "recentVaultBookmarks"

    static func remember(_ url: URL) {
        guard UserDefaults.standard.bool(forKey: enabledKey),
              let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) else { return }
        var entries = UserDefaults.standard.array(forKey: entriesKey) as? [Data] ?? []
        entries.removeAll { resolve($0)?.standardizedFileURL == url.standardizedFileURL }
        entries.insert(bookmark, at: 0)
        UserDefaults.standard.set(Array(entries.prefix(10)), forKey: entriesKey)
    }

    static var urls: [URL] {
        guard UserDefaults.standard.bool(forKey: enabledKey) else { return [] }
        let entries = UserDefaults.standard.array(forKey: entriesKey) as? [Data] ?? []
        return entries.compactMap(resolve)
    }

    private static func resolve(_ bookmark: Data) -> URL? {
        var stale = false
        return try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: entriesKey) }
}

@MainActor
enum VaultPasswordClipboard {
    /// Current-host-only prevents Universal Clipboard propagation. Never erase a
    /// newer copy operation just because our password's expiry timer has fired.
    static func copy(_ password: String, to pasteboard: NSPasteboard = .general, lifetime: Duration = .seconds(30)) {
        pasteboard.prepareForNewContents(with: .currentHostOnly)
        pasteboard.setString(password, forType: .string)
        pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        let generation = pasteboard.changeCount
        Task { @MainActor in
            try? await Task.sleep(for: lifetime)
            if pasteboard.changeCount == generation { pasteboard.clearContents() }
        }
    }
}
