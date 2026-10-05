import CSQLite
import CryptoKit
import Foundation
import KansolendarCore

internal enum SQLiteVaultError: Error, Equatable, Sendable {
    case openFailed(Int32)
    case filesystemFailure(Int32)
    case unsafeDatabaseFile
    case databaseFailure(Int32)
    case unsupportedSchemaVersion(Int32)
    case schemaMismatch
    case invalidIdentifier
    case invalidEnvelope
    case constraintViolation
    case missingRecord
    case integrityFailure
    case foreignKeyFailure
    case snapshotDestinationExists
    case unsafeSnapshotDestination
    case restoreFailed
    case restoreRollbackFailed
}

internal enum VaultAccessState: Sendable, Equatable {
    case notCreated
    case locked
    case unlocking(UUID)
    case unlocked(UUID)
    case recoveryRequired
    case corrupt
}

internal enum VaultStorageError: Error, Equatable, Sendable {
    case vaultNotCreated
    case vaultAlreadyCreated
    case locked
    case recoveryRequired
    case corruptVault
    case unlockSuperseded
    case timeZoneRulesChanged
    case duplicateUID
    case unlockInProgress
    case authenticationFailed
    case invalidInput
}

internal enum VaultPayloadTable: Sendable {
    case calendar
    case event
    case eventException

    fileprivate var selectSQL: String {
        switch self {
        case .calendar: "SELECT payload_envelope FROM calendars WHERE id = ?1"
        case .event: "SELECT payload_envelope FROM events WHERE id = ?1"
        case .eventException: "SELECT payload_envelope FROM event_exceptions WHERE id = ?1"
        }
    }
}

internal struct VaultMetadata: Sendable, Equatable {
    let vaultID: UUID
    let activeKeyID: UUID
    let controlEnvelope: Data
}

private struct VaultControlPayload: Codable, Sendable {
    let version: Int
    let vaultID: UUID
    let keyID: UUID
}

internal struct VaultCalendarRecord: Sendable, Equatable {
    let id: UUID
    let envelope: Data
}

internal struct VaultEventRecord: Sendable, Equatable {
    let id: UUID
    let calendarID: UUID
    let envelope: Data
}

internal struct VaultExceptionRecord: Sendable, Equatable {
    let id: UUID
    let eventID: UUID
    let envelope: Data
}

/// Serializes access to one SQLite connection. Public-facing storage must pass only
/// UUID relationships and authenticated envelopes, never plaintext business values.
internal actor SQLiteVaultDatabase {
    // MARK: - Schema configuration and session ownership

    static let schemaVersion: Int32 = 1
    private static let portableSchemaVersion: Int32 = 2
    private static let metadataSchemaVersion: Int64 = 1
    private static let portableApplicationID: Int32 = 0x4B414E53 // "KANS"
    static let minimumEnvelopeSize = 33
    static let maximumEnvelopeSize = 131_105

    private let connection: SQLiteConnection
    private let keyStore: any VaultKeyStore
    private let usesEmbeddedPasswordWrapper: Bool
    private var keySession = VaultKeySession()
    private var accessState: VaultAccessState = .locked
    private var activeKeyOperation: UUID?

    init(
        path: String,
        keyStore: any VaultKeyStore = KeychainVaultKeyStore(),
        usesEmbeddedPasswordWrapper: Bool = false,
        createPortableFile: Bool = false
    ) throws {
        self.usesEmbeddedPasswordWrapper = usesEmbeddedPasswordWrapper
        if usesEmbeddedPasswordWrapper && !createPortableFile {
            try SQLiteConnection.validatePortableFile(path: path, applicationID: Self.portableApplicationID)
        }
        connection = try SQLiteConnection(path: path, requireNewFile: createPortableFile)
        self.keyStore = keyStore
        if usesEmbeddedPasswordWrapper && !createPortableFile {
            guard try connection.applicationID() == Self.portableApplicationID else {
                throw SQLiteVaultError.schemaMismatch
            }
        }
        try connection.configure()
        if usesEmbeddedPasswordWrapper && createPortableFile {
            try connection.setPortableApplicationID(Self.portableApplicationID)
        }
    }

    // MARK: - Creation and authentication

    func vaultState() -> VaultAccessState {
        accessState
    }

    func createVault() async throws -> UUID {
        try await createVault(password: nil)
    }

    func createVault(password: String?) async throws -> UUID {
        if case .unlocking = accessState { throw VaultStorageError.unlockInProgress }
        try migrate()
        if usesEmbeddedPasswordWrapper, password == nil {
            throw VaultStorageError.invalidInput
        }
        guard try metadata() == nil else {
            accessState = .locked
            throw VaultStorageError.vaultAlreadyCreated
        }
        guard try !hasBusinessRecords() else {
            accessState = .corrupt
            throw VaultStorageError.corruptVault
        }

        let attempt = UUID()
        activeKeyOperation = attempt
        accessState = .unlocking(attempt)
        let vaultID = UUID()
        let keyID = UUID()
        do {
            let key: SymmetricKey
            let passwordWrapper: PasswordWrappedKeyRecord?
            if usesEmbeddedPasswordWrapper, let password {
                key = KeychainVaultKeyStore.generateDataEncryptionKey()
                passwordWrapper = try PasswordKeyWrapper.wrap(key, password: password, vaultID: vaultID, keyID: keyID)
            } else {
                key = try await keyStore.create(vaultID: vaultID, keyID: keyID)
                passwordWrapper = nil
            }
            guard activeKeyOperation == attempt else { throw VaultStorageError.unlockSuperseded }

            let generation = keySession.unlock(with: key)
            let control = VaultControlPayload(version: 1, vaultID: vaultID, keyID: keyID)
            let controlBytes = try JSONEncoder().encode(control)
            let context = PayloadContext(
                vaultID: vaultID,
                keyID: keyID,
                recordKind: .control,
                recordID: vaultID
            )
            let envelope = try keySession.seal(controlBytes, context: context, expectedGeneration: generation)
            try createVault(vaultID: vaultID, keyID: keyID, controlEnvelope: envelope, passwordWrapper: passwordWrapper)
            activeKeyOperation = nil
            accessState = .unlocked(generation)
            return vaultID
        } catch {
            _ = keySession.lock()
            if activeKeyOperation == attempt {
                activeKeyOperation = nil
                accessState = .notCreated
            }
            throw error
        }
    }

    func unlockVault() async throws {
        try await unlockVault(password: nil)
    }

    func unlockVault(password: String?) async throws {
        if case .unlocked = accessState { return }
        if case .unlocking = accessState { throw VaultStorageError.unlockInProgress }
        try migrate()
        guard let metadata = try metadata() else {
            if try hasBusinessRecords() {
                accessState = .corrupt
                throw VaultStorageError.corruptVault
            }
            accessState = .notCreated
            throw VaultStorageError.vaultNotCreated
        }

        let attempt = UUID()
        activeKeyOperation = attempt
        accessState = .unlocking(attempt)
        let key: SymmetricKey
        do {
            if usesEmbeddedPasswordWrapper, !(keyStore is FixedVaultKeyStore), let password {
                guard let record = try passwordWrapper(vaultID: metadata.vaultID, keyID: metadata.activeKeyID) else {
                    throw VaultKeyStoreError.missingKey
                }
                key = try PasswordKeyWrapper.unwrap(record, password: password, vaultID: metadata.vaultID, keyID: metadata.activeKeyID)
            } else {
                key = try await keyStore.load(vaultID: metadata.vaultID, keyID: metadata.activeKeyID)
            }
        } catch let error as VaultKeyStoreError {
            guard activeKeyOperation == attempt else { throw VaultStorageError.unlockSuperseded }
            activeKeyOperation = nil
            accessState = error == .missingKey ? .recoveryRequired : .locked
            if error == .missingKey { throw VaultStorageError.recoveryRequired }
            if usesEmbeddedPasswordWrapper { throw VaultStorageError.authenticationFailed }
            throw error
        } catch {
            guard activeKeyOperation == attempt else { throw VaultStorageError.unlockSuperseded }
            activeKeyOperation = nil
            accessState = .locked
            if usesEmbeddedPasswordWrapper { throw VaultStorageError.authenticationFailed }
            throw error
        }
        guard activeKeyOperation == attempt else { throw VaultStorageError.unlockSuperseded }

        let generation = keySession.unlock(with: key)
        do {
            let context = PayloadContext(
                vaultID: metadata.vaultID,
                keyID: metadata.activeKeyID,
                recordKind: .control,
                recordID: metadata.vaultID
            )
            let bytes = try keySession.open(
                metadata.controlEnvelope,
                context: context,
                expectedGeneration: generation
            )
            let control = try JSONDecoder().decode(VaultControlPayload.self, from: bytes)
            guard control.version == 1,
                  control.vaultID == metadata.vaultID,
                  control.keyID == metadata.activeKeyID else {
                throw VaultStorageError.corruptVault
            }
            activeKeyOperation = nil
            accessState = .unlocked(generation)
        } catch {
            _ = keySession.lock()
            activeKeyOperation = nil
            accessState = .corrupt
            throw VaultStorageError.corruptVault
        }
    }

    func lockVault() async {
        activeKeyOperation = nil
        _ = keySession.lock()
        switch accessState {
        case .notCreated:
            break
        default:
            accessState = .locked
        }
    }

    private func activeKey(metadata: VaultMetadata, generation: UUID) async throws -> SymmetricKey {
        // Recovery validation supplies a fixed key; ordinary portable sessions reuse their unlocked DEK.
        if usesEmbeddedPasswordWrapper && !(keyStore is FixedVaultKeyStore) {
            return try keySession.keyMaterial(expectedGeneration: generation)
        }
        return try await keyStore.load(vaultID: metadata.vaultID, keyID: metadata.activeKeyID)
    }

    // MARK: - Backups and recovery

    func createSnapshot(at path: String) async throws {
        let expectedGeneration = try unlockedGeneration()
        guard let metadata = try metadata() else { throw VaultStorageError.vaultNotCreated }
        let key = try await activeKey(metadata: metadata, generation: expectedGeneration)
        let stagingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Kansolendar-Backup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: stagingDirectory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: stagingDirectory) }
        let stagingURL = stagingDirectory.appendingPathComponent("verified.sqlite")
        try connection.snapshot(to: stagingURL.path)
        try await Self.validateBackup(
            at: stagingURL.path,
            key: key,
            expectedVaultID: metadata.vaultID,
            expectedKeyID: metadata.activeKeyID
        )
        do {
            try PrivateFileCopier.copyNewFile(from: stagingURL.path, to: path)
        } catch PrivateFileError.destinationExists {
            throw SQLiteVaultError.snapshotDestinationExists
        }
    }

    func restoreBackup(from sourcePath: String, recoveryKitData: Data, password: String? = nil) async throws {
        try migrate()
        let kit = try RecoveryKit.decode(recoveryKitData)
        let replacementKey = try kit.makeKey()
        let staging = try Self.stageBackup(from: sourcePath)
        var preserveSafetyCopy = false
        defer {
            if !preserveSafetyCopy {
                try? FileManager.default.removeItem(at: staging.deletingLastPathComponent())
            }
        }

        try await Self.validateBackup(
            at: staging.path,
            key: replacementKey,
            expectedVaultID: kit.vaultID,
            expectedKeyID: kit.keyID
        )

        let previousAccessState = accessState
        let previousMetadata = try metadata()
        let previousKey: SymmetricKey?
        if let previousMetadata {
            do {
                if usesEmbeddedPasswordWrapper {
                    previousKey = try keySession.keyMaterial(expectedGeneration: unlockedGeneration())
                } else {
                    previousKey = try await keyStore.load(
                        vaultID: previousMetadata.vaultID,
                        keyID: previousMetadata.activeKeyID
                    )
                }
            } catch VaultKeyStoreError.missingKey {
                previousKey = nil
            }
        } else {
            previousKey = nil
        }
        let safetyURL = staging.deletingLastPathComponent().appendingPathComponent("active-safety.sqlite")
        try connection.snapshot(to: safetyURL.path)

        let hasSameStoredKey = previousMetadata?.vaultID == kit.vaultID &&
            previousMetadata?.activeKeyID == kit.keyID && previousKey != nil
        let canReplaceEmptyPortableVault: Bool
        if usesEmbeddedPasswordWrapper, previousMetadata != nil, !hasSameStoredKey {
            canReplaceEmptyPortableVault = try !hasBusinessRecords()
        } else {
            canReplaceEmptyPortableVault = false
        }
        if usesEmbeddedPasswordWrapper,
           previousMetadata != nil,
           !hasSameStoredKey,
           !canReplaceEmptyPortableVault {
            throw VaultStorageError.vaultAlreadyCreated
        }
        if hasSameStoredKey, let previousKey {
            // Equal IDs alone do not prove that the installed key can reopen the backup.
            try await Self.validateBackup(
                at: staging.path, key: previousKey,
                expectedVaultID: kit.vaultID, expectedKeyID: kit.keyID
            )
        }
        if !hasSameStoredKey {
            if usesEmbeddedPasswordWrapper {
                guard password != nil else { throw VaultStorageError.invalidInput }
            } else {
                try await keyStore.install(replacementKey, vaultID: kit.vaultID, keyID: kit.keyID)
            }
        }

        do {
            _ = keySession.lock()
            accessState = .locked
            try connection.replaceContents(from: staging.path)
            if usesEmbeddedPasswordWrapper {
                try connection.setPortableApplicationID(Self.portableApplicationID)
            }
            try migrate()
            if usesEmbeddedPasswordWrapper, let password {
                let record = try PasswordKeyWrapper.wrap(replacementKey, password: password, vaultID: kit.vaultID, keyID: kit.keyID)
                try connection.withImmediateTransaction {
                    try storePasswordWrapper(record, vaultID: kit.vaultID, keyID: kit.keyID)
                }
            }
            let generation = keySession.unlock(with: replacementKey)
            accessState = .unlocked(generation)
            _ = try calendars()
            _ = try events()
        } catch {
            _ = keySession.lock()
            accessState = .corrupt
            do {
                try connection.replaceContents(from: safetyURL.path)
            } catch {
                // Keep both encrypted candidates and their keys for manual recovery.
                preserveSafetyCopy = true
                throw SQLiteVaultError.restoreRollbackFailed
            }
            if let previousKey {
                let generation = keySession.unlock(with: previousKey)
                accessState = .unlocked(generation)
            } else {
                switch previousAccessState {
                case .recoveryRequired: accessState = .recoveryRequired
                case .corrupt: accessState = .corrupt
                case .notCreated: accessState = .notCreated
                default: accessState = .locked
                }
            }
            // install may have reused a previously authorized key. Retain it on
            // rollback rather than risk deleting a key needed by another backup.
            throw SQLiteVaultError.restoreFailed
        }

        if !usesEmbeddedPasswordWrapper,
           let previousMetadata,
           previousMetadata.vaultID != kit.vaultID || previousMetadata.activeKeyID != kit.keyID {
            try? await keyStore.delete(vaultID: previousMetadata.vaultID, keyID: previousMetadata.activeKeyID)
        }
    }

    private static func validateBackup(
        at path: String,
        key: SymmetricKey,
        expectedVaultID: UUID,
        expectedKeyID: UUID
    ) async throws {
        let validator = try SQLiteVaultDatabase(
            path: path,
            keyStore: FixedVaultKeyStore(
                vaultID: expectedVaultID,
                keyID: expectedKeyID,
                key: key
            ),
            usesEmbeddedPasswordWrapper: try isPortableDatabase(at: path)
        )
        try await validator.unlockVault()
        guard let metadata = try await validator.metadata(),
              metadata.vaultID == expectedVaultID,
              metadata.activeKeyID == expectedKeyID else {
            throw RecoveryKitError.vaultMismatch
        }
        _ = try await validator.calendars()
        _ = try await validator.events()
        await validator.lockVault()
    }

    private static func isPortableDatabase(at path: String) throws -> Bool {
        let connection = try SQLiteConnection(path: path)
        return try connection.applicationID() == portableApplicationID
    }

    private static func stageBackup(from sourcePath: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Kansolendar-Restore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        let destination = directory.appendingPathComponent("candidate.sqlite")
        do {
            try PrivateFileCopier.copyNewFile(from: sourcePath, to: destination.path)
            return destination
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    func exportRecoveryKit(to path: String) async throws {
        let expectedGeneration = try unlockedGeneration()
        guard let metadata = try metadata() else { throw VaultStorageError.vaultNotCreated }
        let key = try await activeKey(metadata: metadata, generation: expectedGeneration)
        guard try unlockedGeneration() == expectedGeneration else {
            throw VaultStorageError.unlockSuperseded
        }

        let context = PayloadContext(
            vaultID: metadata.vaultID,
            keyID: metadata.activeKeyID,
            recordKind: .control,
            recordID: metadata.vaultID
        )
        let controlBytes = try PayloadEnvelope.open(metadata.controlEnvelope, using: key, context: context)
        let control = try JSONDecoder().decode(VaultControlPayload.self, from: controlBytes)
        guard control.version == 1,
              control.vaultID == metadata.vaultID,
              control.keyID == metadata.activeKeyID else {
            throw VaultStorageError.corruptVault
        }
        let kit = try RecoveryKit(vaultID: metadata.vaultID, keyID: metadata.activeKeyID, key: key)
        try RecoveryKitFileWriter.write(try kit.encoded(), to: path)
    }

    // MARK: - Domain values and authenticated payloads

    func saveCalendar(_ calendar: LocalCalendar) throws {
        let generation = try unlockedGeneration()
        let context = PayloadContext(
            vaultID: try currentVaultID(),
            keyID: try currentKeyID(),
            recordKind: .calendar,
            recordID: calendar.id
        )
        let envelope = try keySession.seal(
            VaultPayloadCodec.encode(calendar),
            context: context,
            expectedGeneration: generation
        )
        try saveCalendar(id: calendar.id, envelope: envelope)
    }

    func saveEvent(
        _ event: Event,
        recurrence: RecurrenceRule? = nil,
        cancellations: Set<EventOccurrenceKey> = []
    ) throws {
        let generation = try unlockedGeneration()
        let hasDuplicateUID = try events().contains { existing in
            existing.event.id != event.id &&
                existing.event.calendarID == event.calendarID &&
                existing.event.uid == event.uid
        }
        guard !hasDuplicateUID else { throw VaultStorageError.duplicateUID }
        if let recurrence {
            _ = try RecurringSeries(event: event, rule: recurrence, cancellations: cancellations)
        } else if !cancellations.isEmpty {
            throw DomainValidationError.invalidRecurrence
        }
        let vaultID = try currentVaultID()
        let keyID = try currentKeyID()
        let context = PayloadContext(
            vaultID: vaultID,
            keyID: keyID,
            recordKind: .event,
            recordID: event.id,
            parentID: event.calendarID
        )
        let envelope = try keySession.seal(
            VaultPayloadCodec.encode(event, recurrence: recurrence),
            context: context,
            expectedGeneration: generation
        )
        let encryptedExceptions = try cancellations.map { key -> (UUID, Data) in
            let cancellation = EventCancellation(key: key)
            let exceptionID = UUID()
            let exceptionContext = PayloadContext(
                vaultID: vaultID,
                keyID: keyID,
                recordKind: .eventException,
                recordID: exceptionID,
                parentID: event.id
            )
            return (exceptionID, try keySession.seal(
                VaultPayloadCodec.encode(cancellation),
                context: exceptionContext,
                expectedGeneration: generation
            ))
        }

        // The event and its recurrence exceptions must become visible together.
        try connection.withImmediateTransaction {
            try saveEvent(id: event.id, calendarID: event.calendarID, envelope: envelope)
            try deleteExceptions(eventID: event.id)
            for (exceptionID, exceptionEnvelope) in encryptedExceptions {
                try insertException(id: exceptionID, eventID: event.id, envelope: exceptionEnvelope)
            }
        }
    }

    func importEvents(_ importedEvents: [Event], into calendarID: UUID) throws {
        let generation = try unlockedGeneration()
        guard try calendarRecords().contains(where: { $0.id == calendarID }),
              importedEvents.allSatisfy({ $0.calendarID == calendarID }) else {
            throw VaultStorageError.corruptVault
        }
        let existingUIDs = Set(try events().filter { $0.event.calendarID == calendarID }.map(\.event.uid))
        let importedUIDs = importedEvents.map(\.uid)
        guard existingUIDs.isDisjoint(with: importedUIDs),
              Set(importedUIDs).count == importedUIDs.count else {
            throw VaultStorageError.duplicateUID
        }
        let vaultID = try currentVaultID()
        let keyID = try currentKeyID()
        let encrypted = try importedEvents.map { event -> (UUID, UUID, Data) in
            let context = PayloadContext(
                vaultID: vaultID,
                keyID: keyID,
                recordKind: .event,
                recordID: event.id,
                parentID: calendarID
            )
            return (
                event.id,
                calendarID,
                try keySession.seal(
                    VaultPayloadCodec.encode(event, recurrence: nil),
                    context: context,
                    expectedGeneration: generation
                )
            )
        }
        // Import is all-or-nothing; duplicates were rejected before starting the transaction.
        try connection.withImmediateTransaction {
            for (id, parentID, envelope) in encrypted {
                try saveEvent(id: id, calendarID: parentID, envelope: envelope)
            }
        }
    }

    func calendars() throws -> [LocalCalendar] {
        let generation = try unlockedGeneration()
        let vaultID = try currentVaultID()
        let keyID = try currentKeyID()
        do {
            return try calendarRecords().map { record in
                let context = PayloadContext(
                    vaultID: vaultID,
                    keyID: keyID,
                    recordKind: .calendar,
                    recordID: record.id
                )
                let payload = try keySession.open(record.envelope, context: context, expectedGeneration: generation)
                return try VaultPayloadCodec.decodeCalendar(payload, id: record.id)
            }
        } catch {
            return try failClosed(error)
        }
    }

    func events() throws -> [VaultEvent] {
        let generation = try unlockedGeneration()
        let vaultID = try currentVaultID()
        let keyID = try currentKeyID()
        do {
            return try eventRecords().map { record in
                let context = PayloadContext(
                    vaultID: vaultID,
                    keyID: keyID,
                    recordKind: .event,
                    recordID: record.id,
                    parentID: record.calendarID
                )
                let payload = try keySession.open(record.envelope, context: context, expectedGeneration: generation)
                let base = try VaultPayloadCodec.decodeEvent(payload, id: record.id, calendarID: record.calendarID)
                let cancellations = try exceptionRecords(eventID: record.id).reduce(into: Set<EventOccurrenceKey>()) { result, exception in
                    let exceptionContext = PayloadContext(
                        vaultID: vaultID,
                        keyID: keyID,
                        recordKind: .eventException,
                        recordID: exception.id,
                        parentID: record.id
                    )
                    let exceptionPayload = try keySession.open(
                        exception.envelope,
                        context: exceptionContext,
                        expectedGeneration: generation
                    )
                    let cancellation = try VaultPayloadCodec.decodeCancellation(exceptionPayload, eventID: record.id)
                    result.insert(cancellation.key)
                }
                if let recurrence = base.recurrence {
                    _ = try RecurringSeries(event: base.event, rule: recurrence, cancellations: cancellations)
                } else if !cancellations.isEmpty {
                    throw VaultPayloadCodecError.invalidPayload
                }
                return VaultEvent(event: base.event, recurrence: base.recurrence, cancellations: cancellations)
            }
        } catch {
            return try failClosed(error)
        }
    }

    func events(matching query: EventSearchQuery) throws -> [VaultEvent] {
        let needle = EventSearch.normalized(query.text ?? "")
        let candidates = try events().filter { value in
            if let calendarIDs = query.calendarIDs, !calendarIDs.contains(value.event.calendarID) {
                return false
            }
            return needle.isEmpty || EventSearch.normalized(value.event.title).contains(needle)
        }
        let engine = RecurrenceEngine()
        var matches: [VaultEvent] = []
        for value in candidates {
            if let recurrence = value.recurrence {
                let series = try RecurringSeries(
                    event: value.event,
                    rule: recurrence,
                    cancellations: value.cancellations
                )
                if try !engine.expand(series, in: query.timeRange).isEmpty {
                    matches.append(value)
                }
            } else if !EventSearch.matching([value.event], query: query).isEmpty {
                matches.append(value)
            }
        }
        return matches.sorted { $0.event.id.uuidString < $1.event.id.uuidString }
    }

    func removeEvent(id: UUID) throws {
        _ = try unlockedGeneration()
        try deleteEvent(id: id)
    }

    func removeCalendar(id: UUID) throws {
        _ = try unlockedGeneration()
        try connection.withImmediateTransaction {
            try deleteEvents(calendarID: id)
            try deleteCalendar(id: id)
        }
    }

    // MARK: - Schema and encrypted record access

    func migrate() throws {
        let currentVersion = try connection.userVersion()
        let expectedVersion = usesEmbeddedPasswordWrapper ? Self.portableSchemaVersion : Self.schemaVersion
        guard currentVersion <= expectedVersion else {
            throw SQLiteVaultError.unsupportedSchemaVersion(currentVersion)
        }
        if currentVersion == expectedVersion {
            try validateMetadataSchemaVersion()
            switch accessState {
            case .unlocked, .unlocking:
                break
            default:
                if try metadata() == nil {
                    accessState = try hasBusinessRecords() ? .corrupt : .notCreated
                } else {
                    accessState = .locked
                }
            }
            return
        }

        try connection.withImmediateTransaction {
            if currentVersion == 0 {
                try connection.execute(Self.initialSchema)
                if usesEmbeddedPasswordWrapper {
                    try connection.execute(Self.passwordWrapperSchema)
                }
            } else if usesEmbeddedPasswordWrapper {
                try connection.execute(Self.passwordWrapperSchema)
            }
            try connection.execute("PRAGMA user_version = \(expectedVersion)")
        }
        accessState = .notCreated
    }

    func createVault(
        vaultID: UUID,
        keyID: UUID,
        controlEnvelope: Data,
        passwordWrapper: PasswordWrappedKeyRecord? = nil
    ) throws {
        try validate(id: vaultID)
        try validate(id: keyID)
        try validate(envelope: controlEnvelope)
        // Metadata and the portable key wrapper form one recoverable vault identity.
        try connection.withImmediateTransaction {
            let statement = try connection.prepare(
                "INSERT INTO vault_meta(singleton, vault_id, schema_version, active_key_id, control_envelope) VALUES(1, ?1, ?2, ?3, ?4)"
            )
            defer { sqlite3_finalize(statement) }
            try bind(vaultID, to: statement, at: 1)
            try bind(Self.metadataSchemaVersion, to: statement, at: 2)
            try bind(keyID, to: statement, at: 3)
            try bind(controlEnvelope, to: statement, at: 4)
            try stepDone(statement)
            if let passwordWrapper {
                try storePasswordWrapper(passwordWrapper, vaultID: vaultID, keyID: keyID)
            }
        }
    }

    func metadata() throws -> VaultMetadata? {
        let statement = try connection.prepare(
            "SELECT vault_id, active_key_id, control_envelope, schema_version FROM vault_meta WHERE singleton = 1"
        )
        defer { sqlite3_finalize(statement) }
        let status = sqlite3_step(statement)
        if status == SQLITE_DONE { return nil }
        guard status == SQLITE_ROW else { throw connection.failure(status) }

        let schemaVersion = sqlite3_column_int64(statement, 3)
        guard schemaVersion == Self.metadataSchemaVersion else {
            throw SQLiteVaultError.schemaMismatch
        }
        return VaultMetadata(
            vaultID: try uuidColumn(statement, index: 0),
            activeKeyID: try uuidColumn(statement, index: 1),
            controlEnvelope: try dataColumn(statement, index: 2)
        )
    }

    func passwordWrapper(vaultID: UUID, keyID: UUID) throws -> PasswordWrappedKeyRecord? {
        let statement = try connection.prepare(
            "SELECT record FROM vault_key_wrap WHERE singleton = 1 AND vault_id = ?1 AND key_id = ?2"
        )
        defer { sqlite3_finalize(statement) }
        try bind(vaultID, to: statement, at: 1)
        try bind(keyID, to: statement, at: 2)
        let status = sqlite3_step(statement)
        if status == SQLITE_DONE { return nil }
        guard status == SQLITE_ROW else { throw connection.failure(status) }
        let data = try dataColumn(statement, index: 0)
        guard data.count <= 4_096 else { throw SQLiteVaultError.invalidEnvelope }
        return try JSONDecoder().decode(PasswordWrappedKeyRecord.self, from: data)
    }

    func storePasswordWrapper(_ record: PasswordWrappedKeyRecord, vaultID: UUID, keyID: UUID) throws {
        let data = try JSONEncoder().encode(record)
        guard data.count <= 4_096 else { throw SQLiteVaultError.invalidEnvelope }
        let statement = try connection.prepare(
            "INSERT INTO vault_key_wrap(singleton, vault_id, key_id, record) VALUES(1, ?1, ?2, ?3) " +
                "ON CONFLICT(singleton) DO UPDATE SET vault_id = excluded.vault_id, key_id = excluded.key_id, record = excluded.record"
        )
        defer { sqlite3_finalize(statement) }
        try bind(vaultID, to: statement, at: 1)
        try bind(keyID, to: statement, at: 2)
        try bind(data, to: statement, at: 3)
        try stepDone(statement)
    }

    func insertCalendar(id: UUID, envelope: Data) throws {
        try insertRecord(sql: "INSERT INTO calendars(id, payload_envelope) VALUES(?1, ?2)", id: id, envelope: envelope)
    }

    func saveCalendar(id: UUID, envelope: Data) throws {
        try validate(id: id)
        try validate(envelope: envelope)
        let statement = try connection.prepare(
            "INSERT INTO calendars(id, payload_envelope) VALUES(?1, ?2) ON CONFLICT(id) DO UPDATE SET payload_envelope = excluded.payload_envelope"
        )
        defer { sqlite3_finalize(statement) }
        try bind(id, to: statement, at: 1)
        try bind(envelope, to: statement, at: 2)
        try stepDone(statement)
    }

    func insertEvent(id: UUID, calendarID: UUID, envelope: Data) throws {
        try validate(id: id)
        try validate(id: calendarID)
        try validate(envelope: envelope)
        let statement = try connection.prepare(
            "INSERT INTO events(id, calendar_id, payload_envelope) VALUES(?1, ?2, ?3)"
        )
        defer { sqlite3_finalize(statement) }
        try bind(id, to: statement, at: 1)
        try bind(calendarID, to: statement, at: 2)
        try bind(envelope, to: statement, at: 3)
        try stepDone(statement)
    }

    func insertException(id: UUID, eventID: UUID, envelope: Data) throws {
        try validate(id: id)
        try validate(id: eventID)
        try validate(envelope: envelope)
        let statement = try connection.prepare(
            "INSERT INTO event_exceptions(id, event_id, payload_envelope) VALUES(?1, ?2, ?3)"
        )
        defer { sqlite3_finalize(statement) }
        try bind(id, to: statement, at: 1)
        try bind(eventID, to: statement, at: 2)
        try bind(envelope, to: statement, at: 3)
        try stepDone(statement)
    }

    func exceptionRecords(eventID: UUID) throws -> [VaultExceptionRecord] {
        try validate(id: eventID)
        let statement = try connection.prepare(
            "SELECT id, event_id, payload_envelope FROM event_exceptions WHERE event_id = ?1 ORDER BY id"
        )
        defer { sqlite3_finalize(statement) }
        try bind(eventID, to: statement, at: 1)
        var records: [VaultExceptionRecord] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return records }
            guard status == SQLITE_ROW else { throw connection.failure(status) }
            records.append(VaultExceptionRecord(
                id: try uuidColumn(statement, index: 0),
                eventID: try uuidColumn(statement, index: 1),
                envelope: try dataColumn(statement, index: 2)
            ))
        }
    }

    func deleteExceptions(eventID: UUID) throws {
        try validate(id: eventID)
        let statement = try connection.prepare("DELETE FROM event_exceptions WHERE event_id = ?1")
        defer { sqlite3_finalize(statement) }
        try bind(eventID, to: statement, at: 1)
        try stepDone(statement)
    }

    func updateEvent(id: UUID, envelope: Data) throws {
        try validate(id: id)
        try validate(envelope: envelope)
        let statement = try connection.prepare("UPDATE events SET payload_envelope = ?1 WHERE id = ?2")
        defer { sqlite3_finalize(statement) }
        try bind(envelope, to: statement, at: 1)
        try bind(id, to: statement, at: 2)
        try stepDone(statement)
        guard sqlite3_changes(connection.handle) == 1 else { throw SQLiteVaultError.missingRecord }
    }

    func saveEvent(id: UUID, calendarID: UUID, envelope: Data) throws {
        try validate(id: id)
        try validate(id: calendarID)
        try validate(envelope: envelope)
        let statement = try connection.prepare(
            "INSERT INTO events(id, calendar_id, payload_envelope) VALUES(?1, ?2, ?3) " +
                "ON CONFLICT(id) DO UPDATE SET calendar_id = excluded.calendar_id, payload_envelope = excluded.payload_envelope"
        )
        defer { sqlite3_finalize(statement) }
        try bind(id, to: statement, at: 1)
        try bind(calendarID, to: statement, at: 2)
        try bind(envelope, to: statement, at: 3)
        try stepDone(statement)
    }

    func payload(table: VaultPayloadTable, id: UUID) throws -> Data? {
        try validate(id: id)
        let statement = try connection.prepare(table.selectSQL)
        defer { sqlite3_finalize(statement) }
        try bind(id, to: statement, at: 1)
        let status = sqlite3_step(statement)
        if status == SQLITE_DONE { return nil }
        guard status == SQLITE_ROW else { throw connection.failure(status) }
        return try dataColumn(statement, index: 0)
    }

    func calendarRecords() throws -> [VaultCalendarRecord] {
        let statement = try connection.prepare("SELECT id, payload_envelope FROM calendars ORDER BY id")
        defer { sqlite3_finalize(statement) }
        var records: [VaultCalendarRecord] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return records }
            guard status == SQLITE_ROW else { throw connection.failure(status) }
            records.append(VaultCalendarRecord(
                id: try uuidColumn(statement, index: 0),
                envelope: try dataColumn(statement, index: 1)
            ))
        }
    }

    func eventRecords() throws -> [VaultEventRecord] {
        let statement = try connection.prepare("SELECT id, calendar_id, payload_envelope FROM events ORDER BY id")
        defer { sqlite3_finalize(statement) }
        var records: [VaultEventRecord] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return records }
            guard status == SQLITE_ROW else { throw connection.failure(status) }
            records.append(VaultEventRecord(
                id: try uuidColumn(statement, index: 0),
                calendarID: try uuidColumn(statement, index: 1),
                envelope: try dataColumn(statement, index: 2)
            ))
        }
    }

    private func hasBusinessRecords() throws -> Bool {
        for table in ["calendars", "events", "event_exceptions"] {
            let statement = try connection.prepare("SELECT 1 FROM \(table) LIMIT 1")
            defer { sqlite3_finalize(statement) }
            let status = sqlite3_step(statement)
            if status == SQLITE_ROW { return true }
            guard status == SQLITE_DONE else { throw connection.failure(status) }
        }
        return false
    }

    func deleteEvent(id: UUID) throws {
        try deleteRecord(sql: "DELETE FROM events WHERE id = ?1", id: id)
    }

    func deleteCalendar(id: UUID) throws {
        try deleteRecord(sql: "DELETE FROM calendars WHERE id = ?1", id: id)
    }

    private func deleteEvents(calendarID: UUID) throws {
        let statement = try connection.prepare("DELETE FROM events WHERE calendar_id = ?1")
        defer { sqlite3_finalize(statement) }
        try bind(calendarID, to: statement, at: 1)
        let status = sqlite3_step(statement)
        guard status == SQLITE_DONE else { throw connection.failure(status) }
    }

    // MARK: - Session validation and SQLite bindings

    private func unlockedGeneration() throws -> UUID {
        guard case let .unlocked(generation) = accessState,
              keySession.isUnlocked,
              keySession.generation == generation else {
            throw VaultStorageError.locked
        }
        return generation
    }

    private func currentVaultID() throws -> UUID {
        guard let metadata = try metadata() else { throw VaultStorageError.corruptVault }
        return metadata.vaultID
    }

    private func currentKeyID() throws -> UUID {
        guard let metadata = try metadata() else { throw VaultStorageError.corruptVault }
        return metadata.activeKeyID
    }

    private func failClosed<Value>(_ error: Error) throws -> Value {
        if let error = error as? SQLiteVaultError {
            throw error
        }
        if let error = error as? VaultKeySessionError, error == .locked || error == .staleGeneration {
            throw VaultStorageError.locked
        }
        if let error = error as? VaultPayloadCodecError, error == .timeZoneRulesChanged {
            throw VaultStorageError.timeZoneRulesChanged
        }
        _ = keySession.lock()
        accessState = .corrupt
        throw VaultStorageError.corruptVault
    }

    func integrityCheck() throws {
        let statement = try connection.prepare("PRAGMA integrity_check")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let text = sqlite3_column_text(statement, 0),
              String(cString: text) == "ok"
        else {
            throw SQLiteVaultError.integrityFailure
        }
    }

    func foreignKeyCheck() throws {
        let statement = try connection.prepare("PRAGMA foreign_key_check")
        defer { sqlite3_finalize(statement) }
        let status = sqlite3_step(statement)
        if status == SQLITE_DONE { return }
        if status == SQLITE_ROW { throw SQLiteVaultError.foreignKeyFailure }
        throw connection.failure(status)
    }

    func userVersion() throws -> Int32 {
        try connection.userVersion()
    }

    private func validateMetadataSchemaVersion() throws {
        let statement = try connection.prepare("SELECT schema_version FROM vault_meta WHERE singleton = 1")
        defer { sqlite3_finalize(statement) }
        let status = sqlite3_step(statement)
        if status == SQLITE_DONE { return }
        guard status == SQLITE_ROW,
              sqlite3_column_int64(statement, 0) == Self.metadataSchemaVersion
        else {
            throw SQLiteVaultError.schemaMismatch
        }
    }

    private func insertRecord(sql: String, id: UUID, envelope: Data) throws {
        try validate(id: id)
        try validate(envelope: envelope)
        let statement = try connection.prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(id, to: statement, at: 1)
        try bind(envelope, to: statement, at: 2)
        try stepDone(statement)
    }

    private func deleteRecord(sql: String, id: UUID) throws {
        try validate(id: id)
        let statement = try connection.prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(id, to: statement, at: 1)
        try stepDone(statement)
        guard sqlite3_changes(connection.handle) == 1 else { throw SQLiteVaultError.missingRecord }
    }

    private func validate(id: UUID) throws {
        guard Self.uuidData(id).count == 16 else { throw SQLiteVaultError.invalidIdentifier }
    }

    private func validate(envelope: Data) throws {
        guard (Self.minimumEnvelopeSize...Self.maximumEnvelopeSize).contains(envelope.count) else {
            throw SQLiteVaultError.invalidEnvelope
        }
    }

    private func bind(_ id: UUID, to statement: OpaquePointer, at index: Int32) throws {
        try bind(Self.uuidData(id), to: statement, at: index)
    }

    private func bind(_ integer: Int64, to statement: OpaquePointer, at index: Int32) throws {
        let status = sqlite3_bind_int64(statement, index, integer)
        guard status == SQLITE_OK else { throw connection.failure(status) }
    }

    private func bind(_ data: Data, to statement: OpaquePointer, at index: Int32) throws {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let status = data.withUnsafeBytes { buffer in
            sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(buffer.count), transient)
        }
        guard status == SQLITE_OK else { throw connection.failure(status) }
    }

    private func stepDone(_ statement: OpaquePointer) throws {
        let status = sqlite3_step(statement)
        guard status == SQLITE_DONE else { throw connection.failure(status) }
    }

    private func uuidColumn(_ statement: OpaquePointer, index: Int32) throws -> UUID {
        let data = try dataColumn(statement, index: index)
        guard data.count == 16 else { throw SQLiteVaultError.invalidIdentifier }
        return UUID(uuid: (
            data[0], data[1], data[2], data[3], data[4], data[5], data[6], data[7],
            data[8], data[9], data[10], data[11], data[12], data[13], data[14], data[15]
        ))
    }

    private func dataColumn(_ statement: OpaquePointer, index: Int32) throws -> Data {
        let count = Int(sqlite3_column_bytes(statement, index))
        guard count >= 0, count <= Self.maximumEnvelopeSize,
              let bytes = sqlite3_column_blob(statement, index)
        else {
            throw SQLiteVaultError.invalidEnvelope
        }
        return Data(bytes: bytes, count: count)
    }

    private static func uuidData(_ id: UUID) -> Data {
        var value = id.uuid
        return withUnsafeBytes(of: &value) { Data($0) }
    }

    private static let initialSchema = """
    CREATE TABLE vault_meta (
        singleton INTEGER PRIMARY KEY NOT NULL CHECK(singleton = 1),
        vault_id BLOB NOT NULL UNIQUE CHECK(typeof(vault_id) = 'blob' AND length(vault_id) = 16),
        schema_version INTEGER NOT NULL CHECK(schema_version = 1),
        active_key_id BLOB NOT NULL CHECK(typeof(active_key_id) = 'blob' AND length(active_key_id) = 16),
        control_envelope BLOB NOT NULL CHECK(typeof(control_envelope) = 'blob' AND length(control_envelope) BETWEEN 33 AND 131105)
    );
    CREATE TABLE calendars (
        id BLOB PRIMARY KEY NOT NULL CHECK(typeof(id) = 'blob' AND length(id) = 16),
        payload_envelope BLOB NOT NULL CHECK(typeof(payload_envelope) = 'blob' AND length(payload_envelope) BETWEEN 33 AND 131105)
    );
    CREATE TABLE events (
        id BLOB PRIMARY KEY NOT NULL CHECK(typeof(id) = 'blob' AND length(id) = 16),
        calendar_id BLOB NOT NULL CHECK(typeof(calendar_id) = 'blob' AND length(calendar_id) = 16),
        payload_envelope BLOB NOT NULL CHECK(typeof(payload_envelope) = 'blob' AND length(payload_envelope) BETWEEN 33 AND 131105),
        FOREIGN KEY(calendar_id) REFERENCES calendars(id) ON DELETE RESTRICT
    );
    CREATE TABLE event_exceptions (
        id BLOB PRIMARY KEY NOT NULL CHECK(typeof(id) = 'blob' AND length(id) = 16),
        event_id BLOB NOT NULL CHECK(typeof(event_id) = 'blob' AND length(event_id) = 16),
        payload_envelope BLOB NOT NULL CHECK(typeof(payload_envelope) = 'blob' AND length(payload_envelope) BETWEEN 33 AND 131105),
        FOREIGN KEY(event_id) REFERENCES events(id) ON DELETE CASCADE
    );
    CREATE INDEX events_calendar_id ON events(calendar_id);
    CREATE INDEX event_exceptions_event_id ON event_exceptions(event_id);
    """

    private static let passwordWrapperSchema = """
    CREATE TABLE vault_key_wrap (
        singleton INTEGER PRIMARY KEY NOT NULL CHECK(singleton = 1),
        vault_id BLOB NOT NULL CHECK(typeof(vault_id) = 'blob' AND length(vault_id) = 16),
        key_id BLOB NOT NULL CHECK(typeof(key_id) = 'blob' AND length(key_id) = 16),
        record BLOB NOT NULL CHECK(typeof(record) = 'blob' AND length(record) BETWEEN 1 AND 4096),
        FOREIGN KEY(vault_id) REFERENCES vault_meta(vault_id) ON DELETE CASCADE
    );
    """
}
