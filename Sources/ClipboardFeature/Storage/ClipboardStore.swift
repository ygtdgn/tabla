import Foundation
import UtilCore

public enum ClipboardStoreError: Error, Equatable {
    case unsupportedVersion(Int)
}

public final class ClipboardStore {
    private struct Index: Codable {
        var version: Int
        var items: [ClipItem]
    }

    private static let indexName = "index"
    private static let blobPrefix = "blob-"
    private static let thumbPrefix = "thumb-"
    private static let currentVersion = 1

    private let files: EncryptedFileStore

    public init(files: EncryptedFileStore) { self.files = files }

    public func loadHistory() throws -> ClipboardHistory {
        guard let data = try files.read(named: Self.indexName) else { return ClipboardHistory() }
        let index = try JSONDecoder().decode(Index.self, from: data)
        guard index.version <= Self.currentVersion else {
            throw ClipboardStoreError.unsupportedVersion(index.version)
        }
        return ClipboardHistory(items: index.items)
    }

    /// Anahtarı şimdi okur; anahtar yoksa `EncryptedFileStore.Failure.keyUnavailable` fırlatır.
    public func prepareKey() throws { try files.prepareKey() }

    /// Okunamayan index'i silmeden kenara alır (`index.unreadable-<unix zamanı>`) ve yeni adını döndürür.
    public func quarantineIndex(now: Date) throws -> String {
        let name = "\(Self.indexName).unreadable-\(Int(now.timeIntervalSince1970))"
        try files.rename(from: Self.indexName, to: name)
        return name
    }

    public func saveHistory(_ history: ClipboardHistory) throws {
        let data = try JSONEncoder().encode(Index(version: Self.currentVersion, items: history.items))
        try files.write(data, named: Self.indexName)
    }

    public func saveRepresentations(_ reps: [Representation], for id: UUID) throws {
        try files.write(try JSONEncoder().encode(reps), named: Self.blobName(id))
    }

    public func loadRepresentations(for id: UUID) throws -> [Representation] {
        guard let data = try files.read(named: Self.blobName(id)) else { return [] }
        return try JSONDecoder().decode([Representation].self, from: data)
    }

    public func saveThumbnail(_ data: Data, for id: UUID) throws {
        try files.write(data, named: Self.thumbName(id))
    }

    public func loadThumbnail(for id: UUID) throws -> Data? {
        try files.read(named: Self.thumbName(id))
    }

    public func removeData(for ids: [UUID]) throws {
        for id in ids {
            try files.delete(named: Self.blobName(id))
            try files.delete(named: Self.thumbName(id))
        }
    }

    public func removeOrphans(keeping: Set<UUID>) throws {
        for name in try files.allNames() where name != Self.indexName {
            for prefix in [Self.blobPrefix, Self.thumbPrefix] where name.hasPrefix(prefix) {
                if let id = UUID(uuidString: String(name.dropFirst(prefix.count))), keeping.contains(id) { break }
                try files.delete(named: name)
            }
        }
    }

    private static func blobName(_ id: UUID) -> String { blobPrefix + id.uuidString }
    private static func thumbName(_ id: UUID) -> String { thumbPrefix + id.uuidString }
}
