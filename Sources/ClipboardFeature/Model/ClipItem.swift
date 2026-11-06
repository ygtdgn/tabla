import Foundation
import CoreGraphics

public struct Representation: Codable, Equatable, Sendable {
    public let type: String
    public let data: Data
    public init(type: String, data: Data) { self.type = type; self.data = data }
}

public enum ClipKind: String, Codable, Sendable { case text, image }

public struct CapturedClip: Equatable, Sendable {
    public let kind: ClipKind
    public let representations: [Representation]
    public let plainText: String?
    public let dedupKey: String
    public let imagePixelSize: CGSize?
    public let sourceBundleID: String?
    public init(kind: ClipKind, representations: [Representation], plainText: String?,
                dedupKey: String, imagePixelSize: CGSize?, sourceBundleID: String?) {
        self.kind = kind; self.representations = representations; self.plainText = plainText
        self.dedupKey = dedupKey; self.imagePixelSize = imagePixelSize; self.sourceBundleID = sourceBundleID
    }
}

public struct ClipItem: Codable, Equatable, Identifiable, Sendable {
    public static let previewLimit = 200
    /// Önizleme için taranan baş kısım: büyük kopyalarda tüm metin bölünüp kırpılmaz.
    public static let previewScanLimit = 4096
    public static let searchKeyLimit = 20_000

    public let id: UUID
    public let kind: ClipKind
    public let dedupKey: String
    public var preview: String
    public var searchKey: String
    public var imagePixelSize: CGSize?
    public var sourceBundleID: String?
    public var firstCopiedAt: Date
    public var lastCopiedAt: Date
    public var pinnedAt: Date?
    public var isPinned: Bool { pinnedAt != nil }

    public init(clip: CapturedClip, id: UUID, now: Date) {
        self.id = id
        self.kind = clip.kind
        self.dedupKey = clip.dedupKey
        self.imagePixelSize = clip.imagePixelSize
        self.sourceBundleID = clip.sourceBundleID
        self.firstCopiedAt = now
        self.lastCopiedAt = now
        self.pinnedAt = nil
        if clip.kind == .text, let text = clip.plainText {
            let line = text.prefix(Self.previewScanLimit).split(whereSeparator: \.isNewline).lazy
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty } ?? ""
            self.preview = String(line.prefix(Self.previewLimit))
            self.searchKey = String(SearchNormalizer.normalize(String(text.prefix(Self.searchKeyLimit))).prefix(Self.searchKeyLimit))
        } else {
            self.preview = ""
            self.searchKey = ""
        }
    }
}
