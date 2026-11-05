import CoreGraphics

public struct AppIdentity: Equatable, Sendable {
    public let name: String
    public let bundleID: String?

    public init(name: String, bundleID: String?) {
        self.name = name
        self.bundleID = bundleID
    }
}

public struct WindowInfo: Equatable, Identifiable, Sendable {
    public let id: CGWindowID
    public let pid: pid_t
    public let appName: String
    public let bundleID: String?
    public var title: String
    public let bounds: CGRect
    public var isMinimized: Bool

    public init(id: CGWindowID, pid: pid_t, appName: String, bundleID: String?,
                title: String, bounds: CGRect, isMinimized: Bool) {
        self.id = id
        self.pid = pid
        self.appName = appName
        self.bundleID = bundleID
        self.title = title
        self.bounds = bounds
        self.isMinimized = isMinimized
    }
}
