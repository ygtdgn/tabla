import CoreGraphics

/// A state machine effect bound to the window list it was produced with. Effects are applied
/// asynchronously, after the event tap callback has returned, so a commit carries its target window
/// instead of an index into a list that a later session may already have replaced.
enum SwitcherAction: Equatable, Sendable {
    case select(Int)
    case schedulePanel
    case showPanel
    /// Cancels the show timer and any thumbnail refresh, then hides the panel.
    case hidePanel
    case focus(WindowInfo)

    /// The state machine does not bounds-check commit indices; an index outside `windows` only hides.
    static func plan(_ effects: [SwitcherEffect], windows: [WindowInfo]) -> [SwitcherAction] {
        effects.flatMap { effect -> [SwitcherAction] in
            switch effect {
            case .select(let index): [.select(index)]
            case .schedulePanel: [.schedulePanel]
            case .showPanel: [.showPanel]
            case .cancel: [.hidePanel]
            case .commit(let index):
                windows.indices.contains(index) ? [.hidePanel, .focus(windows[index])] : [.hidePanel]
            }
        }
    }
}
