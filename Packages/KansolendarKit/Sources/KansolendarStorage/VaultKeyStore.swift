import CryptoKit
import Foundation

internal protocol VaultKeyStore: Sendable {
    func create(vaultID: UUID, keyID: UUID) async throws -> SymmetricKey
    func load(vaultID: UUID, keyID: UUID) async throws -> SymmetricKey
    func delete(vaultID: UUID, keyID: UUID) async throws
}
