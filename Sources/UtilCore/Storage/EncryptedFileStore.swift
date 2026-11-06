import CryptoKit
import Foundation

/// Düz (alt dizinsiz) adlarla şifreli dosya deposu. Dizin 0700, dosyalar 0600.
/// Anahtar ilk başarılı okumadan sonra bellekte tutulur; başarısız okuma tutulmaz, sonraki işlem yeniden dener.
public final class EncryptedFileStore {
    public enum Failure: Error {
        case invalidName(String)
        /// Anahtar sağlayıcı (Keychain) anahtarı veremedi. Dosyalar bozuk değildir; daha sonra yeniden denenebilir.
        case keyUnavailable(any Error)
    }

    private let directory: URL
    private let keyProvider: KeyProvider
    private let fileManager = FileManager.default
    private var cachedKey: SymmetricKey?

    public init(directory: URL, keyProvider: KeyProvider) throws {
        self.directory = directory
        self.keyProvider = keyProvider
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        // Dizin önceden varsa da izinleri sıkılaştır.
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }

    /// Anahtarı şimdi okur, böylece anahtar hatası hiçbir dosyaya dokunulmadan ortaya çıkar.
    public func prepareKey() throws {
        _ = try key()
    }

    public func write(_ data: Data, named name: String) throws {
        let url = try fileURL(for: name)
        let sealed = try SecretBox.seal(data, using: key())
        try sealed.write(to: url, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public func read(named name: String) throws -> Data? {
        let url = try fileURL(for: name)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let key = try key()
        return try SecretBox.open(Data(contentsOf: url), using: key)
    }

    /// Hedef ad zaten varsa hata verir; iki ad da diğer adlar gibi doğrulanır.
    public func rename(from source: String, to destination: String) throws {
        let sourceURL = try fileURL(for: source)
        let destinationURL = try fileURL(for: destination)
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
    }

    public func delete(named name: String) throws {
        let url = try fileURL(for: name)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    public func allNames() throws -> [String] {
        try fileManager.contentsOfDirectory(atPath: directory.path)
            .filter { !$0.hasPrefix(".") }
            .sorted()
    }

    private func key() throws -> SymmetricKey {
        if let cachedKey { return cachedKey }
        let key: SymmetricKey
        do {
            key = try keyProvider.symmetricKey()
        } catch {
            throw Failure.keyUnavailable(error)
        }
        cachedKey = key
        return key
    }

    private func fileURL(for name: String) throws -> URL {
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/") else {
            throw Failure.invalidName(name)
        }
        return directory.appendingPathComponent(name)
    }
}
