import CryptoKit
import Darwin
import Foundation

/// Stable app-container lock survives atomic replacement of the encrypted document inode.
/// The lock contains no key or document content. Never unlink it while other processes
/// may be waiting: that would allow two independent locks for the same path.
internal final class KansoFileLease: Sendable {
    let path: String
    private let descriptor: Int32

    init(url: URL) throws {
        let canonical = url.resolvingSymlinksInPath().standardizedFileURL
        path = canonical.path
        // File-panel access grants the selected document, not arbitrary sibling files.
        // Keep the stable editing lock in our private container instead of beside the vault.
        let lockDirectory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Kansolendar/DocumentLocks", isDirectory: true)
        try FileManager.default.createDirectory(at: lockDirectory, withIntermediateDirectories: true,
                                              attributes: [.posixPermissions: 0o700])
        let identity = SHA256.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined()
        let lockPath = lockDirectory.appendingPathComponent(identity + ".lock").path
        let fd = lockPath.withCString { Darwin.open($0, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK, 0o600) }
        guard fd >= 0 else { throw PrivateFileError.filesystemFailure(errno) }
        var status = stat()
        guard fstat(fd, &status) == 0, status.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
              status.st_uid == getuid(), status.st_nlink == 1, fchmod(fd, 0o600) == 0 else {
            close(fd)
            throw PrivateFileError.invalidSource
        }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            throw VaultStorageError.fileInUse
        }
        descriptor = fd
    }

    deinit { close(descriptor) }

    func read() throws -> Data {
        try PrivateFileReader.read(path, maximumBytes: KansoFileEnvelope.maximumFileBytes)
    }

    /// Stage only encrypted bytes beside the destination, then atomically replace.
    /// A digest detects external modifications even by programs ignoring our lock.
    func write(_ data: Data, replacing expected: Data?) throws {
        if let expected {
            guard try digest(read()) == expected else { throw VaultStorageError.fileChanged }
        } else if FileManager.default.fileExists(atPath: path) {
            throw PrivateFileError.destinationExists
        }
        let url = URL(fileURLWithPath: path)
        var coordinationError: NSError?
        var operationError: (any Error)?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { destination in
            do {
                // Foundation chooses a writable staging location on the destination volume
                // without requiring access to unrelated files in the user's directory.
                let stagingDirectory = try FileManager.default.url(
                    for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: destination, create: true
                )
                defer { try? FileManager.default.removeItem(at: stagingDirectory) }
                let stage = stagingDirectory.appendingPathComponent("encrypted.kanso").path
                try PrivateFileWriter.write(data, to: stage)
                if let expected {
                    guard try digest(read()) == expected else { throw VaultStorageError.fileChanged }
                    _ = try FileManager.default.replaceItemAt(destination, withItemAt: URL(fileURLWithPath: stage), options: .usingNewMetadataOnly)
                } else {
                    let result = stage.withCString { source in
                        destination.path.withCString { renamex_np(source, $0, UInt32(RENAME_EXCL)) }
                    }
                    guard result == 0 else {
                        if errno == EEXIST { throw PrivateFileError.destinationExists }
                        throw PrivateFileError.filesystemFailure(errno)
                    }
                }
                // Some sandbox grants do not permit opening the parent directory.
                // Encrypted staging is fsynced; sync directory metadata when accessible.
                let directory = destination.deletingLastPathComponent().path.withCString { Darwin.open($0, O_RDONLY | O_CLOEXEC) }
                if directory >= 0 {
                    defer { close(directory) }
                    guard fsync(directory) == 0 else { throw PrivateFileError.filesystemFailure(errno) }
                }
            } catch { operationError = error }
        }
        if let coordinationError { throw coordinationError }
        if let operationError { throw operationError }
    }

    func digest(_ data: Data) -> Data { Data(SHA256.hash(data: data)) }
}
