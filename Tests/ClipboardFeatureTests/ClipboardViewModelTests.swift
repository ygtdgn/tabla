import Testing
import AppKit
import Foundation
@testable import ClipboardFeature

@MainActor @Suite struct ClipboardViewModelTests {
    func history() -> (ClipboardHistory, UUID) {
        var h = ClipboardHistory()
        let p = h.add(textClip("iban"), now: date(0)).itemID; _ = h.setPinned(p, true, now: date(1))
        for i in 1...10 { _ = h.add(textClip("öğe \(i)"), now: date(1 + i)) }
        return (h, p)
    }
    @Test func numbersFirstNineVisibleRowsIncludingPinned() {
        let (h, p) = history(); let vm = ClipboardViewModel(history: h)
        #expect(vm.rows[0].item.id == p); #expect(vm.rows[0].shortcutNumber == 1)
        #expect(vm.rows[8].shortcutNumber == 9); #expect(vm.rows[9].shortcutNumber == nil)
        #expect(vm.item(forShortcut: 2)?.preview == "öğe 10")
    }
    @Test func searchRenumbersAndResetsSelection() {
        let vm = ClipboardViewModel(history: history().0)
        vm.moveSelection(by: 3); vm.query = "öğe 1"
        #expect(vm.rows.map(\.item.preview) == ["öğe 10", "öğe 1"])
        #expect(vm.rows.map(\.shortcutNumber) == [1, 2]); #expect(vm.selectedIndex == 0)
    }
    @Test func selectionClamps() {
        let vm = ClipboardViewModel(history: history().0)
        vm.moveSelection(by: -1); #expect(vm.selectedIndex == 0)
        vm.moveSelection(by: 100); #expect(vm.selectedIndex == 10)
    }
    @Test func updateKeepsSelectionInRange() {
        let vm = ClipboardViewModel(history: history().0)
        vm.moveSelection(by: 100)
        vm.update(history: ClipboardHistory())
        #expect(vm.rows.isEmpty); #expect(vm.selectedIndex == 0); #expect(vm.selectedItem == nil)
    }
    @Test func keyMapping() {
        #expect(clipboardKeyAction(keyCode: 125, modifiers: [], characters: nil) == .moveDown)
        #expect(clipboardKeyAction(keyCode: 126, modifiers: [], characters: nil) == .moveUp)
        #expect(clipboardKeyAction(keyCode: 36, modifiers: [], characters: "\r") == .paste(plainText: false))
        #expect(clipboardKeyAction(keyCode: 76, modifiers: [], characters: "\r") == .paste(plainText: false))
        #expect(clipboardKeyAction(keyCode: 36, modifiers: [.shift], characters: "\r") == .paste(plainText: true))
        #expect(clipboardKeyAction(keyCode: 53, modifiers: [], characters: nil) == .close)
        #expect(clipboardKeyAction(keyCode: 18, modifiers: [.command], characters: "1") == .pasteShortcut(1))
        #expect(clipboardKeyAction(keyCode: 25, modifiers: [.command], characters: "9") == .pasteShortcut(9))
        #expect(clipboardKeyAction(keyCode: 29, modifiers: [.command], characters: "0") == nil)
        #expect(clipboardKeyAction(keyCode: 0, modifiers: [], characters: "a") == nil)
    }
    @Test func editShortcutsMapToStandardActions() {
        #expect(clipboardEditCommand(modifiers: [.command], characters: "a") == .selectAll)
        #expect(clipboardEditCommand(modifiers: [.command], characters: "c") == .copy)
        #expect(clipboardEditCommand(modifiers: [.command], characters: "v") == .paste)
        #expect(clipboardEditCommand(modifiers: [.command], characters: "x") == .cut)
        #expect(clipboardEditCommand(modifiers: [.command], characters: "z") == .undo)
        #expect(clipboardEditCommand(modifiers: [.command, .shift], characters: "Z") == .redo)
        #expect(clipboardEditCommand(modifiers: [.command, .capsLock], characters: "A") == .selectAll)
    }
    @Test func otherKeysAreNotEditShortcuts() {
        #expect(clipboardEditCommand(modifiers: [], characters: "a") == nil)
        #expect(clipboardEditCommand(modifiers: [.command, .option], characters: "c") == nil)
        #expect(clipboardEditCommand(modifiers: [.command, .control], characters: "v") == nil)
        #expect(clipboardEditCommand(modifiers: [.command, .shift], characters: "A") == nil)
        #expect(clipboardEditCommand(modifiers: [.command], characters: "1") == nil)
        #expect(clipboardEditCommand(modifiers: [.command], characters: nil) == nil)
        // ⌘1–9 hâlâ numaralı öğeyi yapıştırır.
        #expect(clipboardKeyAction(keyCode: 18, modifiers: [.command], characters: "1") == .pasteShortcut(1))
    }
    @Test func editCommandsUseResponderChainSelectors() {
        #expect(ClipboardEditCommand.selectAll.selector == #selector(NSText.selectAll(_:)))
        #expect(ClipboardEditCommand.copy.selector == #selector(NSText.copy(_:)))
        #expect(ClipboardEditCommand.paste.selector == #selector(NSText.paste(_:)))
        #expect(ClipboardEditCommand.cut.selector == #selector(NSText.cut(_:)))
        #expect(ClipboardEditCommand.undo.selector == Selector(("undo:")))
        #expect(ClipboardEditCommand.redo.selector == Selector(("redo:")))
    }
}
