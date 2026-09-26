import CryptoKit
import Foundation
import Security
@testable import KansolendarStorage
import Testing

@Suite("Vault key storage contract")
struct KeychainVaultKeyStoreTests {
    private let vaultID = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
    private let keyID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    @Test("item identity is stable and scoped to a vault key")
    func itemIdentityIsStableAndScoped() {
        let account = KeychainVaultKeyStore.account(vaultID: vaultID, keyID: keyID)

        #expect(account == "vault:aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee:key:11111111-2222-3333-4444-555555555555")
        #expect(account != KeychainVaultKeyStore.account(vaultID: UUID(), keyID: keyID))
    }

    @Test("key item uses local Data Protection Keychain and user presence")
    func keyItemUsesLocalProtection() throws {
        let accessControl = try KeychainVaultKeyStore.makeUserPresenceAccessControl()
        let attributes = KeychainVaultKeyStore.makeAddQuery(
            keyData: Data(repeating: 0xA5, count: 32),
            vaultID: vaultID,
            keyID: keyID,
            accessControl: accessControl
        )

        #expect(attributes[kSecAttrService as String] as? String == KeychainVaultKeyStore.service)
        #expect(attributes[kSecAttrAccount as String] as? String == KeychainVaultKeyStore.account(vaultID: vaultID, keyID: keyID))
        #expect(attributes[kSecAttrAccessControl as String] != nil)
        #expect(attributes[kSecAttrAccessible as String] == nil)
        #expect(attributes[kSecAttrSynchronizable as String] as? Bool == false)
        #expect(attributes[kSecUseDataProtectionKeychain as String] as? Bool == true)
        #expect(attributes[kSecAttrAccessGroup as String] == nil)
    }

    @Test("Keychain failures stay typed and do not suggest fallback")
    func keychainFailuresStayTyped() {
        #expect(KeychainVaultKeyStore.error(for: errSecItemNotFound) == .missingKey)
        #expect(KeychainVaultKeyStore.error(for: errSecUserCanceled) == .userCancelled)
        #expect(KeychainVaultKeyStore.error(for: errSecMissingEntitlement) == .missingEntitlement)
        #expect(KeychainVaultKeyStore.error(for: errSecAuthFailed) == .accessDenied)
    }

    @Test("new DEKs have AES-256 key size")
    func generatedKeyHasAES256Size() {
        let key = KeychainVaultKeyStore.generateDataEncryptionKey()
        #expect(key.bitCount == 256)
    }

    @Test("stored key material must be exactly 32 bytes")
    func storedKeyMaterialMustHaveExpectedLength() throws {
        let valid = try KeychainVaultKeyStore.makeDataEncryptionKey(from: Data(repeating: 0xA5, count: 32))
        #expect(valid.bitCount == 256)
        #expect(throws: VaultKeyStoreError.invalidKeyMaterial) {
            _ = try KeychainVaultKeyStore.makeDataEncryptionKey(from: Data(repeating: 0xA5, count: 31))
        }
    }
}
