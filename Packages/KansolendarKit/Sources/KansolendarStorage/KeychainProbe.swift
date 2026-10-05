import Foundation
import LocalAuthentication
import Security

enum KeychainProbe {
    static let service = "local.kansolendar.security-probe"

    static func makeUserPresenceAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            &error
        )

        guard let accessControl else {
            throw KeychainProbeError.accessControl(error?.takeRetainedValue())
        }

        return accessControl
    }

    static func store(_ secret: Data, account: String) throws {
        let accessControl = try makeUserPresenceAccessControl()

        let query = makeAddQuery(secret: secret, account: account, accessControl: accessControl)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainProbeError.status(status)
        }
    }

    static func makeAddQuery(
        secret: Data,
        account: String,
        accessControl: SecAccessControl
    ) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessControl as String: accessControl,
            kSecAttrSynchronizable as String: false,
            kSecUseDataProtectionKeychain as String: true,
            kSecValueData as String: secret
        ]
    }

    static func load(account: String) throws -> Data {
        let authenticationContext = LAContext()
        authenticationContext.localizedReason = "Unlock a Kansolendar development key"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
            kSecUseAuthenticationContext as String: authenticationContext,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess else {
            throw KeychainProbeError.status(status)
        }

        guard let data = item as? Data else {
            throw KeychainProbeError.unexpectedItem
        }

        return data
    }

    static func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainProbeError.status(status)
        }
    }
}

enum KeychainProbeError: Error, Equatable {
    public static func == (lhs: KeychainProbeError, rhs: KeychainProbeError) -> Bool {
        switch (lhs, rhs) {
        case let (.status(lhsStatus), .status(rhsStatus)):
            lhsStatus == rhsStatus
        case (.unexpectedItem, .unexpectedItem):
            true
        case (.accessControl, .accessControl):
            true
        default:
            false
        }
    }

    case status(OSStatus)
    case unexpectedItem
    case accessControl(CFError?)
}
