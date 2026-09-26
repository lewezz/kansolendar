import CryptoKit
import Foundation
import KansolendarCore
@testable import KansolendarStorage
import Testing

@Suite("Encrypted vault repository")
struct SQLiteVaultRepositoryTests {
    @Test("app-facing state migrates storage and reports an empty vault")
    func initialStateIsNotCreated() async throws {
        let storage = try SQLiteVaultDatabase(path: ":memory:", keyStore: FixtureVaultKeyStore())
        let vault = KansolendarVault(storage: storage)

        #expect(try await vault.state() == .notCreated)
        #expect(try await vault.state() == .notCreated)
    }

    @Test("vault create, lock, unlock and domain CRUD preserve encrypted values")
    func vaultLifecycleAndCRUD() async throws {
        let keyStore = FixtureVaultKeyStore()
        let database = try SQLiteVaultDatabase(path: ":memory:", keyStore: keyStore)
        let vaultID = try await database.createVault()
        #expect(await database.vaultState().isUnlocked)

        let calendar = try LocalCalendar(
            name: "Personal",
            color: .green,
            sortOrder: 2,
            defaultTimeZone: TimeZoneID("Europe/Madrid")
        )
        try await database.saveCalendar(calendar)

        let event = try Event(
            calendarID: calendar.id,
            uid: "event-local-1",
            title: "Private planning",
            notes: "not stored as SQL text",
            location: "Home",
            time: .utc(try TimedEventTime(start: Instant(unixSeconds: -100), durationSeconds: 1_800))
        )
        let recurrence = try RecurrenceRule(frequency: .daily, interval: 2, end: .count(5))
        try await database.saveEvent(event, recurrence: recurrence)
        #expect(try await database.calendars() == [calendar])
        #expect(try await database.events() == [VaultEvent(event: event, recurrence: recurrence)])

        await database.lockVault()
        #expect(await database.vaultState() == .locked)
        do {
            _ = try await database.events()
            Issue.record("Locked vault must not return events")
        } catch let error as VaultStorageError {
            #expect(error == .locked)
        }

        try await database.unlockVault()
        #expect(await database.vaultState().isUnlocked)
        #expect(try await database.events() == [VaultEvent(event: event, recurrence: recurrence)])

        try await database.removeEvent(id: event.id)
        #expect(try await database.events().isEmpty)
        try await database.removeCalendar(id: calendar.id)
        #expect(try await database.calendars().isEmpty)
        #expect(try await database.metadata()?.vaultID == vaultID)
    }

    @Test("missing key requires recovery and user cancellation stays locked")
    func missingAndCancelledKeysFailClosed() async throws {
        let keyStore = FixtureVaultKeyStore()
        let database = try SQLiteVaultDatabase(path: ":memory:", keyStore: keyStore)
        _ = try await database.createVault()
        await database.lockVault()

        await keyStore.setLoadError(.userCancelled)
        do {
            try await database.unlockVault()
            Issue.record("Cancelled unlock must not succeed")
        } catch let error as VaultKeyStoreError {
            #expect(error == .userCancelled)
        }
        #expect(await database.vaultState() == .locked)

        await keyStore.setLoadError(.missingKey)
        do {
            try await database.unlockVault()
            Issue.record("Missing key must require recovery")
        } catch let error as VaultStorageError {
            #expect(error == .recoveryRequired)
        }
        #expect(await database.vaultState() == .recoveryRequired)
    }

    @Test("authenticated payload corruption locks the vault without partial results")
    func corruptPayloadLocksVault() async throws {
        let keyStore = FixtureVaultKeyStore()
        let database = try SQLiteVaultDatabase(path: ":memory:", keyStore: keyStore)
        _ = try await database.createVault()
        let calendar = try LocalCalendar(name: "Private", defaultTimeZone: TimeZoneID("UTC"))
        try await database.saveCalendar(calendar)

        let raw = try #require(await database.payload(table: .calendar, id: calendar.id))
        var corrupted = raw
        corrupted[corrupted.index(before: corrupted.endIndex)] ^= 0x01
        try await database.saveCalendar(id: calendar.id, envelope: corrupted)

        do {
            _ = try await database.calendars()
            Issue.record("Tampered payload must not be returned")
        } catch let error as VaultStorageError {
            #expect(error == .corruptVault)
        }
        #expect(await database.vaultState() == .corrupt)
    }

    @Test("UID uniqueness is enforced within a calendar but not globally")
    func uidUniquenessMatchesDomainRule() async throws {
        let database = try SQLiteVaultDatabase(path: ":memory:", keyStore: FixtureVaultKeyStore())
        _ = try await database.createVault()
        let firstCalendar = try LocalCalendar(name: "One", defaultTimeZone: TimeZoneID("UTC"))
        let secondCalendar = try LocalCalendar(name: "Two", defaultTimeZone: TimeZoneID("UTC"))
        try await database.saveCalendar(firstCalendar)
        try await database.saveCalendar(secondCalendar)

        let firstEvent = try makeEvent(calendarID: firstCalendar.id, uid: "shared-uid", title: "First")
        try await database.saveEvent(firstEvent)
        let duplicate = try makeEvent(calendarID: firstCalendar.id, uid: "shared-uid", title: "Duplicate")
        do {
            try await database.saveEvent(duplicate)
            Issue.record("Duplicate UID in one calendar must fail")
        } catch let error as VaultStorageError {
            #expect(error == .duplicateUID)
        }

        let otherCalendarEvent = try makeEvent(calendarID: secondCalendar.id, uid: "shared-uid", title: "Other calendar")
        try await database.saveEvent(otherCalendarEvent)
        #expect(try await database.events().count == 2)
    }

    @Test("orphan payload rows cannot be mistaken for a new empty vault")
    func orphanRecordsBlockVaultCreation() async throws {
        let database = try SQLiteVaultDatabase(path: ":memory:", keyStore: FixtureVaultKeyStore())
        try await database.migrate()
        try await database.insertCalendar(id: UUID(), envelope: Data(repeating: 0xA1, count: 33))

        do {
            _ = try await database.createVault()
            Issue.record("Existing business records without vault metadata are corruption")
        } catch let error as VaultStorageError {
            #expect(error == .corruptVault)
        }
        #expect(await database.vaultState() == .corrupt)
    }

    @Test("production database directory and file use restrictive permissions")
    func productionPathUsesPrivatePermissions() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let url = try VaultDatabaseLocation.databaseURL(applicationSupportRoot: root)
        #expect(try VaultDatabaseLocation.databaseURL(applicationSupportRoot: root) == url)
        let database = try SQLiteVaultDatabase(path: url.path, keyStore: FixtureVaultKeyStore())
        _ = database

        let directoryAttributes = try FileManager.default.attributesOfItem(atPath: url.deletingLastPathComponent().path)
        let databaseAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        #expect((directoryAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
        #expect((databaseAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    }

    @Test("application support location rejects a symlinked vault directory")
    func rejectsSymlinkedVaultDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let target = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: target)
        }
        let link = root.appendingPathComponent("Kansolendar", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        do {
            _ = try VaultDatabaseLocation.databaseURL(applicationSupportRoot: root)
            Issue.record("Symlinked vault directory must not be followed")
        } catch let error as VaultDatabaseLocationError {
            switch error {
            case .unsafeDirectory:
                break
            case let .filesystemFailure(code):
                #expect(code != 0)
            }
        }
        #expect(!FileManager.default.fileExists(atPath: target.appendingPathComponent("vault.sqlite").path))
    }

    @Test("overlapping vault creation is rejected without replacing the active attempt")
    func overlappingCreationIsRejected() async throws {
        let keyStore = FixtureVaultKeyStore()
        await keyStore.setCreateDelay(50_000_000)
        let database = try SQLiteVaultDatabase(path: ":memory:", keyStore: keyStore)
        let firstCreation = Task { try await database.createVault() }
        try await Task.sleep(nanoseconds: 5_000_000)

        do {
            _ = try await database.createVault()
            Issue.record("Concurrent creation must not replace an in-flight attempt")
        } catch let error as VaultStorageError {
            #expect(error == .unlockInProgress)
        }
        _ = try await firstCreation.value
        #expect(await database.vaultState().isUnlocked)
    }

    @Test("app-facing vault boundary exposes domain data and privacy-safe errors")
    func publicVaultBoundary() async throws {
        let keyStore = FixtureVaultKeyStore()
        let storage = try SQLiteVaultDatabase(path: ":memory:", keyStore: keyStore)
        let vault = KansolendarVault(storage: storage)
        _ = try await vault.createVault()
        #expect(try await vault.state() == .unlocked)

        let calendar = try LocalCalendar(name: "Private", defaultTimeZone: TimeZoneID("UTC"))
        try await vault.save(calendar)
        #expect(try await vault.calendars() == [calendar])

        await vault.lock()
        do {
            _ = try await vault.calendars()
            Issue.record("App-facing API must not return plaintext while locked")
        } catch let error as VaultError {
            #expect(error == .locked)
        }

        await keyStore.setLoadError(.userCancelled)
        do {
            try await vault.unlock()
            Issue.record("Cancelled Keychain prompt must remain locked")
        } catch let error as VaultError {
            #expect(error == .authenticationCancelled)
        }
        #expect(try await vault.state() == .locked)
    }

    private func makeEvent(calendarID: UUID, uid: String, title: String) throws -> Event {
        try Event(
            calendarID: calendarID,
            uid: uid,
            title: title,
            time: .utc(try TimedEventTime(start: Instant(unixSeconds: 0), durationSeconds: 60))
        )
    }
}

private actor FixtureVaultKeyStore: VaultKeyStore {
    private var keys: [String: Data] = [:]
    private var loadError: VaultKeyStoreError?
    private var createDelayNanoseconds: UInt64 = 0

    func create(vaultID: UUID, keyID: UUID) async throws -> SymmetricKey {
        if createDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: createDelayNanoseconds)
        }
        let key = SymmetricKey(size: .bits256)
        keys[KeychainVaultKeyStore.account(vaultID: vaultID, keyID: keyID)] = key.withUnsafeBytes { Data($0) }
        return key
    }

    func load(vaultID: UUID, keyID: UUID) async throws -> SymmetricKey {
        if let loadError { throw loadError }
        guard let data = keys[KeychainVaultKeyStore.account(vaultID: vaultID, keyID: keyID)] else {
            throw VaultKeyStoreError.missingKey
        }
        return try KeychainVaultKeyStore.makeDataEncryptionKey(from: data)
    }

    func delete(vaultID: UUID, keyID: UUID) async throws {
        keys[KeychainVaultKeyStore.account(vaultID: vaultID, keyID: keyID)] = nil
    }

    func setLoadError(_ error: VaultKeyStoreError?) {
        loadError = error
    }

    func setCreateDelay(_ nanoseconds: UInt64) {
        createDelayNanoseconds = nanoseconds
    }
}

private extension VaultAccessState {
    var isUnlocked: Bool {
        if case .unlocked = self { return true }
        return false
    }
}
