import CryptoKit
import Foundation
import KansolendarStorage
import Testing

@Suite("Envelope crypto probe")
struct EnvelopeCryptoProbeTests {
    @Test("round trips dummy payload")
    func roundTripsDummyPayload() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = try #require("dummy event payload".data(using: .utf8))

        let envelope = try EnvelopeCryptoProbe.seal(plaintext, using: key)
        let opened = try EnvelopeCryptoProbe.open(envelope, using: key)

        #expect(opened == plaintext)
        #expect(envelope != plaintext)
    }

    @Test("rejects tampered dummy payload")
    func rejectsTampering() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = try #require("dummy event payload".data(using: .utf8))
        var envelope = try EnvelopeCryptoProbe.seal(plaintext, using: key)
        envelope[envelope.index(before: envelope.endIndex)] ^= 0x01

        #expect(throws: (any Error).self) {
            _ = try EnvelopeCryptoProbe.open(envelope, using: key)
        }
    }
}
