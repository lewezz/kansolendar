import CryptoKit
import Foundation
@testable import KansolendarStorage
import Testing

@Suite("Vault key session")
struct VaultKeySessionTests {
    private let context = PayloadContext(
        vaultID: UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!,
        keyID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
        recordKind: .event,
        recordID: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!
    )

    @Test("locked session cannot read or write encrypted payloads")
    func lockedSessionCannotUseKey() {
        let session = VaultKeySession()

        #expect(!session.isUnlocked)
        #expect(throws: VaultKeySessionError.locked) {
            _ = try session.seal(Data("secret".utf8), context: context, expectedGeneration: session.generation)
        }
        #expect(throws: VaultKeySessionError.locked) {
            _ = try session.open(Data(), context: context, expectedGeneration: session.generation)
        }
    }

    @Test("unlock permits authenticated payload access only for its generation")
    func unlockedSessionUsesCurrentGeneration() throws {
        var session = VaultKeySession()
        let key = SymmetricKey(data: Data(repeating: 0x5A, count: 32))
        let previousGeneration = session.generation
        let activeGeneration = session.unlock(with: key)
        let plaintext = Data("private calendar entry".utf8)

        #expect(session.isUnlocked)
        #expect(activeGeneration != previousGeneration)
        let envelope = try session.seal(plaintext, context: context, expectedGeneration: activeGeneration)
        #expect(try session.open(envelope, context: context, expectedGeneration: activeGeneration) == plaintext)
        #expect(throws: VaultKeySessionError.staleGeneration) {
            _ = try session.open(envelope, context: context, expectedGeneration: previousGeneration)
        }
    }

    @Test("locking invalidates prior work and removes key access")
    func lockInvalidatesPriorGeneration() throws {
        var session = VaultKeySession()
        let generation = session.unlock(with: SymmetricKey(data: Data(repeating: 0x3C, count: 32)))
        let envelope = try session.seal(Data("secret".utf8), context: context, expectedGeneration: generation)
        let lockedGeneration = session.lock()

        #expect(!session.isUnlocked)
        #expect(lockedGeneration != generation)
        #expect(throws: VaultKeySessionError.locked) {
            _ = try session.open(envelope, context: context, expectedGeneration: generation)
        }
    }
}
