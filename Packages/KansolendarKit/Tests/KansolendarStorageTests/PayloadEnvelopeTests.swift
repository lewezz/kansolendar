import CryptoKit
import Foundation
@testable import KansolendarStorage
import Testing

@Suite("Payload envelope v1")
struct PayloadEnvelopeTests {
    private let key = SymmetricKey(data: Data(repeating: 0x01, count: 32))
    private let nonce = try! AES.GCM.Nonce(data: Data(repeating: 0x02, count: 12))
    private let context = PayloadContext(
        vaultID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        keyID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        recordKind: .event,
        recordID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        parentID: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    )

    @Test("round trips payload with row identity authenticated")
    func roundTripsPayload() throws {
        let plaintext = Data("fixed test event".utf8)
        let envelope = try PayloadEnvelope.seal(plaintext, using: key, context: context, nonce: nonce)
        let encodedHex = envelope.map { String(format: "%02x", $0) }.joined()

        #expect(try PayloadEnvelope.open(envelope, using: key, context: context) == plaintext)
        #expect(envelope.prefix(5) == Data([0x4B, 0x4E, 0x53, 0x4C, 0x01]))
        let expectedSize = 33 + plaintext.count
        #expect(envelope.count == expectedSize)
        #expect(encodedHex == "4b4e534c0102020202020202020202020261bfb12c2e77b598a0b89cad2ac2acc6f264b8a94deb1000a70ca04737ce2075")
    }

    @Test("rejects changing any authenticated row identity")
    func rejectsContextMismatch() throws {
        let envelope = try PayloadEnvelope.seal(Data("payload".utf8), using: key, context: context, nonce: nonce)
        let changedContexts = [
            PayloadContext(vaultID: UUID(), keyID: context.keyID, recordKind: context.recordKind, recordID: context.recordID, parentID: context.parentID),
            PayloadContext(vaultID: context.vaultID, keyID: UUID(), recordKind: context.recordKind, recordID: context.recordID, parentID: context.parentID),
            PayloadContext(vaultID: context.vaultID, keyID: context.keyID, recordKind: .calendar, recordID: context.recordID, parentID: context.parentID),
            PayloadContext(vaultID: context.vaultID, keyID: context.keyID, recordKind: context.recordKind, recordID: UUID(), parentID: context.parentID),
            PayloadContext(vaultID: context.vaultID, keyID: context.keyID, recordKind: context.recordKind, recordID: context.recordID)
        ]

        for changedContext in changedContexts {
            #expect(throws: PayloadEnvelopeError.authenticationFailed) {
                _ = try PayloadEnvelope.open(envelope, using: key, context: changedContext)
            }
        }
    }

    @Test("rejects mutations, truncation, unknown versions, and oversized payloads")
    func rejectsMalformedInputs() throws {
        let plaintext = Data("payload".utf8)
        let valid = try PayloadEnvelope.seal(plaintext, using: key, context: context, nonce: nonce)
        for offset in [5, 17, valid.count - 1] {
            var changed = valid
            changed[changed.index(changed.startIndex, offsetBy: offset)] ^= 0x80
            #expect(throws: PayloadEnvelopeError.authenticationFailed) {
                _ = try PayloadEnvelope.open(changed, using: key, context: context)
            }
        }
        #expect(throws: PayloadEnvelopeError.malformed) {
            _ = try PayloadEnvelope.open(Data(valid.prefix(20)), using: key, context: context)
        }

        var invalidMagic = valid
        invalidMagic[invalidMagic.startIndex] ^= 0x01
        #expect(throws: PayloadEnvelopeError.malformed) {
            _ = try PayloadEnvelope.open(invalidMagic, using: key, context: context)
        }

        var unknownVersion = valid
        unknownVersion[unknownVersion.index(valid.startIndex, offsetBy: 4)] = 0x7F
        #expect(throws: PayloadEnvelopeError.unsupportedVersion(0x7F)) {
            _ = try PayloadEnvelope.open(unknownVersion, using: key, context: context)
        }
        #expect(throws: PayloadEnvelopeError.payloadTooLarge) {
            _ = try PayloadEnvelope.seal(
                Data(repeating: 0, count: PayloadEnvelope.maximumPayloadSize + 1),
                using: key,
                context: context,
                nonce: nonce
            )
        }
    }
}
