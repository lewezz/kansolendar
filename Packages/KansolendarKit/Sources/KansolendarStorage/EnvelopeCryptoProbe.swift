import CryptoKit
import Foundation

public enum EnvelopeCryptoProbe {
    public static func seal(_ plaintext: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(plaintext, using: key)

        guard let combined = sealedBox.combined else {
            throw EnvelopeCryptoProbeError.missingCombinedRepresentation
        }

        return combined
    }

    public static func open(_ combinedEnvelope: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: combinedEnvelope)
        return try AES.GCM.open(sealedBox, using: key)
    }
}

public enum EnvelopeCryptoProbeError: Error, Equatable {
    case missingCombinedRepresentation
}
