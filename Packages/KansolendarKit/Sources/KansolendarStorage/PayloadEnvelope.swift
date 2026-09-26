import CryptoKit
import Foundation

public enum PayloadRecordKind: UInt8, Sendable {
    case control = 0x01
    case calendar = 0x10
    case event = 0x11
    case reminder = 0x12
    case eventException = 0x13
}

public struct PayloadContext: Sendable, Equatable {
    public let vaultID: UUID
    public let keyID: UUID
    public let recordKind: PayloadRecordKind
    public let recordID: UUID
    public let parentID: UUID?

    public init(
        vaultID: UUID,
        keyID: UUID,
        recordKind: PayloadRecordKind,
        recordID: UUID,
        parentID: UUID? = nil
    ) {
        self.vaultID = vaultID
        self.keyID = keyID
        self.recordKind = recordKind
        self.recordID = recordID
        self.parentID = parentID
    }
}

public enum PayloadEnvelopeError: Error, Equatable {
    case malformed
    case unsupportedVersion(UInt8)
    case payloadTooLarge
    case authenticationFailed
}

/// Versioned AES-GCM payload format. This authenticates each payload and its row identity;
/// it does not authenticate the existence or freshness of the database as a whole.
public enum PayloadEnvelope {
    public static let version: UInt8 = 1
    public static let maximumPayloadSize = 131_072

    private static let magic = Data([0x4B, 0x4E, 0x53, 0x4C]) // KNSL
    private static let nonceSize = 12
    private static let tagSize = 16
    private static let fixedSize = magic.count + 1 + nonceSize + tagSize
    private static let aadDomain = Data("com.kansolendar.payload".utf8)

    /// Layout: magic[4] | version[1] | nonce[12] | ciphertext[n] | tag[16].
    public static func seal(
        _ plaintext: Data,
        using key: SymmetricKey,
        context: PayloadContext
    ) throws -> Data {
        try seal(plaintext, using: key, context: context, nonce: AES.GCM.Nonce())
    }

    static func seal(
        _ plaintext: Data,
        using key: SymmetricKey,
        context: PayloadContext,
        nonce: AES.GCM.Nonce
    ) throws -> Data {
        guard plaintext.count <= maximumPayloadSize else {
            throw PayloadEnvelopeError.payloadTooLarge
        }

        let sealedBox = try AES.GCM.seal(
            plaintext,
            using: key,
            nonce: nonce,
            authenticating: authenticatedData(for: context)
        )

        var envelope = magic
        envelope.append(version)
        nonce.withUnsafeBytes { envelope.append(contentsOf: $0) }
        envelope.append(sealedBox.ciphertext)
        envelope.append(sealedBox.tag)
        return envelope
    }

    public static func open(
        _ envelope: Data,
        using key: SymmetricKey,
        context: PayloadContext
    ) throws -> Data {
        guard envelope.count >= fixedSize,
              envelope.count <= fixedSize + maximumPayloadSize,
              envelope.prefix(magic.count).elementsEqual(magic)
        else {
            throw PayloadEnvelopeError.malformed
        }

        let versionIndex = envelope.index(envelope.startIndex, offsetBy: magic.count)
        let envelopeVersion = envelope[versionIndex]
        guard envelopeVersion == version else {
            throw PayloadEnvelopeError.unsupportedVersion(envelopeVersion)
        }

        let nonceStart = envelope.index(after: versionIndex)
        let nonceEnd = envelope.index(nonceStart, offsetBy: nonceSize)
        let tagStart = envelope.index(envelope.endIndex, offsetBy: -tagSize)
        guard nonceEnd <= tagStart else {
            throw PayloadEnvelopeError.malformed
        }

        do {
            let nonce = try AES.GCM.Nonce(data: envelope[nonceStart..<nonceEnd])
            let box = try AES.GCM.SealedBox(
                nonce: nonce,
                ciphertext: envelope[nonceEnd..<tagStart],
                tag: envelope[tagStart...]
            )
            return try AES.GCM.open(
                box,
                using: key,
                authenticating: authenticatedData(for: context)
            )
        } catch {
            throw PayloadEnvelopeError.authenticationFailed
        }
    }

    private static func authenticatedData(for context: PayloadContext) -> Data {
        var data = aadDomain
        data.append(0)
        data.append(magic)
        data.append(version)
        data.append(uuidBytes(context.vaultID))
        data.append(uuidBytes(context.keyID))
        data.append(context.recordKind.rawValue)
        data.append(uuidBytes(context.recordID))
        if let parentID = context.parentID {
            data.append(1)
            data.append(uuidBytes(parentID))
        } else {
            data.append(0)
        }
        return data
    }

    private static func uuidBytes(_ id: UUID) -> Data {
        var uuid = id.uuid
        return withUnsafeBytes(of: &uuid) { Data($0) }
    }
}
