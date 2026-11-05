import Foundation

/// Düz (alt dizinsiz) adlarla şifreli dosya deposu. Dizin 0700, dosyalar 0600.
public final class EncryptedFileStore {
    public enum Failure: Error { case invalidName(String) }

    private let directory: URL
    private let keyProvider: KeyProvider
    private let fileManager = FileManager.default

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

    public func write(_ data: Data, named name: String) throws {
        let url = try fileURL(for: name)
        let sealed = try SecretBox.seal(data, using: keyProvider.symmetricKey())
        try sealed.write(to: url, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public func read(named name: String) throws -> Data? {
        let url = try fileURL(for: name)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try SecretBox.open(Data(contentsOf: url), using: keyProvider.symmetricKey())
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

    private func fileURL(for name: String) throws -> URL {
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/") else {
            throw Failure.invalidName(name)
        }
        return directory.appendingPathComponent(name)
    }
}
