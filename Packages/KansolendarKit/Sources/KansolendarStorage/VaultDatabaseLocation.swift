import Darwin
import Foundation

internal enum VaultDatabaseLocationError: Error, Equatable, Sendable {
    case filesystemFailure(Int32)
    case unsafeDirectory
}

internal enum VaultDatabaseLocation {
    static func applicationSupportURL(fileManager: FileManager = .default) throws -> URL {
        let root = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return try databaseURL(applicationSupportRoot: root, fileManager: fileManager)
    }

    static func databaseURL(applicationSupportRoot: URL, fileManager: FileManager = .default) throws -> URL {
        let directory = applicationSupportRoot.appendingPathComponent("Kansolendar", isDirectory: true)
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )
        } catch let error as CocoaError where error.code == .fileWriteFileExists {
            // Validate the existing entry below without resolving a symlink.
        } catch {
            throw VaultDatabaseLocationError.filesystemFailure(Int32(truncatingIfNeeded: (error as NSError).code))
        }

        var info = stat()
        guard lstat(directory.path, &info) == 0 else {
            throw VaultDatabaseLocationError.filesystemFailure(errno)
        }
        guard info.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR), info.st_uid == getuid() else {
            throw VaultDatabaseLocationError.unsafeDirectory
        }
        guard chmod(directory.path, mode_t(S_IRWXU)) == 0 else {
            throw VaultDatabaseLocationError.filesystemFailure(errno)
        }

        return directory.appendingPathComponent("vault.sqlite", isDirectory: false)
    }
}
