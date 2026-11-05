import Testing
import CoreGraphics
@testable import SwitcherFeature

private func window(_ id: CGWindowID, title: String) -> WindowInfo {
    WindowInfo(id: id, pid: 100, appName: "Finder", bundleID: "com.apple.finder",
               title: title, bounds: CGRect(x: 0, y: 0, width: 800, height: 600), isMinimized: false)
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
                                             window(4, title: "cg")], ax: ax)
        #expect(merged.map(\.id) == [1, 2])
        #expect(merged[0].title == "Belgeler"); #expect(merged[0].isMinimized)
        #expect(merged[1].title == "Kaydet"); #expect(!merged[1].isMinimized)
    }

    @Test func keepsWindowsWithoutAXOnlyWhenCGTitleIsPresent() {
        let merged = WindowEnumerator.merge([window(5, title: ""), window(6, title: "Masaüstü 2"), window(7, title: "")], ax: [:])
        #expect(merged.map(\.id) == [6])
        #expect(merged[0].title == "Masaüstü 2"); #expect(!merged[0].isMinimized)
    }

    @Test func titleFallsBackFromAXToCGToAppName() {
        let ax: [CGWindowID: AXWindowAttributes] = [
            1: .init(subrole: "AXStandardWindow", title: "", isMinimized: false),
            2: .init(subrole: "AXStandardWindow", title: nil, isMinimized: false),
        ]
        let merged = WindowEnumerator.merge([window(1, title: "CG başlığı"), window(2, title: "")], ax: ax)
        #expect(merged.map(\.title) == ["CG başlığı", "Finder"])
    }

    @Test func preservesFrontToBackOrder() {
        let ax: [CGWindowID: AXWindowAttributes] = [9: .init(subrole: "AXStandardWindow", title: "a", isMinimized: false),
                                                    3: .init(subrole: "AXStandardWindow", title: "b", isMinimized: false)]
        let merged = WindowEnumerator.merge([window(9, title: ""), window(8, title: "c"), window(3, title: "")], ax: ax)
        #expect(merged.map(\.id) == [9, 8, 3])
    }
}
