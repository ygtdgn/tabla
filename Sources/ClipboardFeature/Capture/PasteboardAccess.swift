import AppKit

public protocol PasteboardReading: AnyObject {
    var changeCount: Int { get }
    var types: [String] { get }
    func data(forType: String) -> Data?
}

public protocol PasteboardWriting: AnyObject {
    /// Writes the representations and returns the new `changeCount`.
    @discardableResult func write(_ reps: [Representation]) -> Int
}

public final class SystemPasteboard: PasteboardReading, PasteboardWriting {
    public init() {}

    public var changeCount: Int { NSPasteboard.general.changeCount }
    public var types: [String] { (NSPasteboard.general.types ?? []).map(\.rawValue) }
    public func data(forType type: String) -> Data? {
        NSPasteboard.general.data(forType: NSPasteboard.PasteboardType(type))
    }

    @discardableResult
    public func write(_ reps: [Representation]) -> Int {
        let pb = NSPasteboard.general
        pb.clearContents()
        for rep in reps {
            pb.setData(rep.data, forType: NSPasteboard.PasteboardType(rep.type))
        }
        return pb.changeCount
    }
}
