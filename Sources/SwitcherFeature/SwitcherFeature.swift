import AppKit
import ApplicationServices
import os
import UniformTypeIdentifiers
import UtilCore

private let log = Logger(subsystem: "com.yumoteknoloji.util", category: "switcher")

/// Option+Tab window switcher: event tap, MRU ordered per-window list, preview panel.
/// Fully off without Accessibility; Screen Recording only turns preview capture on.
@MainActor
public final class SwitcherFeature: Feature {
    private var machine = SwitcherStateMachine()
    private let enumerator = WindowEnumerator()
    private var mru = MRUTracker()
    private var isMRUSeeded = false
    /// The current session's windows in MRU order; fixed for the whole session.
    private var windows: [WindowInfo] = []
    private var axElements: [CGWindowID: AXUIElement] = [:]
    /// Bumped at every session start, so a late show timer or schedule of an older session is ignored.
    private var session = 0
    private var showTimer: Timer?
    private var capturesThumbnails = false

    private let cache: ThumbnailCache
    private let thumbnails: ThumbnailProvider
    private let viewModel = SwitcherViewModel()
    private var panel: SwitcherPanel?

    private lazy var tap = KeyboardTap { [weak self] event in self?.handleKey(event) ?? false }
    private lazy var focusObserver = FocusObserver { [weak self] id in self?.mru.touch(id) }

    public init() {
        let cache = ThumbnailCache()
        self.cache = cache
        thumbnails = ThumbnailProvider(cache: cache)
    }

    // MARK: Feature

    public func menuItems() -> [NSMenuItem] { [] }

    public func apply(permissions: PermissionStatus) {
        capturesThumbnails = permissions.screenRecording
        if !capturesThumbnails { thumbnails.cancel() }
        guard permissions.accessibility else {
            stopSwitching()
            return
        }
        focusObserver.start()
        if !isMRUSeeded { takeSnapshot() }
        if !tap.start() { log.error("Option+Tab event tap'i oluşturulamadı") }
    }

    public func shutdown() {
        stopSwitching()
    }

    // MARK: Event tap

    /// Runs inside the event tap callback: decides swallow/pass synchronously and defers every effect.
    /// The only synchronous work is the snapshot on the Tab that starts a session.
    private func handleKey(_ event: SwitcherKeyEvent) -> Bool {
        guard let input = switcherInput(for: event, isActive: machine.isActive) else { return false }
        if case .tab = input, !machine.isActive {
            session += 1
            takeSnapshot()
        }
        let output = machine.handle(input, windowCount: windows.count)
        let actions = SwitcherAction.plan(output.effects, windows: windows)
        if !actions.isEmpty {
            let session = self.session
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated { self?.perform(actions, session: session) }
            }
        }
        return output.consume
    }

    private func showDelayElapsed(session: Int) {
        guard session == self.session else { return }
        showTimer = nil
        let output = machine.handle(.showDelayElapsed, windowCount: windows.count)
        perform(SwitcherAction.plan(output.effects, windows: windows), session: session)
    }

    private func click(_ index: Int) {
        let output = machine.handle(.click(index), windowCount: windows.count)
        perform(SwitcherAction.plan(output.effects, windows: windows), session: session)
    }

    // MARK: Actions

    private func perform(_ actions: [SwitcherAction], session: Int) {
        for action in actions {
            switch action {
            case .select(let index):
                viewModel.selectedIndex = index
            case .schedulePanel:
                schedulePanel(session: session)
            case .showPanel:
                showPanel()
            case .hidePanel:
                hidePanel()
            case .focus(let window):
                WindowFocuser.focus(window, axElement: axElements[window.id])
                mru.touch(window.id)
            }
        }
    }

    private func schedulePanel(session: Int) {
        // The session may already be over (quick Option+Tab) or replaced by a newer one.
        guard session == self.session, machine.isActive else { return }
        showTimer?.invalidate()
        let timer = Timer(timeInterval: Shortcuts.switcherShowDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.showDelayElapsed(session: session) }
        }
        RunLoop.main.add(timer, forMode: .common)
        showTimer = timer
    }

    /// Centered on the screen with the mouse. Cached previews first, then fresh ones if allowed.
    private func showPanel() {
        guard !windows.isEmpty, let screen = PanelPlacement.screenContainingMouse() else { return }
        let visibleFrame = screen.visibleFrame
        let layout = SwitcherLayout.compute(
            aspectRatios: windows.map { SwitcherPanelGeometry.aspectRatio(of: $0.bounds) },
            maxPanelSize: SwitcherPanelGeometry.maxPanelSize(in: visibleFrame)
        )
        var icons: [pid_t: NSImage] = [:]
        viewModel.present(windows.indices.map { i in
            let window = windows[i]
            let icon = icons[window.pid] ?? Self.appIcon(pid: window.pid)
            icons[window.pid] = icon
            return SwitcherCard(id: window.id, title: window.title, icon: icon, frame: layout.cardFrames[i],
                                thumbSize: layout.thumbFrames[i].size, image: thumbnails.cached(for: window.id))
        })

        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.present(frame: SwitcherPanelGeometry.panelFrame(size: layout.panelSize, in: visibleFrame))

        if capturesThumbnails {
            thumbnails.refresh(windows.map(\.id)) { [weak self] id, image in
                self?.viewModel.setImage(image, for: id)
            }
        }
    }

    /// Commit and cancel both end here: no timer, no capture and no panel left behind.
    private func hidePanel() {
        showTimer?.invalidate()
        showTimer = nil
        thumbnails.cancel()
        panel?.dismiss()
        viewModel.clear()
    }

    private func makePanel() -> SwitcherPanel {
        SwitcherPanel(rootView: SwitcherView(model: viewModel) { [weak self] index in self?.click(index) })
    }

    // MARK: Windows

    /// Refreshes the window list; closed windows drop out of the MRU and the preview cache.
    /// The first snapshot seeds the MRU in CG front-to-back order.
    private func takeSnapshot() {
        let snapshot = enumerator.snapshot()
        if !isMRUSeeded {
            for window in snapshot.windows.reversed() { mru.touch(window.id) }
            isMRUSeeded = true
        }
        let ids = Set(snapshot.windows.map(\.id))
        mru.prune(keeping: ids)
        cache.prune(keeping: ids)
        windows = mru.ordered(snapshot.windows)
        axElements = snapshot.axElements
    }

    /// Without Accessibility nothing runs: no tap, no focus observer, no open session.
    private func stopSwitching() {
        tap.stop()
        focusObserver.stop()
        machine = SwitcherStateMachine()
        hidePanel()
    }

    private static func appIcon(pid: pid_t) -> NSImage {
        NSRunningApplication(processIdentifier: pid)?.icon ?? NSWorkspace.shared.icon(for: .application)
    }
}
