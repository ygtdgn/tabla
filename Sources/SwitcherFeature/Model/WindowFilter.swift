import CoreGraphics
import Foundation

public enum WindowFilter {
    public static let minSide: CGFloat = 60

    /// Filters a `CGWindowListCopyWindowInfo`-style list (front to back) down to real app windows.
    public static func windows(from list: [[String: Any]], apps: [pid_t: AppIdentity], ownPID: pid_t) -> [WindowInfo] {
        var seen = Set<CGWindowID>()
        var result: [WindowInfo] = []
        for dict in list {
            guard let number = dict[kCGWindowNumber as String] as? NSNumber,
                  let pidNumber = dict[kCGWindowOwnerPID as String] as? NSNumber,
                  (dict[kCGWindowLayer as String] as? NSNumber)?.intValue == 0
            else { continue }
            let id = CGWindowID(truncating: number)
            let pid = pid_t(truncating: pidNumber)
            guard pid != ownPID, let app = apps[pid] else { continue }
            guard let boundsDict = dict[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.width >= minSide, bounds.height >= minSide
            else { continue }
            if let alpha = dict[kCGWindowAlpha as String] as? NSNumber, alpha.doubleValue <= 0 { continue }
            guard seen.insert(id).inserted else { continue }
            result.append(WindowInfo(id: id, pid: pid, appName: app.name, bundleID: app.bundleID,
                                     title: dict[kCGWindowName as String] as? String ?? "",
                                     bounds: bounds, isMinimized: false,
                                     isOnScreen: dict[kCGWindowIsOnscreen as String] as? Bool ?? false))
        }
        return result
    }
}
