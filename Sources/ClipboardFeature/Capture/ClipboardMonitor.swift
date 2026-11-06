import Foundation
import os
import UtilCore

private let log = Logger(subsystem: "com.yumoteknoloji.util", category: "clipboard")

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
        let started = ContinuousClock.now
        if let clip = PasteboardSnapshot.capture(from: pasteboard, sourceBundleID: frontmostBundleID()) {
            onCapture(clip)
            // Yalnızca süre ve boyut; içerik asla günlüğe yazılmaz.
            let elapsed = (ContinuousClock.now - started).inMilliseconds
            let bytes = clip.representations.reduce(0) { $0 + $1.data.count }
            log.debug("Pano yakalama: \(elapsed, format: .fixed(precision: 1), privacy: .public) ms, \(bytes, privacy: .public) bayt")
        }
    }

    /// Marks a change count (produced by our own pasteboard write) as not to be captured.
    public func ignoreChange(count: Int) {
        ignoredCount = count
    }
}
