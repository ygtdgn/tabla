import AppKit
import Combine
import SwiftUI
import UtilCore

@MainActor
final class PermissionsWindowController {
    private lazy var window: NSWindow = {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Util İzinleri"
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }()

    private var closeObserver: NSObjectProtocol?

    init() {
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main
        ) { [weak self] note in
            let closing = note.object as? NSWindow
            MainActor.assumeIsolated {
                guard let self, let closing, closing === self.window else { return }
                // Görünümü söker; 1 sn'lik yenileme zamanlayıcısı pencere kapanınca durur.
                self.window.contentView = nil
            }
        }
    }

    func show() {
        if window.contentView == nil {
            window.contentView = NSHostingView(rootView: PermissionsView())
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}

private struct PermissionsView: View {
    @State private var status = Permissions.current()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            row(
                title: "Erişilebilirlik",
                detail: "Option+Tab kısayolu, pencereleri öne getirme ve seçtiğin öğeyi yapıştırma için gerekli.",
                granted: status.accessibility,
                kind: .accessibility
            )
            row(
                title: "Ekran Kaydı",
                detail: "Alt-Tab panelinde pencere önizlemelerini göstermek için gerekli. Hiçbir görüntü kaydedilmez veya bilgisayarından çıkmaz.",
                granted: status.screenRecording,
                kind: .screenRecording
            )
            Text("Ekran Kaydı iznini verdikten sonra macOS uygulamanın yeniden başlatılmasını isteyebilir.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Util'i yeniden başlat", action: relaunch)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onReceive(timer) { _ in status = Permissions.current() }
    }

    private func row(title: String, detail: String, granted: Bool, kind: PermissionKind) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if granted {
                    Text("✓ Verildi").foregroundStyle(.green)
                } else {
                    Text("Verilmedi").foregroundStyle(.orange)
                }
            }
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Sistem Ayarları'nı aç") {
                Permissions.request(kind)
                Permissions.openSettings(kind)
            }
        }
    }

    private func relaunch() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 0.5; open '\(Bundle.main.bundlePath)'"]
        try? process.run()
        NSApp.terminate(nil)
    }
}
