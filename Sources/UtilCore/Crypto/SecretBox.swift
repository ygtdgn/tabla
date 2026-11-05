import Foundation
import CryptoKit

/// AES-GCM ile mühürleme. Çıktı: nonce + ciphertext + tag (`combined`).
public enum SecretBox {
    public enum Failure: Error { case sealFailed }

    public static func seal(_ plaintext: Data, using key: SymmetricKey) throws -> Data {
        guard let combined = try AES.GCM.seal(plaintext, using: key).combined else {
            throw Failure.sealFailed
        }
        return combined
    }

    public static func open(_ box: Data, using key: SymmetricKey) throws -> Data {
        try AES.GCM.open(AES.GCM.SealedBox(combined: box), using: key)
    }
}
