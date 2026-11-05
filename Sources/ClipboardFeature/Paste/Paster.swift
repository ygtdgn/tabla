import Foundation
import UtilCore

@MainActor
public final class Paster {
    public static let pasteDelay: TimeInterval = 0.05

    private let pasteboard: PasteboardWriting
    private let monitor: ClipboardMonitor
    private let keyStroker: KeyStroking
    private let schedule: (TimeInterval, @escaping @MainActor () -> Void) -> Void

    public init(pasteboard: PasteboardWriting, monitor: ClipboardMonitor, keyStroker: KeyStroking,
                schedule: @escaping (TimeInterval, @escaping @MainActor () -> Void) -> Void) {
        self.pasteboard = pasteboard
        self.monitor = monitor
        self.keyStroker = keyStroker
        self.schedule = schedule
    }

    public func paste(_ reps: [Representation], plainTextOnly: Bool, sendCommandV: Bool) {
        let count = pasteboard.write(Self.representationsForPaste(reps, plainTextOnly: plainTextOnly))
        monitor.ignoreChange(count: count)
        if sendCommandV {
            schedule(Self.pasteDelay) { [keyStroker] in keyStroker.postCommandV() }
        }
    }

    public static func representationsForPaste(_ reps: [Representation], plainTextOnly: Bool) -> [Representation] {
        guard plainTextOnly, let plain = reps.first(where: { $0.type == "public.utf8-plain-text" }) else { return reps }
        return [plain]
    }
}
