import CSQLite
import Foundation

internal enum SQLiteVaultError: Error, Equatable, Sendable {
    case openFailed(Int32)
    case databaseFailure(Int32)
    case unsupportedSchemaVersion(Int32)
    case schemaMismatch
    case invalidIdentifier
    case invalidEnvelope
    case constraintViolation
    case missingRecord
    case integrityFailure
    case foreignKeyFailure
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

/// Serializes access to one SQLite connection. Public-facing storage must pass only
/// UUID relationships and authenticated envelopes, never plaintext business values.
internal actor SQLiteVaultDatabase {
    static let schemaVersion: Int32 = 1
    static let minimumEnvelopeSize = 33
    static let maximumEnvelopeSize = 131_105

    private let connection: SQLiteConnection

    init(path: String) throws {
        connection = try SQLiteConnection(path: path)
        try connection.configure()
    }

    func migrate() throws {
        let currentVersion = try connection.userVersion()
        guard currentVersion <= Self.schemaVersion else {
            throw SQLiteVaultError.unsupportedSchemaVersion(currentVersion)
        }
        if currentVersion == Self.schemaVersion {
            try validateMetadataSchemaVersion()
            return
        }

        try connection.execute("BEGIN IMMEDIATE")
        do {
            try connection.execute(Self.initialSchema)
            try connection.execute("PRAGMA user_version = 1")
            try connection.execute("COMMIT")
        } catch {
            try? connection.execute("ROLLBACK")
            throw error
        }
    }

    func createVault(vaultID: UUID, keyID: UUID, controlEnvelope: Data) throws {
        try validate(id: vaultID)
        try validate(id: keyID)
        try validate(envelope: controlEnvelope)
        let statement = try connection.prepare(
            "INSERT INTO vault_meta(singleton, vault_id, schema_version, active_key_id, control_envelope) VALUES(1, ?1, ?2, ?3, ?4)"
        )
        defer { sqlite3_finalize(statement) }
        try bind(vaultID, to: statement, at: 1)
        try bind(Int64(Self.schemaVersion), to: statement, at: 2)
        try bind(keyID, to: statement, at: 3)
        try bind(controlEnvelope, to: statement, at: 4)
        try stepDone(statement)
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
        guard schemaVersion == Int64(Self.schemaVersion) else {
            throw SQLiteVaultError.schemaMismatch
        }
        return VaultMetadata(
            vaultID: try uuidColumn(statement, index: 0),
            activeKeyID: try uuidColumn(statement, index: 1),
            controlEnvelope: try dataColumn(statement, index: 2)
        )
    }

    func insertCalendar(id: UUID, envelope: Data) throws {
        try insertRecord(sql: "INSERT INTO calendars(id, payload_envelope) VALUES(?1, ?2)", id: id, envelope: envelope)
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

    func deleteEvent(id: UUID) throws {
        try deleteRecord(sql: "DELETE FROM events WHERE id = ?1", id: id)
    }

    func deleteCalendar(id: UUID) throws {
        try deleteRecord(sql: "DELETE FROM calendars WHERE id = ?1", id: id)
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
              sqlite3_column_int64(statement, 0) == Int64(Self.schemaVersion)
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
}

private final class SQLiteConnection {
    let handle: OpaquePointer

    init(path: String) throws {
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_PRIVATECACHE
        let status = sqlite3_open_v2(path, &database, flags, nil)
        guard status == SQLITE_OK, let database else {
            if let database { sqlite3_close_v2(database) }
            throw SQLiteVaultError.openFailed(status)
        }
        handle = database
    }

    deinit {
        sqlite3_close_v2(handle)
    }

    func configure() throws {
        sqlite3_extended_result_codes(handle, 1)
        let timeoutStatus = sqlite3_busy_timeout(handle, 1_000)
        guard timeoutStatus == SQLITE_OK else { throw failure(timeoutStatus) }
        let defensiveStatus = kansolendar_sqlite_set_db_config(handle, SQLITE_DBCONFIG_DEFENSIVE, 1)
        guard defensiveStatus == SQLITE_OK else { throw failure(defensiveStatus) }
        // The system SQLite header marks extension loading as omitted/no-op.
        try execute("PRAGMA foreign_keys = ON")
        guard try pragmaInteger("PRAGMA foreign_keys") == 1 else {
            throw SQLiteVaultError.foreignKeyFailure
        }
        try execute("PRAGMA journal_mode = DELETE")
        try execute("PRAGMA synchronous = FULL")
        try execute("PRAGMA temp_store = MEMORY")
        try execute("PRAGMA trusted_schema = OFF")
    }

    func execute(_ sql: String) throws {
        let status = sqlite3_exec(handle, sql, nil, nil, nil)
        guard status == SQLITE_OK else { throw failure(status) }
    }

    func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        let status = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard status == SQLITE_OK, let statement else { throw failure(status) }
        return statement
    }

    func userVersion() throws -> Int32 {
        Int32(try pragmaInteger("PRAGMA user_version"))
    }

    func pragmaInteger(_ sql: String) throws -> Int64 {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        let status = sqlite3_step(statement)
        guard status == SQLITE_ROW else { throw failure(status) }
        return sqlite3_column_int64(statement, 0)
    }

    func failure(_ status: Int32) -> SQLiteVaultError {
        let extendedStatus = sqlite3_extended_errcode(handle)
        if extendedStatus & 0xFF == SQLITE_CONSTRAINT {
            return .constraintViolation
        }
        return .databaseFailure(extendedStatus == SQLITE_OK ? status : extendedStatus)
    }
}
