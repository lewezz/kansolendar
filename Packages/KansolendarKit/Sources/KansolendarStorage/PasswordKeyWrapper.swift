import CommonCrypto
import CryptoKit
import Foundation
import Security

/// Persisted KDF parameters and authenticated ciphertext; never contains the password or plaintext key.
internal struct PasswordWrappedKeyRecord: Codable, Sendable {
    let formatVersion: Int
    let iterations: UInt32
    let salt: Data
    let sealedKey: Data
}

internal enum PasswordKeyWrapper {
    // These sizes and the AAD domain are part of the v1 on-disk contract.
    private static let keyByteCount = 32
    private static let sealedKeyByteCount = 60 // GCM nonce (12) + key (32) + tag (16).

    static func wrap(_ key: SymmetricKey, password: String, vaultID: UUID, keyID: UUID) throws -> PasswordWrappedKeyRecord {
        let salt = try randomBytes(count: VaultPassword.saltLength)
        let wrappingKey = try derive(password: password, salt: salt)
        let sealed = try AES.GCM.seal(
            key.withUnsafeBytes { Data($0) },
            using: wrappingKey,
            authenticating: context(vaultID: vaultID, keyID: keyID)
        )
        guard let combined = sealed.combined else { throw VaultKeyStoreError.invalidKeyMaterial }
        return PasswordWrappedKeyRecord(formatVersion: 1, iterations: VaultPassword.iterations, salt: salt, sealedKey: combined)
    }

    static func unwrap(_ record: PasswordWrappedKeyRecord, password: String, vaultID: UUID, keyID: UUID) throws -> SymmetricKey {
        // Validate before running PBKDF so malformed files cannot request arbitrary KDF work.
        guard record.formatVersion == 1, record.iterations == VaultPassword.iterations,
              record.salt.count == VaultPassword.saltLength, record.sealedKey.count == sealedKeyByteCount else {
            throw VaultKeyStoreError.invalidKeyMaterial
        }
        let wrappingKey = try derive(password: password, salt: record.salt)
        let box = try AES.GCM.SealedBox(combined: record.sealedKey)
        let bytes = try AES.GCM.open(
            box, using: wrappingKey,
            authenticating: context(vaultID: vaultID, keyID: keyID)
        )
        guard bytes.count == keyByteCount else { throw VaultKeyStoreError.invalidKeyMaterial }
        return SymmetricKey(data: bytes)
    }

    private static func derive(password: String, salt: Data) throws -> SymmetricKey {
        guard VaultPassword.isAcceptable(password), salt.count == VaultPassword.saltLength else {
            throw VaultKeyStoreError.invalidKeyMaterial
        }
        var output = [UInt8](repeating: 0, count: keyByteCount)
        let status = password.withCString { passwordPtr in
            salt.withUnsafeBytes { saltBuffer -> Int32 in
                guard let saltBytes = saltBuffer.bindMemory(to: UInt8.self).baseAddress else {
                    return -1
                }
                return CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2), passwordPtr, password.utf8.count,
                    saltBytes, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), VaultPassword.iterations,
                    &output, output.count
                )
            }
        }
        guard status == kCCSuccess else { throw VaultKeyStoreError.invalidKeyMaterial }
        return SymmetricKey(data: output)
    }

    private static func randomBytes(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else {
            throw VaultKeyStoreError.keychainFailure(-1)
        }
        return Data(bytes)
    }

    // Binding both identities prevents a wrapped key from being transplanted to another vault.
    private static func context(vaultID: UUID, keyID: UUID) -> Data {
        var data = Data("Kansolendar-DEK-wrap-v1".utf8)
        var vault = vaultID.uuid
        var key = keyID.uuid
        withUnsafeBytes(of: &vault) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &key) { data.append(contentsOf: $0) }
        return data
    }
}

public enum VaultPassword {
    internal static let iterations: UInt32 = 600_000
    internal static let saltLength = 16
    public static let minimumLength = 15

    public static func isAcceptable(_ password: String) -> Bool {
        password.unicodeScalars.count >= minimumLength &&
            password.utf8.count <= 1024 &&
            password.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
    }
}
