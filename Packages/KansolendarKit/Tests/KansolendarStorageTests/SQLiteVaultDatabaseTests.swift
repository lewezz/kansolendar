import CryptoKit
import CSQLite
import Foundation
@testable import KansolendarStorage
import Testing

@Suite("SQLite vault database")
struct SQLiteVaultDatabaseTests {
    private let vaultID = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
    private let keyID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private let calendarID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let eventID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    private let exceptionID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

    @Test("initial migration is transactional and repeatable")
    func migrationIsRepeatable() async throws {
        let database = try SQLiteVaultDatabase(path: ":memory:")

        try await database.migrate()
        try await database.migrate()

        #expect(try await database.userVersion() == SQLiteVaultDatabase.schemaVersion)
        try await database.integrityCheck()
        try await database.foreignKeyCheck()
    }

    @Test("vault metadata preserves only identifiers and sealed control payload")
    func metadataRoundTrips() async throws {
        let database = try SQLiteVaultDatabase(path: ":memory:")
        try await database.migrate()
        #expect(try await database.metadata() == nil)

        let controlEnvelope = Data(repeating: 0xA7, count: 33)
        try await database.createVault(vaultID: vaultID, keyID: keyID, controlEnvelope: controlEnvelope)
        let metadata = try #require(await database.metadata())

        #expect(metadata == VaultMetadata(vaultID: vaultID, activeKeyID: keyID, controlEnvelope: controlEnvelope))
    }

    @Test("foreign keys restrict calendar deletion and cascade event exceptions")
    func relationshipsEnforceDeletionRules() async throws {
        let database = try SQLiteVaultDatabase(path: ":memory:")
        try await database.migrate()
        try await database.insertCalendar(id: calendarID, envelope: Data(repeating: 0xA1, count: 33))
        try await database.insertEvent(id: eventID, calendarID: calendarID, envelope: Data(repeating: 0xA2, count: 33))
        try await database.insertException(id: exceptionID, eventID: eventID, envelope: Data(repeating: 0xA3, count: 33))

        do {
            try await database.deleteCalendar(id: calendarID)
            Issue.record("Calendar with events must be restricted")
        } catch let error as SQLiteVaultError {
            #expect(error == .constraintViolation)
        }

        try await database.deleteEvent(id: eventID)
        #expect(try await database.payload(table: .eventException, id: exceptionID) == nil)
        try await database.deleteCalendar(id: calendarID)
        try await database.foreignKeyCheck()
    }

    @Test("event CRUD stores and returns envelope bytes unchanged")
    func eventCRUDUsesOpaqueEnvelopes() async throws {
        let database = try SQLiteVaultDatabase(path: ":memory:")
        try await database.migrate()
        try await database.insertCalendar(id: calendarID, envelope: Data(repeating: 0xB1, count: 33))
        let original = Data(repeating: 0xB2, count: 64)
        try await database.insertEvent(id: eventID, calendarID: calendarID, envelope: original)
        #expect(try await database.payload(table: .event, id: eventID) == original)

        let updated = Data(repeating: 0xC2, count: 65)
        try await database.updateEvent(id: eventID, envelope: updated)
        #expect(try await database.payload(table: .event, id: eventID) == updated)

        try await database.deleteEvent(id: eventID)
        #expect(try await database.payload(table: .event, id: eventID) == nil)
        do {
            try await database.deleteEvent(id: eventID)
            Issue.record("Deleting a missing event must fail")
        } catch let error as SQLiteVaultError {
            #expect(error == .missingRecord)
        }
    }

    @Test("concurrent callers are serialized by the database actor")
    func concurrentCallsRemainConsistent() async throws {
        let database = try SQLiteVaultDatabase(path: ":memory:")
        try await database.migrate()
        try await database.insertCalendar(id: calendarID, envelope: Data(repeating: 0xD1, count: 33))
        let eventIDs = (0..<40).map { _ in UUID() }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for (index, eventID) in eventIDs.enumerated() {
                group.addTask {
                    let byte = UInt8(index)
                    try await database.insertEvent(
                        id: eventID,
                        calendarID: self.calendarID,
                        envelope: Data(repeating: byte, count: 33)
                    )
                }
            }
            try await group.waitForAll()
        }

        for id in eventIDs {
            #expect(try await database.payload(table: .event, id: id) != nil)
        }
        try await database.integrityCheck()
    }

    @Test("database rejects malformed envelope sizes before binding")
    func rejectsMalformedEnvelopeSize() async throws {
        let database = try SQLiteVaultDatabase(path: ":memory:")
        try await database.migrate()

        do {
            try await database.insertCalendar(id: calendarID, envelope: Data(repeating: 0, count: 32))
            Issue.record("Short envelopes must be rejected")
        } catch let error as SQLiteVaultError {
            #expect(error == .invalidEnvelope)
        }
        do {
            try await database.insertCalendar(
                id: calendarID,
                envelope: Data(repeating: 0, count: SQLiteVaultDatabase.maximumEnvelopeSize + 1)
            )
            Issue.record("Oversized envelopes must be rejected")
        } catch let error as SQLiteVaultError {
            #expect(error == .invalidEnvelope)
        }
    }

    @Test("future schema version is rejected without mutation")
    func rejectsFutureSchemaVersion() async throws {
        let url = temporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: url) }
        var rawDatabase: OpaquePointer?
        #expect(sqlite3_open(url.path, &rawDatabase) == SQLITE_OK)
        let setVersionStatus = sqlite3_exec(rawDatabase, "PRAGMA user_version = 99", nil, nil, nil)
        #expect(setVersionStatus == SQLITE_OK)
        sqlite3_close_v2(rawDatabase)

        let database = try SQLiteVaultDatabase(path: url.path)
        do {
            try await database.migrate()
            Issue.record("Future schema versions must be rejected")
        } catch let error as SQLiteVaultError {
            #expect(error == .unsupportedSchemaVersion(99))
        }
        #expect(try await database.userVersion() == 99)
    }

    @Test("failed initial migration rolls back all schema changes")
    func failedMigrationRollsBack() async throws {
        let url = temporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: url) }
        var rawDatabase: OpaquePointer?
        #expect(sqlite3_open(url.path, &rawDatabase) == SQLITE_OK)
        let conflictStatus = sqlite3_exec(rawDatabase, "CREATE TABLE calendars(unexpected INTEGER)", nil, nil, nil)
        #expect(conflictStatus == SQLITE_OK)
        sqlite3_close_v2(rawDatabase)

        let database = try SQLiteVaultDatabase(path: url.path)
        do {
            try await database.migrate()
            Issue.record("Conflicting schema must make initial migration fail")
        } catch let error as SQLiteVaultError {
            if case .databaseFailure = error {} else {
                Issue.record("Expected typed SQLite failure, received \(error)")
            }
        }
        #expect(try await database.userVersion() == 0)
        do {
            _ = try await database.metadata()
            Issue.record("Partial vault_meta table must be rolled back")
        } catch let error as SQLiteVaultError {
            if case .databaseFailure = error {} else {
                Issue.record("Expected missing-table database failure, received \(error)")
            }
        }
    }

    @Test("database file does not contain sentinel plaintext")
    func fileContainsNoSentinelPlaintext() async throws {
        let url = temporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let database = try SQLiteVaultDatabase(path: url.path)
        try await database.migrate()

        let sentinel = Data("sensitive-title-sentinel".utf8)
        let key = SymmetricKey(data: Data(repeating: 0x91, count: 32))
        let context = PayloadContext(
            vaultID: vaultID,
            keyID: keyID,
            recordKind: .calendar,
            recordID: calendarID
        )
        let envelope = try PayloadEnvelope.seal(sentinel, using: key, context: context)
        try await database.insertCalendar(id: calendarID, envelope: envelope)

        let bytes = try Data(contentsOf: url)
        #expect(bytes.range(of: sentinel) == nil)
        #expect(try await database.payload(table: .calendar, id: calendarID) == envelope)
    }

    private func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("Kansolendar-\(UUID().uuidString).sqlite")
    }
}
