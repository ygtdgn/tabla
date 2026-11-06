import Testing
import ApplicationServices
import CoreGraphics
@testable import SwitcherFeature

private func window(_ id: CGWindowID, title: String, pid: pid_t = 100, onScreen: Bool = false) -> WindowInfo {
    WindowInfo(id: id, pid: pid, appName: "Finder", bundleID: "com.apple.finder",
               title: title, bounds: CGRect(x: 0, y: 0, width: 800, height: 600), isMinimized: false,
               isOnScreen: onScreen)
}

@Suite struct WindowMergeTests {
    @Test func keepsStandardAndDialogWindowsAndDropsOtherSubroles() {
        let ax: [CGWindowID: AXWindowAttributes] = [
            1: .init(subrole: "AXStandardWindow", title: "Belgeler", isMinimized: true),
            2: .init(subrole: "AXDialog", title: "Kaydet", isMinimized: false),
            3: .init(subrole: "AXFloatingWindow", title: "Palet", isMinimized: false),
            4: .init(subrole: nil, title: "Bilinmeyen", isMinimized: false),
        ]
        let merged = WindowEnumerator.merge([window(1, title: "cg"), window(2, title: ""), window(3, title: "cg"),
                                             window(4, title: "cg")], ax: ax, windowSpaces: [:], currentSpaces: [1])
        #expect(merged.map(\.id) == [1, 2])
        #expect(merged[0].title == "Belgeler"); #expect(merged[0].isMinimized)
        #expect(merged[1].title == "Kaydet"); #expect(!merged[1].isMinimized)
    }

    @Test func withoutSpaceDataKeepsWindowsWithoutAXOnlyWhenCGTitleIsPresent() {
        let merged = WindowEnumerator.merge([window(5, title: ""), window(6, title: "Masaüstü 2"), window(7, title: "")],
                                            ax: [:], windowSpaces: [:], currentSpaces: nil)
        #expect(merged.map(\.id) == [6])
        #expect(merged[0].title == "Masaüstü 2"); #expect(!merged[0].isMinimized)
    }

    @Test func withSpaceDataKeepsOnlyWindowsWithoutAXOnOtherSpaces() {
        let spaces: [CGWindowID: [UInt64]] = [5: [], 6: [1], 7: [2], 8: [3]]
        let merged = WindowEnumerator.merge([window(5, title: "Tercihler"), window(6, title: "İndirilenler"),
                                             window(7, title: "Masaüstü 2"), window(8, title: ""), window(9, title: "")],
                                            ax: [:], windowSpaces: spaces, currentSpaces: [1])
        #expect(merged.map(\.id) == [7, 8])
        #expect(merged.map(\.title) == ["Masaüstü 2", "Finder"])
    }

    @Test func titleFallsBackFromAXToCGToAppName() {
        let ax: [CGWindowID: AXWindowAttributes] = [
            1: .init(subrole: "AXStandardWindow", title: "", isMinimized: false),
            2: .init(subrole: "AXStandardWindow", title: nil, isMinimized: false),
        ]
        let merged = WindowEnumerator.merge([window(1, title: "CG başlığı"), window(2, title: "")], ax: ax,
                                            windowSpaces: [:], currentSpaces: [1])
        #expect(merged.map(\.title) == ["CG başlığı", "Finder"])
    }

    @Test func axFailedAppKeepsWindowsOnCurrentAndOtherSpaces() {
        // pid 200: kAXWindows çağrısı hata verdi; pid 100: AX çalışıyor ama bu pencereleri raporlamadı.
        let spaces: [CGWindowID: [UInt64]] = [1: [1], 2: [2], 3: [], 4: [1], 5: [1]]
        let merged = WindowEnumerator.merge([window(1, title: "Oyun", pid: 200), window(2, title: "", pid: 200),
                                             window(3, title: "Gizli", pid: 200), window(4, title: "", pid: 200),
                                             window(5, title: "Yardımcı", pid: 100)],
                                            ax: [:], axFailedPIDs: [200], windowSpaces: spaces, currentSpaces: [1])
        #expect(merged.map(\.id) == [1, 2, 4])
        #expect(merged.map(\.title) == ["Oyun", "Finder", "Finder"])
        #expect(merged.allSatisfy { !$0.isMinimized })
    }

    @Test func axFailedAppWithoutSpaceDataKeepsOnScreenWindows() {
        let merged = WindowEnumerator.merge([window(1, title: "", pid: 200, onScreen: true),
                                             window(2, title: "", pid: 200, onScreen: false),
                                             window(3, title: "Başlıklı", pid: 200, onScreen: false),
                                             window(4, title: "", pid: 100, onScreen: true)],
                                            ax: [:], axFailedPIDs: [200], windowSpaces: [:], currentSpaces: nil)
        #expect(merged.map(\.id) == [1, 3])
        #expect(merged.map(\.title) == ["Finder", "Başlıklı"])
    }

    @Test func preservesFrontToBackOrder() {
        let ax: [CGWindowID: AXWindowAttributes] = [9: .init(subrole: "AXStandardWindow", title: "a", isMinimized: false),
                                                    3: .init(subrole: "AXStandardWindow", title: "b", isMinimized: false)]
        let merged = WindowEnumerator.merge([window(9, title: ""), window(8, title: "c"), window(3, title: "")], ax: ax,
                                            windowSpaces: [8: [2]], currentSpaces: [1])
        #expect(merged.map(\.id) == [9, 8, 3])
    }
}

@Suite struct SpaceKeepRuleTests {
    @Test func emptySpaceListIsDropped() {
        #expect(!WindowEnumerator.keepsWindowWithoutAX(cgTitle: "Tercihler", spaces: [], currentSpaces: [1]))
    }

    @Test func windowOnlyOnCurrentSpacesIsDropped() {
        #expect(!WindowEnumerator.keepsWindowWithoutAX(cgTitle: "İndirilenler", spaces: [1], currentSpaces: [1, 4]))
        #expect(!WindowEnumerator.keepsWindowWithoutAX(cgTitle: "İndirilenler", spaces: [4, 1], currentSpaces: [1, 4]))
        #expect(!WindowEnumerator.keepsWindowWithoutAX(cgTitle: "Karışık", spaces: [1, 2], currentSpaces: [1]))
    }

    @Test func windowOnAnotherSpaceIsKept() {
        #expect(WindowEnumerator.keepsWindowWithoutAX(cgTitle: "Masaüstü 2", spaces: [2], currentSpaces: [1]))
        #expect(WindowEnumerator.keepsWindowWithoutAX(cgTitle: "", spaces: [2, 3], currentSpaces: [1, 4]))
    }

    @Test func unavailableSpaceDataFallsBackToCGTitle() {
        #expect(WindowEnumerator.keepsWindowWithoutAX(cgTitle: "Masaüstü 2", spaces: nil, currentSpaces: [1]))
        #expect(!WindowEnumerator.keepsWindowWithoutAX(cgTitle: "", spaces: nil, currentSpaces: [1]))
        #expect(WindowEnumerator.keepsWindowWithoutAX(cgTitle: "Masaüstü 2", spaces: [1], currentSpaces: nil))
        #expect(!WindowEnumerator.keepsWindowWithoutAX(cgTitle: "", spaces: [2], currentSpaces: nil))
    }

    @Test func axFailedAppKeepsCurrentSpaceWindows() {
        #expect(WindowEnumerator.keepsWindowWithoutAX(cgTitle: "", spaces: [1], currentSpaces: [1], axFailed: true))
        #expect(WindowEnumerator.keepsWindowWithoutAX(cgTitle: "", spaces: [2], currentSpaces: [1], axFailed: true))
        #expect(!WindowEnumerator.keepsWindowWithoutAX(cgTitle: "Gizli", spaces: [], currentSpaces: [1], axFailed: true))
    }

    @Test func axFailedAppWithoutSpaceDataUsesOnScreenFlag() {
        #expect(WindowEnumerator.keepsWindowWithoutAX(cgTitle: "", spaces: nil, currentSpaces: [1],
                                                      axFailed: true, isOnScreen: true))
        #expect(!WindowEnumerator.keepsWindowWithoutAX(cgTitle: "", spaces: [1], currentSpaces: nil,
                                                       axFailed: true, isOnScreen: false))
        #expect(WindowEnumerator.keepsWindowWithoutAX(cgTitle: "Başlık", spaces: nil, currentSpaces: [1],
                                                      axFailed: true, isOnScreen: false))
        // AX'i çalışan uygulamada ekranda olmak tek başına yetmez.
        #expect(!WindowEnumerator.keepsWindowWithoutAX(cgTitle: "", spaces: nil, currentSpaces: [1],
                                                       axFailed: false, isOnScreen: true))
    }

    @Test func onlyRealErrorsCountAsAXWindowsFailures() {
        #expect(!WindowEnumerator.isAXWindowsFailure(.success))
        #expect(!WindowEnumerator.isAXWindowsFailure(.noValue))
        for error: AXError in [.failure, .cannotComplete, .apiDisabled, .notImplemented, .attributeUnsupported,
                               .invalidUIElement, .illegalArgument] {
            #expect(WindowEnumerator.isAXWindowsFailure(error))
        }
    }

    @Test func currentSpacesAreReadFromManagedDisplaySpaces() {
        let displays: [[String: Any]] = [
            ["Display Identifier": "Main", "Current Space": ["ManagedSpaceID": 3, "id64": 3],
             "Spaces": [["ManagedSpaceID": 3, "id64": 3], ["ManagedSpaceID": 5, "id64": 5]]],
            ["Display Identifier": "B2C1", "Current Space": ["ManagedSpaceID": 9]],
            ["Display Identifier": "C3D4"],
        ]
        #expect(PrivateAPIs.currentSpaceIDs(fromManagedDisplaySpaces: displays) == [3, 9])
        #expect(PrivateAPIs.currentSpaceIDs(fromManagedDisplaySpaces: [["Display Identifier": "Main"]]) == nil)
        #expect(PrivateAPIs.currentSpaceIDs(fromManagedDisplaySpaces: []) == nil)
    }
}
