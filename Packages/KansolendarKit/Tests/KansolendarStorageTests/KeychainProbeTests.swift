import Foundation
import Security
@testable import KansolendarStorage
import Testing

@Suite("Keychain probe")
struct KeychainProbeTests {
    @Test("creates user presence access control for the planned unlock model")
    func createsUserPresenceAccessControl() throws {
        let accessControl = try KeychainProbe.makeUserPresenceAccessControl()
        #expect(String(describing: accessControl).isEmpty == false)
    }

    @Test("attaches user presence protection to the Keychain item")
    func attachesUserPresenceProtectionToItem() throws {
        let accessControl = try KeychainProbe.makeUserPresenceAccessControl()
        let attributes = KeychainProbe.makeAddQuery(
            secret: Data(repeating: 0x01, count: 32),
            account: "test-\(UUID().uuidString)",
            accessControl: accessControl
        )

        #expect(attributes[kSecAttrAccessControl as String] != nil)
        #expect(attributes[kSecAttrAccessible as String] == nil)
        #expect(attributes[kSecAttrSynchronizable as String] as? Bool == false)
        #expect(attributes[kSecUseDataProtectionKeychain as String] as? Bool == true)
    }
}
