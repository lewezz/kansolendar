import Foundation
import KansolendarCore

public enum VaultState: Sendable, Equatable {
    case notCreated, locked, unlocking, unlocked, corrupt
}

public enum VaultError: Error, Sendable, Equatable {
    case vaultNotCreated, vaultAlreadyCreated, locked, authenticationFailed
    case corruptVault, unsupportedFormat, storageUnavailable, conflict, duplicateUID
    case timeZoneRulesChanged, invalidInput, queryLimitExceeded, fileInUse, fileChanged
}

/// Password-only boundary for one current-format encrypted document. Domain values
/// cross this actor; keys and decrypted serialization never reach the app layer.
public actor KansolendarVault {
    private var storage: PortableVaultDatabase?
    private var activeStorage: PortableVaultDatabase {
        get throws {
            guard let storage else { throw VaultError.locked }
            return storage
        }
    }

    public init(portableFileURL url: URL, createNew: Bool = false) throws {
        guard url.isFileURL, url.pathExtension.lowercased() == "kanso" else { throw VaultError.invalidInput }
        do { storage = try PortableVaultDatabase(url: url, createNew: createNew) }
        catch { throw Self.map(error) }
    }

    public func state() async throws -> VaultState {
        guard let storage else { return .locked }
        return await storage.state()
    }

    @discardableResult
    public func createPasswordVault(password: String) async throws -> UUID {
        guard VaultPassword.isAcceptable(password) else { throw VaultError.invalidInput }
        do { return try await activeStorage.create(password: password) }
        catch { throw Self.map(error) }
    }

    public func unlock(password: String) async throws {
        guard VaultPassword.isAcceptable(password) else {
            await storage?.lock()
            throw VaultError.authenticationFailed
        }
        do { try await activeStorage.unlock(password: password) }
        catch { throw Self.map(error) }
    }

    public func lock() async { await storage?.lock() }

    /// Closing releases the stable writer lease as well as the decrypted session.
    public func close() async {
        let current = storage
        storage = nil
        await current?.lock()
    }

    public func save(_ calendar: LocalCalendar) async throws {
        do { try await activeStorage.saveCalendar(calendar) }
        catch { throw Self.map(error) }
    }

    public func save(_ event: Event, recurrence: RecurrenceRule? = nil, cancellations: Set<EventOccurrenceKey> = []) async throws {
        do { try await activeStorage.saveEvent(event, recurrence: recurrence, cancellations: cancellations) }
        catch { throw Self.map(error) }
    }

    public func calendars() async throws -> [LocalCalendar] {
        do { return try await activeStorage.calendars() }
        catch { throw Self.map(error) }
    }

    public func events() async throws -> [VaultEvent] {
        do { return try await activeStorage.events() }
        catch { throw Self.map(error) }
    }

    public func deleteEvent(id: UUID) async throws {
        do { try await activeStorage.removeEvent(id: id) }
        catch { throw Self.map(error) }
    }

    public func deleteCalendar(id: UUID) async throws {
        do { try await activeStorage.removeCalendar(id: id) }
        catch { throw Self.map(error) }
    }

    public func events(matching query: EventSearchQuery) async throws -> [VaultEvent] {
        do { return try Self.search(await activeStorage.events(), query: query) }
        catch { throw Self.map(error) }
    }

    private static func search(_ values: [VaultEvent], query: EventSearchQuery) throws -> [VaultEvent] {
        let needle = EventSearch.normalized(query.text ?? "")
        let engine = RecurrenceEngine()
        return try values.filter { item in
            if let ids = query.calendarIDs, !ids.contains(item.event.calendarID) { return false }
            if !needle.isEmpty, !EventSearch.normalized(item.event.title).contains(needle) { return false }
            if let recurrence = item.recurrence {
                return try !engine.expand(RecurringSeries(event: item.event, rule: recurrence, cancellations: item.cancellations), in: query.timeRange).isEmpty
            }
            return !EventSearch.matching([item.event], query: query).isEmpty
        }.sorted { $0.event.id.uuidString < $1.event.id.uuidString }
    }


    private static func map(_ error: Error) -> VaultError {
        switch error {
        case let error as VaultError: error
        case VaultStorageError.fileInUse: .fileInUse
        case VaultStorageError.fileChanged: .fileChanged
        case VaultStorageError.vaultNotCreated: .vaultNotCreated
        case VaultStorageError.vaultAlreadyCreated: .vaultAlreadyCreated
        case VaultStorageError.locked: .locked
        case VaultStorageError.corruptVault, PasswordKeyWrappingError.invalidKeyMaterial, is DecodingError: .corruptVault
        case VaultPayloadCodecError.unsupportedVersion: .unsupportedFormat
        case VaultStorageError.missingRecord, PrivateFileError.destinationExists: .conflict
        case VaultStorageError.duplicateUID: .duplicateUID
        case VaultPayloadCodecError.timeZoneRulesChanged: .timeZoneRulesChanged
        case VaultStorageError.authenticationFailed: .authenticationFailed
        case DomainValidationError.queryLimitExceeded, DomainValidationError.candidateLimitExceeded, DomainValidationError.occurrenceLimitExceeded: .queryLimitExceeded
        case VaultStorageError.invalidInput, VaultPayloadCodecError.invalidPayload, is DomainValidationError: .invalidInput
        default: .storageUnavailable
        }
    }
}
