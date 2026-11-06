import AppKit
import SwiftUI
import UtilCore

/// "Tabla Hakkında": icon, name, version (from Info.plist), credits, license and copyright.
@MainActor
final class AboutWindowController {
    /// Public source repository. Shown as a link once set (after the GitHub repo is published).
    static let repositoryURL: URL? = nil

    private lazy var window: NSWindow = {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: AboutView(repositoryURL: Self.repositoryURL))
        return window
    }()

    func show() {
        // Same placement as the permissions window: centered on the mouse's screen, in front.
        window.layoutIfNeeded()
        if let screen = PanelPlacement.screenContainingMouse() {
            window.setFrameOrigin(PanelPlacement.centered(size: window.frame.size, in: screen.visibleFrame).origin)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

private struct AboutView: View {
    let repositoryURL: URL?

    private var info: [String: Any] { Bundle.main.infoDictionary ?? [:] }
    private var name: String { info["CFBundleDisplayName"] as? String ?? "Tabla" }
    private var version: String {
        let short = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        return "Sürüm \(short) (\(build))"
    }
    private var copyright: String { info["NSHumanReadableCopyright"] as? String ?? "" }

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text(name)
                .font(.title2.bold())
            Text(version)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            VStack(spacing: 2) {
                Text("Pencere geçişi ve pano geçmişi.")
                Text("Geliştiren: Yiğit Doğan")
                Text("GPL-3.0 lisanslı açık kaynak yazılım.")
                if let repositoryURL {
                    Link(repositoryURL.absoluteString.replacingOccurrences(of: "https://", with: ""),
                         destination: repositoryURL)
                }
            }
            .font(.caption)
            .multilineTextAlignment(.center)
            .padding(.top, 14)

            Text(copyright)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(width: 300)
    }
}
