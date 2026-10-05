import Darwin
import Foundation

internal enum PrivateFileError: Error, Equatable, Sendable {
    case invalidSource
    case destinationExists
    case filesystemFailure(Int32)
}

internal enum PrivateFileReader {
    static func read(_ path: String, maximumBytes: Int) throws -> Data {
        let source = try PrivateFileDescriptor.openSource(path, maximumBytes: maximumBytes)
        defer { close(source.descriptor) }
        var data = Data()
        data.reserveCapacity(source.byteCount)
        var buffer = [UInt8](repeating: 0, count: PrivateFileDescriptor.bufferByteCount)
        while true {
            let count = buffer.withUnsafeMutableBytes {
                Darwin.read(source.descriptor, $0.baseAddress, $0.count)
            }
            if count < 0, errno == EINTR { continue }
            guard count >= 0 else { throw PrivateFileError.filesystemFailure(errno) }
            if count == 0 { return data }
            // The file can grow after fstat; enforce the bound while reading as well.
            guard count <= maximumBytes - data.count else { throw PrivateFileError.invalidSource }
            data.append(contentsOf: buffer.prefix(count))
        }
    }
}

internal enum PrivateFileWriter {
    static func write(_ data: Data, to path: String) throws {
        try PrivateFileDescriptor.withNewFile(at: path) { descriptor in
            try data.withUnsafeBytes { try PrivateFileDescriptor.writeAll($0, to: descriptor) }
        }
    }
}

/// Descriptor rules reject unsafe vault files before reading or writing content.
/// Callers own successful source descriptors; new destination descriptors stay scoped here.
private enum PrivateFileDescriptor {
    static let bufferByteCount = 64 * 1_024

    static func openSource(
        _ path: String,
        maximumBytes: Int,
        allowEmpty: Bool = true
    ) throws -> (descriptor: Int32, byteCount: Int) {
        guard maximumBytes >= 0 else { throw PrivateFileError.invalidSource }
        // O_NONBLOCK avoids waiting on a FIFO before we can reject it with fstat.
        let descriptor = path.withCString { open($0, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK) }
        guard descriptor >= 0 else { throw PrivateFileError.filesystemFailure(errno) }
        do {
            var info = stat()
            guard fstat(descriptor, &info) == 0 else { throw PrivateFileError.filesystemFailure(errno) }
            // Validate the opened inode, not a path that may have changed since lookup.
            guard info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
                  info.st_uid == getuid(),
                  info.st_size >= (allowEmpty ? 0 : 1),
                  info.st_size <= maximumBytes else {
                throw PrivateFileError.invalidSource
            }
            return (descriptor, Int(info.st_size))
        } catch {
            close(descriptor)
            throw error
        }
    }

    static func withNewFile(at path: String, write: (Int32) throws -> Void) throws {
        let descriptor = path.withCString {
            open($0, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, mode_t(S_IRUSR | S_IWUSR))
        }
        guard descriptor >= 0 else {
            if errno == EEXIST { throw PrivateFileError.destinationExists }
            throw PrivateFileError.filesystemFailure(errno)
        }
        var completed = false
        defer {
            close(descriptor)
            // Reservation failures return before cleanup is installed; remove incomplete outputs.
            if !completed { unlink(path) }
        }
        try write(descriptor)
        guard fsync(descriptor) == 0 else { throw PrivateFileError.filesystemFailure(errno) }
        completed = true
    }

    static func writeAll(_ bytes: UnsafeRawBufferPointer, to descriptor: Int32) throws {
        guard let base = bytes.baseAddress else { return }
        var offset = 0
        while offset < bytes.count {
            let count = Darwin.write(descriptor, base.advanced(by: offset), bytes.count - offset)
            if count < 0, errno == EINTR { continue }
            guard count > 0 else { throw PrivateFileError.filesystemFailure(errno) }
            offset += count
        }
    }
}
