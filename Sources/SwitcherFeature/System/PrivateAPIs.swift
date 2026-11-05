import ApplicationServices
import CoreGraphics
import Darwin
import Foundation

/// Private macOS symbols, resolved lazily with `dlsym`. Every pointer is Optional: a missing
/// symbol means the caller falls back to public API, never a crash. SkyLight is `dlopen`ed,
/// not linked.
enum PrivateAPIs {
    typealias AXUIElementGetWindowFunction =
        @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    /// Returns a +1 retained element (Create rule).
    typealias AXUIElementCreateWithRemoteTokenFunction =
        @convention(c) (CFData) -> Unmanaged<AXUIElement>?
    typealias GetProcessForPIDFunction =
        @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus
    typealias SLPSSetFrontProcessWithOptionsFunction =
        @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32) -> CGError
    typealias SLPSPostEventRecordToFunction =
        @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> CGError
    typealias SLSMainConnectionIDFunction = @convention(c) () -> Int32
    /// (connection, space mask, window ids) -> +1 array of space ids.
    typealias SLSCopySpacesForWindowsFunction = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    /// (connection) -> +1 array of per-display dictionaries.
    typealias SLSCopyManagedDisplaySpacesFunction = @convention(c) (Int32) -> Unmanaged<CFArray>?

    /// `RTLD_DEFAULT` (`(void *)-2`); the C macro is not importable into Swift.
    private static var defaultHandle: UnsafeMutableRawPointer? { UnsafeMutableRawPointer(bitPattern: -2) }
    private static let skyLightPath = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"

    static let axUIElementGetWindow: AXUIElementGetWindowFunction? =
        symbol("_AXUIElementGetWindow", in: defaultHandle)
    static let axUIElementCreateWithRemoteToken: AXUIElementCreateWithRemoteTokenFunction? =
        symbol("_AXUIElementCreateWithRemoteToken", in: defaultHandle)
    static let getProcessForPID: GetProcessForPIDFunction? =
        symbol("GetProcessForPID", in: defaultHandle)
    static let slpsSetFrontProcessWithOptions: SLPSSetFrontProcessWithOptionsFunction? =
        symbol("_SLPSSetFrontProcessWithOptions", in: dlopen(skyLightPath, RTLD_LAZY))
    static let slpsPostEventRecordTo: SLPSPostEventRecordToFunction? =
        symbol("SLPSPostEventRecordTo", in: dlopen(skyLightPath, RTLD_LAZY))
    static let slsMainConnectionID: SLSMainConnectionIDFunction? =
        symbol("SLSMainConnectionID", in: dlopen(skyLightPath, RTLD_LAZY))
    static let slsCopySpacesForWindows: SLSCopySpacesForWindowsFunction? =
        symbol("SLSCopySpacesForWindows", in: dlopen(skyLightPath, RTLD_LAZY))
    static let slsCopyManagedDisplaySpaces: SLSCopyManagedDisplaySpacesFunction? =
        symbol("SLSCopyManagedDisplaySpaces", in: dlopen(skyLightPath, RTLD_LAZY))

    /// `kCPSUserGenerated` mode for `_SLPSSetFrontProcessWithOptions`.
    static let userGeneratedFrontMode: UInt32 = 0x200
    /// Space mask for `SLSCopySpacesForWindows`: all spaces (current, other, fullscreen).
    static let allSpacesMask: Int32 = 0x7

    private static func symbol<T>(_ name: String, in handle: UnsafeMutableRawPointer?) -> T? {
        guard let handle, let address = dlsym(handle, name) else { return nil }
        return unsafeBitCast(address, to: T.self)
    }

    /// The CG window id behind an AX window element, or nil if unavailable.
    static func windowID(of element: AXUIElement) -> CGWindowID? {
        guard let getWindow = axUIElementGetWindow else { return nil }
        var id: CGWindowID = 0
        guard getWindow(element, &id) == .success, id != 0 else { return nil }
        return id
    }

    /// Creates an AX element from a remote token, taking ownership of the +1 result.
    static func element(remoteToken: Data) -> AXUIElement? {
        guard let create = axUIElementCreateWithRemoteToken else { return nil }
        return create(remoteToken as CFData)?.takeRetainedValue()
    }

    /// Space ids the window is on, or nil if SkyLight is unavailable. Ordered-out windows have none.
    static func spaceIDs(ofWindow windowID: CGWindowID, connection: Int32) -> [UInt64]? {
        guard let copy = slsCopySpacesForWindows,
              let spaces = copy(connection, allSpacesMask, [windowID] as CFArray)?.takeRetainedValue() as? [NSNumber]
        else { return nil }
        return spaces.map(\.uint64Value)
    }

    /// Ids of the spaces currently shown on any display, or nil if SkyLight cannot tell.
    static func currentSpaceIDs(connection: Int32) -> Set<UInt64>? {
        guard let copy = slsCopyManagedDisplaySpaces,
              let displays = copy(connection)?.takeRetainedValue() as? [[String: Any]]
        else { return nil }
        return currentSpaceIDs(fromManagedDisplaySpaces: displays)
    }

    /// Reads each display's "Current Space" id (`id64`, else `ManagedSpaceID`); nil if none found.
    static func currentSpaceIDs(fromManagedDisplaySpaces displays: [[String: Any]]) -> Set<UInt64>? {
        var ids = Set<UInt64>()
        for display in displays {
            guard let current = display["Current Space"] as? [String: Any],
                  let id = (current["id64"] ?? current["ManagedSpaceID"]) as? NSNumber
            else { continue }
            ids.insert(id.uint64Value)
        }
        return ids.isEmpty ? nil : ids
    }

    /// 20 bytes: pid (Int32 LE), 0 (4 bytes), `0x636f636f` (LE), element id (UInt64 LE).
    static func remoteToken(pid: pid_t, elementID: UInt64) -> Data {
        var token = Data(capacity: 20)
        withUnsafeBytes(of: pid.littleEndian) { token.append(contentsOf: $0) }
        withUnsafeBytes(of: Int32(0)) { token.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(0x636f636f).littleEndian) { token.append(contentsOf: $0) }
        withUnsafeBytes(of: elementID.littleEndian) { token.append(contentsOf: $0) }
        return token
    }

    /// 0xf8-byte event record for `SLPSPostEventRecordTo` that makes `windowID` the key window.
    static func makeKeyWindowEventBytes(windowID: CGWindowID, eventType: UInt8) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 0xf8)
        bytes[0x04] = 0xf8
        bytes[0x08] = eventType
        bytes.replaceSubrange(0x20..<0x30, with: repeatElement(0xff, count: 0x10))
        bytes[0x3a] = 0x10
        withUnsafeBytes(of: windowID.littleEndian) { bytes.replaceSubrange(0x3c..<0x40, with: $0) }
        return bytes
    }
}
