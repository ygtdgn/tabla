import Foundation
import CryptoKit
import Security

public protocol KeyProvider: Sendable {
    func symmetricKey() throws -> SymmetricKey
}

/// Testler için: anahtar yalnızca bellekte yaşar.
public struct InMemoryKeyProvider: KeyProvider {
    private let key: SymmetricKey

    public init(key: SymmetricKey = SymmetricKey(size: .bits256)) {
        self.key = key
    }

    public func symmetricKey() throws -> SymmetricKey { key }
}

/// Anahtarı Keychain'de saklar; yoksa 32 rastgele bayt üretip ekler.
public struct KeychainKeyProvider: KeyProvider {
    public enum Failure: Error {
        case randomFailed(OSStatus)
        case keychain(OSStatus)
        case malformedItem
    }

    private let service: String
    private let account: String

    public init(service: String, account: String) {
        self.service = service
        self.account = account
    }

    public func symmetricKey() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, data.count == 32 else { throw Failure.malformedItem }
            return SymmetricKey(data: data)
        case errSecItemNotFound:
            return try createKey()
        default:
            throw Failure.keychain(status)
        }
    }

    private func createKey() throws -> SymmetricKey {
        var bytes = [UInt8](repeating: 0, count: 32)
        let randomStatus = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard randomStatus == errSecSuccess else { throw Failure.randomFailed(randomStatus) }

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(bytes),
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw Failure.keychain(status) }
        return SymmetricKey(data: bytes)
    }
}
