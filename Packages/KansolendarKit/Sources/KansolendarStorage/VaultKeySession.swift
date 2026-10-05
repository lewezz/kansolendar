import CryptoKit
import Foundation

/// Mutable session state intended to be held only by the storage actor.
/// Key material can be reused internally for backups but never crosses the public vault API.
internal struct VaultKeySession {
    private(set) var generation = UUID()
    private var key: SymmetricKey?

    init() {}

    var isUnlocked: Bool {
        key != nil
    }

    mutating func unlock(with key: SymmetricKey) -> UUID {
        generation = UUID()
        self.key = key
        return generation
    }

    mutating func lock() -> UUID {
        key = nil
        // Replacing the token invalidates any operation that captured the previous session.
        generation = UUID()
        return generation
    }

    func keyMaterial(expectedGeneration: UUID) throws -> SymmetricKey {
        try key(for: expectedGeneration)
    }

    func seal(
        _ plaintext: Data,
        context: PayloadContext,
        expectedGeneration: UUID
    ) throws -> Data {
        let key = try key(for: expectedGeneration)
        return try PayloadEnvelope.seal(plaintext, using: key, context: context)
    }

    func open(
        _ envelope: Data,
        context: PayloadContext,
        expectedGeneration: UUID
    ) throws -> Data {
        let key = try key(for: expectedGeneration)
        return try PayloadEnvelope.open(envelope, using: key, context: context)
    }

    private func key(for expectedGeneration: UUID) throws -> SymmetricKey {
        guard let key else {
            throw VaultKeySessionError.locked
        }
        guard expectedGeneration == generation else {
            throw VaultKeySessionError.staleGeneration
        }
        return key
    }
}

internal enum VaultKeySessionError: Error, Equatable, Sendable {
    case locked
    case staleGeneration
}
