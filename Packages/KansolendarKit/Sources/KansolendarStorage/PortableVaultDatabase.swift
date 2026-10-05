import Foundation
import KansolendarCore

/// Serializes one independent, wholly encrypted file. No plaintext persistence or
/// External credential dependency. A mutation becomes visible only after its encrypted save.
internal actor PortableVaultDatabase {
    private let lease: KansoFileLease
    private var document: KansoDocument?
    private var session: KansoFileEnvelope.Session?
    private var savedDigest: Data?
    private var created: Bool

    init(url: URL, createNew: Bool) throws {
        lease = try KansoFileLease(url: url)
        if createNew {
            guard !FileManager.default.fileExists(atPath: lease.path) else { throw PrivateFileError.destinationExists }
            created = false
        } else {
            let data = try lease.read()
            try KansoFileEnvelope.validateStructure(data)
            savedDigest = lease.digest(data)
            created = true
        }
    }

    func state() -> VaultState { !created ? .notCreated : document == nil ? .locked : .unlocked }

    @discardableResult
    func create(password: String) throws -> UUID {
        try Task.checkCancellation()
        guard !created else { throw VaultStorageError.vaultAlreadyCreated }
        let document = KansoDocument()
        let session = try KansoFileEnvelope.createSession(password: password)
        let data = try KansoFileEnvelope.seal(document, session: session)
        try Task.checkCancellation()
        try lease.write(data, replacing: nil)
        savedDigest = lease.digest(data)
        self.document = document
        self.session = session
        created = true
        return document.id
    }

    func unlock(password: String) throws {
        guard created else { throw VaultStorageError.vaultNotCreated }
        lock()
        // No suspension between KDF, authentication and key publication; lock cannot
        // be overtaken by a delayed unlock result within this actor.
        let data = try lease.read()
        let (document, session) = try KansoFileEnvelope.open(data, password: password)
        self.document = document
        self.session = session
        savedDigest = lease.digest(data)
    }

    func lock() { document = nil; session = nil }

    func calendars() throws -> [LocalCalendar] { try unlocked().calendars }
    func events() throws -> [VaultEvent] { try unlocked().events }

    func saveCalendar(_ calendar: LocalCalendar) throws {
        var next = try unlocked()
        if let index = next.calendars.firstIndex(where: { $0.id == calendar.id }) { next.calendars[index] = calendar }
        else { next.calendars.append(calendar) }
        try commit(next)
    }

    func saveEvent(_ event: Event, recurrence: RecurrenceRule?, cancellations: Set<EventOccurrenceKey>) throws {
        var next = try unlocked()
        guard next.calendars.contains(where: { $0.id == event.calendarID }) else { throw VaultStorageError.invalidInput }
        guard !next.events.contains(where: { $0.event.id != event.id && $0.event.calendarID == event.calendarID && $0.event.uid == event.uid }) else {
            throw VaultStorageError.duplicateUID
        }
        let record = VaultEvent(event: event, recurrence: recurrence, cancellations: cancellations)
        if let index = next.events.firstIndex(where: { $0.event.id == event.id }) { next.events[index] = record }
        else { next.events.append(record) }
        try commit(next)
    }

    func removeEvent(id: UUID) throws {
        var next = try unlocked()
        guard next.events.contains(where: { $0.event.id == id }) else { throw VaultStorageError.missingRecord }
        next.events.removeAll { $0.event.id == id }
        try commit(next)
    }

    func removeCalendar(id: UUID) throws {
        var next = try unlocked()
        guard next.calendars.contains(where: { $0.id == id }) else { throw VaultStorageError.missingRecord }
        next.calendars.removeAll { $0.id == id }
        next.events.removeAll { $0.event.calendarID == id }
        try commit(next)
    }

    private func unlocked() throws -> KansoDocument {
        guard let document, session != nil else { throw VaultStorageError.locked }
        return document
    }

    private func commit(_ next: KansoDocument) throws {
        guard let session, let savedDigest else { throw VaultStorageError.locked }
        let data = try KansoFileEnvelope.seal(next, session: session)
        do { try lease.write(data, replacing: savedDigest) }
        catch {
            // A filesystem error after rename can have an ambiguous durability result.
            // Drop secrets and require re-opening instead of presenting stale state.
            lock()
            throw error
        }
        self.savedDigest = lease.digest(data)
        document = next
    }
}
