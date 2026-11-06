import Testing
import AppKit
@testable import UtilCore

@Suite struct PermissionsTests {
    @Test func allGrantedNeedsEveryPermissionIncludingPasteboard() {
        #expect(PermissionStatus(accessibility: true, screenRecording: true, pasteboard: true).allGranted)
        #expect(!PermissionStatus(accessibility: true, screenRecording: true, pasteboard: false).allGranted)
        #expect(!PermissionStatus(accessibility: false, screenRecording: true, pasteboard: true).allGranted)
        #expect(!PermissionStatus(accessibility: true, screenRecording: false, pasteboard: true).allGranted)
    }

    @Test func pasteboardCountsAsGrantedOnlyWhenAlwaysAllowed() {
        guard #available(macOS 15.4, *) else { return }
        #expect(Permissions.isPasteboardGranted(.alwaysAllow))
        #expect(!Permissions.isPasteboardGranted(.default))
        #expect(!Permissions.isPasteboardGranted(.ask))
        #expect(!Permissions.isPasteboardGranted(.alwaysDeny))
    }

    @Test func settingsOpenTheMatchingPrivacyPane() {
        let base = "x-apple.systempreferences:com.apple.preference.security?"
        #expect(Permissions.settingsURL(.accessibility)?.absoluteString == base + "Privacy_Accessibility")
        #expect(Permissions.settingsURL(.screenRecording)?.absoluteString == base + "Privacy_ScreenCapture")
        #expect(Permissions.settingsURL(.pasteboard)?.absoluteString == base + "Privacy_Pasteboard")
    }
}
