import Foundation
import KansolendarCore

public enum VaultState: Sendable, Equatable {
    case notCreated
    case locked
    case unlocking
    case unlocked
    case recoveryRequired
    case corrupt
}

public enum VaultError: Error, Sendable, Equatable {
    case vaultNotCreated
    case vaultAlreadyCreated
    case locked
    case recoveryRequired
    case authenticationCancelled
    case authenticationFailed
    case keychainUnavailable
    case corruptVault
    case unsupportedFormat
    case storageUnavailable
    case conflict
    case duplicateUID
    case timeZoneRulesChanged
    case unlockInProgress
    case invalidInput
}

/// Public app-facing boundary for the local encrypted vault. It exposes domain values
/// and safe error categories, never database handles, Keychain attributes, or keys.
public actor KansolendarVault {
    private let storage: SQLiteVaultDatabase

    public init() throws {
        do {
            let url = try VaultDatabaseLocation.applicationSupportURL()
            storage = try SQLiteVaultDatabase(path: url.path)
        } catch {
            throw Self.map(error)
        }
    }

    internal init(storage: SQLiteVaultDatabase) {
        self.storage = storage
    }

    public func state() async throws -> VaultState {
        do {
            try await storage.migrate()
            return Self.map(await storage.vaultState())
        } catch {
            throw Self.map(error)
        }
    }

    @discardableResult
    public func createVault() async throws -> UUID {
        do {
            return try await storage.createVault()
        } catch {
            throw Self.map(error)
        }
    }

    public func unlock() async throws {
        do {
            try await storage.unlockVault()
        } catch {
            throw Self.map(error)
        }
    }

    public func lock() async {
        await storage.lockVault()
    }

    public func save(_ calendar: LocalCalendar) async throws {
        do {
            try await storage.saveCalendar(calendar)
        } catch {
            throw Self.map(error)
        }
    }

    public func save(
        _ event: Event,
        recurrence: RecurrenceRule? = nil,
        cancellations: Set<EventOccurrenceKey> = []
    ) async throws {
        do {
            try await storage.saveEvent(event, recurrence: recurrence, cancellations: cancellations)
        } catch {
            throw Self.map(error)
        }
    }

    public func calendars() async throws -> [LocalCalendar] {
        do {
            return try await storage.calendars()
        } catch {
            throw Self.map(error)
        }
    }

    public func events() async throws -> [VaultEvent] {
        do {
            return try await storage.events()
        } catch {
            throw Self.map(error)
        }
    }

    public func deleteEvent(id: UUID) async throws {
        do {
            try await storage.removeEvent(id: id)
        } catch {
            throw Self.map(error)
        }
    }

    public func deleteCalendar(id: UUID) async throws {
        do {
            try await storage.removeCalendar(id: id)
        } catch {
            throw Self.map(error)
        }
    }

    private static func map(_ state: VaultAccessState) -> VaultState {
        switch state {
        case .notCreated: .notCreated
        case .locked: .locked
        case .unlocking: .unlocking
        case .unlocked: .unlocked
        case .recoveryRequired: .recoveryRequired
        case .corrupt: .corrupt
        }
    }

    private static func map(_ error: Error) -> VaultError {
        switch error {
        case VaultStorageError.vaultNotCreated:
            .vaultNotCreated
        case VaultStorageError.vaultAlreadyCreated:
            .vaultAlreadyCreated
        case VaultStorageError.locked, VaultKeySessionError.locked, VaultKeySessionError.staleGeneration:
            .locked
        case VaultStorageError.recoveryRequired, VaultKeyStoreError.missingKey:
            .recoveryRequired
        case VaultKeyStoreError.userCancelled:
            .authenticationCancelled
        case VaultKeyStoreError.accessDenied:
            .authenticationFailed
        case VaultKeyStoreError.missingEntitlement,
             VaultKeyStoreError.interactionNotAllowed,
             VaultKeyStoreError.keychainFailure,
             VaultKeyStoreError.accessControlCreationFailed:
            .keychainUnavailable
        case VaultKeyStoreError.invalidKeyMaterial:
            .corruptVault
        case VaultKeyStoreError.keyAlreadyExists, SQLiteVaultError.missingRecord:
            .conflict
        case VaultStorageError.corruptVault,
             SQLiteVaultError.integrityFailure,
             SQLiteVaultError.schemaMismatch,
             SQLiteVaultError.invalidIdentifier,
             SQLiteVaultError.invalidEnvelope,
             PayloadEnvelopeError.malformed,
             PayloadEnvelopeError.authenticationFailed,
             PayloadEnvelopeError.payloadTooLarge:
            .corruptVault
        case SQLiteVaultError.unsupportedSchemaVersion,
             PayloadEnvelopeError.unsupportedVersion,
             VaultPayloadCodecError.unsupportedVersion:
            .unsupportedFormat
        case SQLiteVaultError.constraintViolation:
            .conflict
        case VaultStorageError.duplicateUID:
            .duplicateUID
        case VaultStorageError.timeZoneRulesChanged, VaultPayloadCodecError.timeZoneRulesChanged:
            .timeZoneRulesChanged
        case VaultStorageError.unlockInProgress, VaultStorageError.unlockSuperseded:
            .unlockInProgress
        case is DomainValidationError, VaultPayloadCodecError.invalidPayload:
            .invalidInput
        default:
            .storageUnavailable
        }
    }
}
