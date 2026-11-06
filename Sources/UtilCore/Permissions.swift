import AppKit
import ApplicationServices
import CoreGraphics

public enum PermissionKind: Sendable {
    case accessibility
    case screenRecording
    /// macOS 15.4+ pano gizliliği: programla pano okumak varsayılan olarak kullanıcıya sorulur.
    case pasteboard
}

public struct PermissionStatus: Equatable, Sendable {
    public var accessibility: Bool
    public var screenRecording: Bool
    /// macOS 15.4 öncesinde her zaman true.
    public var pasteboard: Bool

    public init(accessibility: Bool, screenRecording: Bool, pasteboard: Bool) {
        self.accessibility = accessibility
        self.screenRecording = screenRecording
        self.pasteboard = pasteboard
    }

    public var allGranted: Bool { accessibility && screenRecording && pasteboard }
}

@MainActor
public enum Permissions {
    public static func current() -> PermissionStatus {
        PermissionStatus(
            accessibility: AXIsProcessTrusted(),
            screenRecording: CGPreflightScreenCaptureAccess(),
            pasteboard: pasteboardGranted()
        )
    }

    /// Pano erişimi sorulabilen sistem mi (macOS 15.4+)? Değilse izin satırı gösterilmez.
    public static var asksForPasteboardAccess: Bool {
        if #available(macOS 15.4, *) { true } else { false }
    }

    /// Pano yoklaması uyarısız yalnızca "Her Zaman İzin Ver" ile çalışır; "sor" ve henüz sorulmamış
    /// (`default`) durumlar izin verilmemiş sayılır.
    @available(macOS 15.4, *)
    nonisolated static func isPasteboardGranted(_ behavior: NSPasteboard.AccessBehavior) -> Bool {
        behavior == .alwaysAllow
    }

    private static func pasteboardGranted() -> Bool {
        guard #available(macOS 15.4, *) else { return true }
        return isPasteboardGranted(NSPasteboard.general.accessBehavior)
    }

    public static func request(_ kind: PermissionKind) {
        switch kind {
        case .accessibility:
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        case .screenRecording:
            _ = CGRequestScreenCaptureAccess()
        case .pasteboard:
            // İstek API'si yok: macOS ilk pano okumasında kendisi sorar (yoklama bunu zaten tetikler).
            break
        }
    }

    /// Gizlilik ve Güvenlik'in ilgili bölmesi. `Privacy_Pasteboard` sistem ayarlarının gizlilik
    /// uzantısındaki (SecurityPrivacyExtension) bölme adıdır.
    nonisolated static func settingsURL(_ kind: PermissionKind) -> URL? {
        let pane = switch kind {
        case .accessibility: "Privacy_Accessibility"
        case .screenRecording: "Privacy_ScreenCapture"
        case .pasteboard: "Privacy_Pasteboard"
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")
    }

    public static func openSettings(_ kind: PermissionKind) {
        if let url = settingsURL(kind) {
            NSWorkspace.shared.open(url)
        }
    }
}
