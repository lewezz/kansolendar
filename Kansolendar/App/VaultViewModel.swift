import AppKit
import Foundation
import KansolendarCore
import KansolendarStorage
import Observation

enum VaultPasswordSheet: String, Identifiable {
    case save
    case restore

    var id: String { rawValue }
}

/// One window owns one vault and its decrypted presentation state.
/// Cryptography and persistence remain behind KansolendarVault's actor boundary.
@MainActor
@Observable
final class VaultViewModel {
    // MARK: - Document and presentation state

    private var vault: KansolendarVault?
    let portableFileURL: URL?
    private var hasDocumentAccess = false
    var isPortableDocument: Bool { portableFileURL != nil }
    var displayName: String? { portableFileURL?.deletingPathExtension().lastPathComponent }
    var requiresPassword: Bool { isPortableDocument }
    private(set) var vaultState: VaultState?
    private(set) var isBusy = false
    var passwordInput = ""
    var passwordConfirmation = ""
    var passwordToSave: String?
    var passwordSheet: VaultPasswordSheet?
    private var pendingRestore: (backupURL: URL, recoveryKitURL: URL)?
    @ObservationIgnored private var sessionOperationID = UUID()
    @ObservationIgnored private var contentLoadID = UUID()
    var canCreatePassword: Bool {
        VaultPassword.isAcceptable(passwordInput) && passwordInput == passwordConfirmation
    }
    private(set) var calendars: [LocalCalendar] = []
    private(set) var events: [VaultEvent] = []
    private(set) var isLoadingContent = false
    private(set) var isExporting = false
    var message: String?
    private var hasAttemptedAutomaticUnlock = false

    // MARK: - Document lifecycle and authentication

    init(portableFileURL: URL? = nil) {
        self.portableFileURL = portableFileURL
        if portableFileURL == nil {
            do {
                vault = try KansolendarVault()
            } catch {
                vault = nil
                message = "Local storage could not be prepared. No personal information was saved."
            }
        }
        // Portable files are opened in start(), after acquiring security-scoped access.
    }

    func start() async {
        if let portableFileURL {
            if !hasDocumentAccess {
                hasDocumentAccess = portableFileURL.startAccessingSecurityScopedResource()
            }
            if vault == nil, FileManager.default.fileExists(atPath: portableFileURL.path) {
                do {
                    vault = try KansolendarVault(portableFileURL: portableFileURL)
                } catch {
                    message = "This .kanso file is invalid or could not be opened. Its contents were not changed."
                    vaultState = .corrupt
                    return
                }
            }
        }
        guard vault != nil else {
            if isPortableDocument { vaultState = .notCreated }
            return
        }
        await refresh()
        guard !requiresPassword else { return }
        guard vaultState == .locked, !hasAttemptedAutomaticUnlock else { return }
        hasAttemptedAutomaticUnlock = true
        unlock()
    }

    func refresh() async {
        guard let vault else { return }
        let operationID = sessionOperationID
        do {
            let state = try await vault.state()
            guard sessionOperationID == operationID else { return }
            vaultState = state
        } catch let error as VaultError {
            guard sessionOperationID == operationID else { return }
            message = error.userMessage
        } catch {
            guard sessionOperationID == operationID else { return }
            message = "The local vault state could not be read."
        }
    }

    func createVault() {
        guard !isBusy, !requiresPassword || canCreatePassword else { return }
        let targetVault: KansolendarVault
        if let vault {
            targetVault = vault
        } else if let portableFileURL {
            do {
                targetVault = try KansolendarVault(portableFileURL: portableFileURL, createNew: true)
                vault = targetVault
            } catch {
                message = "The .kanso file could not be created. Choose another name or location."
                return
            }
        } else {
            return
        }
        let password = passwordInput
        let validPassword = canCreatePassword
        let operationID = sessionOperationID
        isBusy = true
        message = nil
        Task {
            defer { if sessionOperationID == operationID { isBusy = false } }
            do {
                if requiresPassword {
                    guard validPassword else { throw VaultError.invalidInput }
                    _ = try await targetVault.createPasswordVault(password: password)
                } else {
                    _ = try await targetVault.createVault()
                }
                let state = try await targetVault.state()
                // Closing or locking while creation suspends must not restore password presentation.
                guard sessionOperationID == operationID else { return }
                if requiresPassword {
                    passwordToSave = password
                    passwordSheet = .save
                    passwordInput = ""
                    passwordConfirmation = ""
                }
                vaultState = state
                await loadContent()
            } catch let error as VaultError {
                guard sessionOperationID == operationID else { return }
                message = error.userMessage
                await refresh()
            } catch {
                guard sessionOperationID == operationID else { return }
                message = "The private vault could not be created. No personal information was saved."
                await refresh()
            }
        }
    }

    func unlock(password: String = "") {
        guard let vault, !isBusy else { return }
        let operationID = sessionOperationID
        isBusy = true
        message = nil
        vaultState = .unlocking
        Task {
            defer { if sessionOperationID == operationID { isBusy = false } }
            do {
                if requiresPassword { try await vault.unlock(password: password) }
                else { try await vault.unlock() }
                let state = try await vault.state()
                guard sessionOperationID == operationID else { return }
                passwordInput = ""
                vaultState = state
                await loadContent()
            } catch let error as VaultError {
                guard sessionOperationID == operationID else { return }
                passwordInput = ""
                message = error.userMessage
                await refresh()
            } catch {
                guard sessionOperationID == operationID else { return }
                passwordInput = ""
                message = "The local vault could not be unlocked."
                await refresh()
            }
        }
    }

    func openPasswords() {
        let app = URL(fileURLWithPath: "/System/Applications/Passwords.app")
        if FileManager.default.fileExists(atPath: app.path) {
            NSWorkspace.shared.open(app)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }

    func finishPasswordPresentation() {
        passwordSheet = nil
        passwordToSave = nil
        passwordInput = ""
        passwordConfirmation = ""
    }

    func closeDocument() {
        guard isPortableDocument else { return }
        let activeVault = vault
        let scopedAccess = hasDocumentAccess
        vault = nil
        hasDocumentAccess = false
        vaultState = .locked
        invalidateSessionPresentation()
        pendingRestore = nil
        Task {
            await activeVault?.lock()
            // Release the captured access claim, not one acquired by a later start().
            if scopedAccess, let portableFileURL {
                portableFileURL.stopAccessingSecurityScopedResource()
            }
        }
    }

    func lock() {
        guard let vault else { return }
        invalidateSessionPresentation()
        vaultState = .locked
        Task {
            await vault.lock()
        }
    }

    // MARK: - Calendar and event operations

    func loadContent() async {
        guard let vault, vaultState == .unlocked else {
            clearPrivateContent()
            return
        }
        let loadID = UUID()
        contentLoadID = loadID
        isLoadingContent = true
        defer { if contentLoadID == loadID { isLoadingContent = false } }
        do {
            async let storedCalendars = vault.calendars()
            async let storedEvents = vault.events()
            let loadedCalendars = try await storedCalendars.sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
            let loadedEvents = try await storedEvents.sorted {
                EventDateAdapter.startDate(for: $0.event) < EventDateAdapter.startDate(for: $1.event)
            }
            // Await points allow locking or a newer load. Publish one complete, current snapshot.
            guard contentLoadID == loadID, vaultState == .unlocked else { return }
            calendars = loadedCalendars
            events = loadedEvents
            message = nil
        } catch let error as VaultError {
            guard contentLoadID == loadID else { return }
            handleContentError(error)
        } catch {
            guard contentLoadID == loadID else { return }
            message = "The local calendar could not be loaded."
        }
    }

    func createCalendar(name: String, color: CalendarColor) async -> Bool {
        guard let vault else { return false }
        do {
            let identifier = TimeZone.autoupdatingCurrent.identifier
            let timeZone = try TimeZoneID(TimeZone.knownTimeZoneIdentifiers.contains(identifier) ? identifier : "UTC")
            let calendar = try LocalCalendar(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                color: color,
                sortOrder: calendars.count,
                defaultTimeZone: timeZone
            )
            try await vault.save(calendar)
            await loadContent()
            return true
        } catch let error as VaultError {
            handleContentError(error)
        } catch {
            message = "The calendar name is not valid."
        }
        return false
    }

    func saveEvent(
        existing: Event?,
        calendarID: UUID,
        title: String,
        notes: String?,
        location: String?,
        start: Date,
        end: Date,
        isAllDay: Bool
    ) async -> Bool {
        guard let vault else { return false }
        do {
            let eventTime = try EventDateAdapter.eventTime(start: start, end: end, isAllDay: isAllDay)
            let normalizedNotes = Self.optionalText(notes)
            let normalizedLocation = Self.optionalText(location)
            let event: Event
            if var existing {
                try existing.update(
                    title: title,
                    notes: normalizedNotes,
                    location: normalizedLocation,
                    time: eventTime
                )
                event = existing
            } else {
                event = try Event(
                    calendarID: calendarID,
                    title: title,
                    notes: normalizedNotes,
                    location: normalizedLocation,
                    time: eventTime
                )
            }
            try await vault.save(event)
            await loadContent()
            return true
        } catch let error as VaultError {
            handleContentError(error)
        } catch {
            message = "Check the event title and time range."
        }
        return false
    }

    func deleteEvent(id: UUID) async -> Bool {
        guard let vault else { return false }
        do {
            try await vault.deleteEvent(id: id)
            await loadContent()
            return true
        } catch let error as VaultError {
            handleContentError(error)
        } catch {
            message = "The event could not be deleted."
        }
        return false
    }

    func moveEvent(id: UUID, to date: CivilDate) async -> Bool {
        guard let vault, let stored = events.first(where: { $0.event.id == id }) else { return false }
        guard stored.recurrence == nil else {
            message = "Recurring series must be moved from their editor to avoid ambiguous changes."
            return false
        }
        do {
            var event = stored.event
            try event.update(
                title: event.title,
                notes: event.notes,
                location: event.location,
                time: event.time.moved(to: date)
            )
            try await vault.save(event)
            await loadContent()
            return true
        } catch let error as VaultError {
            handleContentError(error)
        } catch {
            message = "The event could not be moved to that day. Check the time-zone transition."
        }
        return false
    }

    func deleteCalendar(id: UUID) async -> Bool {
        guard let vault else { return false }
        do {
            try await vault.deleteCalendar(id: id)
            await loadContent()
            return true
        } catch let error as VaultError {
            handleContentError(error)
        } catch {
            message = "The calendar could not be deleted."
        }
        return false
    }

    // MARK: - Backups, recovery, and interchange

    func createBackup(at url: URL) async {
        guard let vault else { return }
        isExporting = true
        defer { isExporting = false }
        let scopedAccess = url.startAccessingSecurityScopedResource()
        defer { if scopedAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            try await vault.createBackup(at: url)
            message = "Encrypted backup saved. Keep the recovery kit separately."
        } catch let error as VaultError {
            message = error == .conflict
                ? "That file already exists. Choose a new name to preserve the previous backup."
                : error.userMessage
        } catch {
            message = "The encrypted backup could not be created."
        }
    }

    func exportRecoveryKit(at url: URL) async {
        guard let vault else { return }
        isExporting = true
        defer { isExporting = false }
        let scopedAccess = url.startAccessingSecurityScopedResource()
        defer { if scopedAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            try await vault.exportRecoveryKit(at: url)
            message = "Recovery kit saved. Do not store it with the backup."
        } catch let error as VaultError {
            message = error == .conflict
                ? "That file already exists. Choose a new name instead of overwriting it."
                : error.userMessage
        } catch {
            message = "The recovery kit could not be exported."
        }
    }

    func prepareRestoreBackup(at backupURL: URL, recoveryKitURL: URL) {
        pendingRestore = (backupURL, recoveryKitURL)
        passwordInput = ""
        passwordConfirmation = ""
        passwordSheet = .restore
    }

    func restoreBackup(at backupURL: URL, recoveryKitURL: URL) async {
        if requiresPassword {
            prepareRestoreBackup(at: backupURL, recoveryKitURL: recoveryKitURL)
            return
        }
        guard let vault else { return }
        isExporting = true
        defer { isExporting = false }
        let backupAccess = backupURL.startAccessingSecurityScopedResource()
        let kitAccess = recoveryKitURL.startAccessingSecurityScopedResource()
        defer {
            if backupAccess { backupURL.stopAccessingSecurityScopedResource() }
            if kitAccess { recoveryKitURL.stopAccessingSecurityScopedResource() }
        }
        do {
            try await vault.restoreBackup(at: backupURL, recoveryKitURL: recoveryKitURL)
            vaultState = try await vault.state()
            await loadContent()
            message = "Encrypted backup restored and verified."
        } catch let error as VaultError {
            if error == .restoreRecoveryRequired {
                vaultState = .corrupt
            } else {
                vaultState = (try? await vault.state()) ?? .corrupt
            }
            if vaultState != .unlocked { clearPrivateContent() }
            message = error == .corruptVault
                ? "The backup or recovery kit is invalid or does not match. Your current vault was preserved."
                : error.userMessage
        } catch {
            vaultState = (try? await vault.state()) ?? .corrupt
            if vaultState != .unlocked { clearPrivateContent() }
            message = "The backup could not be restored. Keep your backup and recovery kit."
        }
    }

    func restorePendingBackup() {
        guard let selection = pendingRestore,
              canCreatePassword, !isExporting, let vault else { return }
        let backupURL = selection.backupURL
        let recoveryKitURL = selection.recoveryKitURL
        let password = passwordInput
        let operationID = sessionOperationID
        isExporting = true
        Task {
            defer { if sessionOperationID == operationID { isExporting = false } }
            let backupAccess = backupURL.startAccessingSecurityScopedResource()
            let kitAccess = recoveryKitURL.startAccessingSecurityScopedResource()
            defer {
                if backupAccess { backupURL.stopAccessingSecurityScopedResource() }
                if kitAccess { recoveryKitURL.stopAccessingSecurityScopedResource() }
            }
            do {
                try await vault.restoreBackup(at: backupURL, recoveryKitURL: recoveryKitURL, password: password)
                let state = try await vault.state()
                guard sessionOperationID == operationID else { return }
                vaultState = state
                await loadContent()
                guard sessionOperationID == operationID, vaultState == .unlocked else { return }
                passwordToSave = password
                passwordInput = ""
                passwordConfirmation = ""
                pendingRestore = nil
                passwordSheet = .save
                message = "Encrypted backup restored and verified. Save the new vault password."
            } catch let error as VaultError {
                guard sessionOperationID == operationID else { return }
                message = error.userMessage
                await refresh()
            } catch {
                guard sessionOperationID == operationID else { return }
                message = "The backup could not be restored. Keep your backup and recovery kit."
                await refresh()
            }
        }
    }

    func exportCalendar(id: UUID, to url: URL) async {
        guard let vault else { return }
        isExporting = true
        defer { isExporting = false }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            try await vault.exportCalendar(id: id, to: url)
            message = "Calendar exported as an unencrypted iCalendar file."
        } catch let error as VaultError {
            message = error == .conflict ? "That file already exists. Choose a new name." : error.userMessage
        } catch {
            message = "The calendar could not be exported."
        }
    }

    func importCalendarEvents(from url: URL, into calendarID: UUID) async {
        guard let vault else { return }
        isExporting = true
        defer { isExporting = false }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let count = try await vault.importCalendarEvents(from: url, into: calendarID)
            await loadContent()
            message = "Imported \(count) \(count == 1 ? "event" : "events") safely."
        } catch let error as VaultError {
            message = error == .duplicateUID
                ? "Import cancelled because an event UID already exists. No events were added."
                : "This iCalendar file contains invalid or unsupported data. No events were added."
        } catch {
            message = "The calendar could not be imported. No events were added."
        }
    }

    // MARK: - Private presentation helpers

    private func invalidateSessionPresentation() {
        // Storage has its own key-generation checks; this token guards only suspended UI work.
        sessionOperationID = UUID()
        isBusy = false
        isExporting = false
        finishPasswordPresentation()
        clearPrivateContent()
    }

    private func clearPrivateContent() {
        // Invalidate suspended loads so they cannot repopulate a locked or closed window.
        contentLoadID = UUID()
        isLoadingContent = false
        calendars = []
        events = []
    }

    private func handleContentError(_ error: VaultError) {
        message = error.userMessage
        if error == .locked || error == .authenticationCancelled || error == .authenticationFailed {
            invalidateSessionPresentation()
            vaultState = .locked
        } else if error == .corruptVault || error == .restoreRecoveryRequired {
            invalidateSessionPresentation()
            vaultState = .corrupt
        }
    }

    private static func optionalText(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
