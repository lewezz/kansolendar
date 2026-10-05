import CryptoKit
import Foundation

/// Whole-document encryption. Only bounded cryptographic parameters are public.
/// An authenticated header prevents parameter substitution and ciphertext transplantation.
internal enum KansoFileEnvelope {
    static let magic = Data([0x4B, 0x41, 0x4E, 0x53, 0x4F, 0x00, 0x03, 0x00])
    static let maximumPlaintextBytes = 64 * 1_024 * 1_024
    static let maximumFileBytes = maximumPlaintextBytes + 4_096 + 40
    private static let maximumHeaderBytes = 4_096

    struct Header: Codable, Sendable {
        // Random cryptographic identities, not calendar/event IDs or the document title.
        let vaultID: UUID
        let keyID: UUID
        let wrappedKey: PasswordWrappedKeyRecord
    }

    struct Session: Sendable {
        let headerBytes: Data
        let key: SymmetricKey
    }

    static func createSession(password: String) throws -> Session {
        guard VaultPassword.isAcceptable(password) else { throw VaultStorageError.invalidInput }
        let key = SymmetricKey(size: .bits256)
        let vaultID = UUID(), keyID = UUID()
        let header = Header(
            vaultID: vaultID, keyID: keyID,
            wrappedKey: try PasswordKeyWrapper.wrap(key, password: password, vaultID: vaultID, keyID: keyID)
        )
        return Session(headerBytes: try JSONEncoder().encode(header), key: key)
    }

    static func seal(_ document: KansoDocument, session: Session) throws -> Data {
        let plaintext = try KansoDocumentCodec.encode(document)
        let prefix = try authenticatedPrefix(headerBytes: session.headerBytes)
        let sealed = try AES.GCM.seal(plaintext, using: session.key, authenticating: prefix)
        guard let combined = sealed.combined else { throw VaultStorageError.corruptVault }
        return prefix + combined
    }

    static func open(_ file: Data, password: String) throws -> (KansoDocument, Session) {
        let (headerBytes, prefix, ciphertext) = try split(file)
        let header = try JSONDecoder().decode(Header.self, from: headerBytes)
        let key: SymmetricKey
        do {
            key = try PasswordKeyWrapper.unwrap(
                header.wrappedKey, password: password, vaultID: header.vaultID, keyID: header.keyID
            )
        } catch is CryptoKitError {
            throw VaultStorageError.authenticationFailed
        }
        let plaintext: Data
        do {
            plaintext = try AES.GCM.open(AES.GCM.SealedBox(combined: ciphertext), using: key, authenticating: prefix)
        } catch {
            throw VaultStorageError.corruptVault
        }
        return (try KansoDocumentCodec.decode(plaintext), Session(headerBytes: headerBytes, key: key))
    }

    /// Shape checks before asking for a password; never decodes the encrypted inventory.
    static func validateStructure(_ file: Data) throws {
        let (bytes, _, _) = try split(file)
        let header = try JSONDecoder().decode(Header.self, from: bytes)
        guard header.wrappedKey.formatVersion == 1,
              header.wrappedKey.iterations == VaultPassword.iterations,
              header.wrappedKey.salt.count == VaultPassword.saltLength,
              header.wrappedKey.sealedKey.count == 60 else { throw VaultStorageError.corruptVault }
    }

    private static func authenticatedPrefix(headerBytes: Data) throws -> Data {
        guard !headerBytes.isEmpty, headerBytes.count <= maximumHeaderBytes else { throw VaultStorageError.corruptVault }
        let size = UInt32(headerBytes.count)
        return magic + Data([UInt8(size >> 24), UInt8((size >> 16) & 255), UInt8((size >> 8) & 255), UInt8(size & 255)]) + headerBytes
    }

    private static func split(_ file: Data) throws -> (Data, Data, Data) {
        guard file.count >= 12 + 28, file.count <= maximumFileBytes,
              file.prefix(8) == magic else { throw VaultStorageError.corruptVault }
        let size = file[8..<12].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard size > 0, size <= maximumHeaderBytes,
              Int(size) <= file.count - 12 - 28 else { throw VaultStorageError.corruptVault }
        let end = 12 + Int(size)
        return (Data(file[12..<end]), Data(file[..<end]), Data(file[end...]))
    }
}
