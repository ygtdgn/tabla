import Foundation

@MainActor
public final class ClipboardMonitor {
    public static let pollInterval: TimeInterval = 0.5

    private let pasteboard: PasteboardReading
    private let frontmostBundleID: () -> String?
    private let onCapture: (CapturedClip) -> Void
    private var lastChangeCount: Int?
    private var ignoredCount: Int?
    private var timer: Timer?

    public init(pasteboard: PasteboardReading,
                frontmostBundleID: @escaping () -> String?,
                onCapture: @escaping (CapturedClip) -> Void) {
        self.pasteboard = pasteboard
        self.frontmostBundleID = frontmostBundleID
        self.onCapture = onCapture
    }

    public func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func poll() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        guard count != ignoredCount else { return }
        if let clip = PasteboardSnapshot.capture(from: pasteboard, sourceBundleID: frontmostBundleID()) {
            onCapture(clip)
        }
    }

    /// Marks a change count (produced by our own pasteboard write) as not to be captured.
    public func ignoreChange(count: Int) {
        ignoredCount = count
    }
}
