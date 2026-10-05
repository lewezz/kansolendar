import CSQLite
import Darwin
import Foundation

/// Owns the C handle; its storage actor serializes all calls. This type is deliberately not Sendable.
internal final class SQLiteConnection {
    let handle: OpaquePointer
    private let path: String

    init(path: String, requireNewFile: Bool = false) throws {
        if path != ":memory:" {
            try Self.preparePrivateDatabaseFile(path: path, requireNewFile: requireNewFile)
        }
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_PRIVATECACHE
        let status = sqlite3_open_v2(path, &database, flags, nil)
        guard status == SQLITE_OK, let database else {
            if let database { sqlite3_close_v2(database) }
            throw SQLiteVaultError.openFailed(status)
        }
        handle = database
        self.path = path
    }

    static func validatePortableFile(path: String, applicationID: Int32) throws {
        let descriptor = path.withCString { open($0, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK) }
        guard descriptor >= 0 else { throw SQLiteVaultError.filesystemFailure(errno) }
        defer { close(descriptor) }
        var info = stat()
        guard fstat(descriptor, &info) == 0 else { throw SQLiteVaultError.filesystemFailure(errno) }
        guard info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG), info.st_uid == getuid(), info.st_size >= 100 else {
            throw SQLiteVaultError.unsafeDatabaseFile
        }
        var header = [UInt8](repeating: 0, count: 100)
        let count = header.withUnsafeMutableBytes { Darwin.read(descriptor, $0.baseAddress, $0.count) }
        guard count == 100,
              Array(header[0..<16]) == Array("SQLite format 3\0".utf8) else {
            throw SQLiteVaultError.schemaMismatch
        }
        // SQLite stores application_id as a big-endian field at header offset 68.
        let storedID = (UInt32(header[68]) << 24) | (UInt32(header[69]) << 16) | (UInt32(header[70]) << 8) | UInt32(header[71])
        guard storedID == UInt32(bitPattern: applicationID) else { throw SQLiteVaultError.schemaMismatch }
    }

    private static func preparePrivateDatabaseFile(path: String, requireNewFile: Bool) throws {
        let createFlags = O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC
        let descriptor = path.withCString { open($0, createFlags, mode_t(S_IRUSR | S_IWUSR)) }
        if descriptor >= 0 {
            try validateAndCloseFileDescriptor(descriptor)
            return
        }
        if requireNewFile, errno == EEXIST { throw SQLiteVaultError.snapshotDestinationExists }
        guard errno == EEXIST else { throw SQLiteVaultError.filesystemFailure(errno) }

        let existingDescriptor = path.withCString { open($0, O_RDWR | O_NOFOLLOW | O_CLOEXEC) }
        guard existingDescriptor >= 0 else { throw SQLiteVaultError.filesystemFailure(errno) }
        try validateAndCloseFileDescriptor(existingDescriptor)
    }

    private static func validateAndCloseFileDescriptor(_ descriptor: Int32) throws {
        defer { close(descriptor) }
        var fileStatus = stat()
        guard fstat(descriptor, &fileStatus) == 0 else {
            throw SQLiteVaultError.filesystemFailure(errno)
        }
        guard fileStatus.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG), fileStatus.st_uid == getuid() else {
            throw SQLiteVaultError.unsafeDatabaseFile
        }
        guard fchmod(descriptor, mode_t(S_IRUSR | S_IWUSR)) == 0 else {
            throw SQLiteVaultError.filesystemFailure(errno)
        }
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

    func snapshot(to destinationPath: String) throws {
        guard destinationPath != ":memory:",
              URL(fileURLWithPath: destinationPath).standardizedFileURL.path
                != URL(fileURLWithPath: path).standardizedFileURL.path else {
            throw SQLiteVaultError.unsafeSnapshotDestination
        }

        // Reserve first: cleanup must never remove a destination that already existed.
        let destination = try SQLiteConnection(path: destinationPath, requireNewFile: true)
        var completed = false
        defer {
            if !completed { try? FileManager.default.removeItem(atPath: destinationPath) }
        }
        try destination.configure()

        guard let backup = sqlite3_backup_init(destination.handle, "main", handle, "main") else {
            throw destination.failure(sqlite3_errcode(destination.handle))
        }
        let stepStatus = sqlite3_backup_step(backup, -1)
        let finishStatus = sqlite3_backup_finish(backup)
        guard stepStatus == SQLITE_DONE else { throw failure(stepStatus) }
        guard finishStatus == SQLITE_OK else { throw destination.failure(finishStatus) }
        guard try destination.pragmaText("PRAGMA integrity_check") == "ok" else {
            throw SQLiteVaultError.integrityFailure
        }
        guard try !destination.hasRows("PRAGMA foreign_key_check") else {
            throw SQLiteVaultError.foreignKeyFailure
        }
        guard fsyncFile(at: destinationPath) else {
            throw SQLiteVaultError.filesystemFailure(errno)
        }
        completed = true
    }

    func replaceContents(from sourcePath: String) throws {
        let source = try SQLiteConnection(path: sourcePath)
        try source.configure()
        guard try source.pragmaText("PRAGMA integrity_check") == "ok",
              try !source.hasRows("PRAGMA foreign_key_check") else {
            throw SQLiteVaultError.integrityFailure
        }
        guard let backup = sqlite3_backup_init(handle, "main", source.handle, "main") else {
            throw failure(sqlite3_errcode(handle))
        }
        let stepStatus = sqlite3_backup_step(backup, -1)
        let finishStatus = sqlite3_backup_finish(backup)
        guard stepStatus == SQLITE_DONE, finishStatus == SQLITE_OK else {
            throw SQLiteVaultError.restoreFailed
        }
        guard try pragmaText("PRAGMA integrity_check") == "ok",
              try !hasRows("PRAGMA foreign_key_check") else {
            throw SQLiteVaultError.integrityFailure
        }
    }

    /// Runs one non-nested write transaction. The body cannot suspend, so actor reentrancy
    /// cannot interleave another operation between BEGIN and COMMIT.
    func withImmediateTransaction(_ body: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            try body()
            try execute("COMMIT")
        } catch {
            // Preserve the original failure; callers own any higher-level recovery policy.
            try? execute("ROLLBACK")
            throw error
        }
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

    func applicationID() throws -> Int32 {
        Int32(try pragmaInteger("PRAGMA application_id"))
    }

    func setPortableApplicationID(_ value: Int32) throws {
        try execute("PRAGMA application_id = \(value)")
    }

    func pragmaInteger(_ sql: String) throws -> Int64 {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        let status = sqlite3_step(statement)
        guard status == SQLITE_ROW else { throw failure(status) }
        return sqlite3_column_int64(statement, 0)
    }

    func pragmaText(_ sql: String) throws -> String {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        let status = sqlite3_step(statement)
        guard status == SQLITE_ROW, let value = sqlite3_column_text(statement, 0) else {
            throw failure(status)
        }
        return String(cString: value)
    }

    func hasRows(_ sql: String) throws -> Bool {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        let status = sqlite3_step(statement)
        switch status {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        default: throw failure(status)
        }
    }

    private func fsyncFile(at path: String) -> Bool {
        let descriptor = path.withCString { open($0, O_RDONLY | O_NOFOLLOW | O_CLOEXEC) }
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }
        return fsync(descriptor) == 0
    }

    func failure(_ status: Int32) -> SQLiteVaultError {
        let extendedStatus = sqlite3_extended_errcode(handle)
        if extendedStatus & 0xFF == SQLITE_CONSTRAINT {
            return .constraintViolation
        }
        return .databaseFailure(extendedStatus == SQLITE_OK ? status : extendedStatus)
    }
}
