import CryptoKit
import Foundation
@testable import KansolendarStorage
import Testing

@Suite("Portable vault password wrapper")
struct PasswordKeyWrapperTests {
    @Test("password policy accepts long passphrases without composition rules")
    func validatesUserPassword() {
        #expect(VaultPassword.minimumLength == 15)
        #expect(VaultPassword.isAcceptable("purple tulip moonlight"))
        #expect(VaultPassword.isAcceptable("áéíóú ñáéíóú üáéí"))
        #expect(!VaultPassword.isAcceptable("too-short"))
        #expect(!VaultPassword.isAcceptable("a password with\ncontrol"))
    }

    @Test("wrapped data key survives serialization and rejects an incorrect password")
    func wrappedKeyRoundTrip() throws {
        let vaultID = UUID()
        let keyID = UUID()
        let password = "purple tulip moonlight"
        let original = SymmetricKey(size: .bits256)
        let record = try PasswordKeyWrapper.wrap(original, password: password, vaultID: vaultID, keyID: keyID)
        let serialized = try JSONEncoder().encode(record)
        let reopenedRecord = try JSONDecoder().decode(PasswordWrappedKeyRecord.self, from: serialized)
        let restored = try PasswordKeyWrapper.unwrap(reopenedRecord, password: password, vaultID: vaultID, keyID: keyID)
        #expect(original == restored)

        #expect(throws: (any Error).self) {
            try PasswordKeyWrapper.unwrap(reopenedRecord, password: "different phrase not matching", vaultID: vaultID, keyID: keyID)
        }
    }

    @Test("altered wrapped key record cannot unlock")
    func tamperedRecordFailsClosed() throws {
        let vaultID = UUID()
        let keyID = UUID()
        let password = "purple tulip moonlight"
        let originalRecord = try PasswordKeyWrapper.wrap(
            SymmetricKey(size: .bits256), password: password, vaultID: vaultID, keyID: keyID
        )
        var tamperedSealedKey = originalRecord.sealedKey
        tamperedSealedKey[tamperedSealedKey.index(before: tamperedSealedKey.endIndex) - 1] ^= 1
        let record = PasswordWrappedKeyRecord(
            formatVersion: originalRecord.formatVersion,
            iterations: originalRecord.iterations,
            salt: originalRecord.salt,
            sealedKey: tamperedSealedKey
        )

        #expect(throws: (any Error).self) {
            try PasswordKeyWrapper.unwrap(record, password: password, vaultID: vaultID, keyID: keyID)
        }
    }
}
