import CoreGraphics
import UtilCore

/// Inputs to `SwitcherLayout` and the panel frame on screen (AppKit coordinates).
enum SwitcherPanelGeometry {
    /// Used when a window's bounds give no finite, positive ratio (e.g. zero height gives NaN or inf).
    static let fallbackAspectRatio: CGFloat = 1.6
    static let maxWidthFraction: CGFloat = 0.9
    static let maxHeightFraction: CGFloat = 0.8

    static func aspectRatio(of bounds: CGRect) -> CGFloat {
        let ratio = bounds.width / bounds.height
        return ratio.isFinite && ratio > 0 ? ratio : fallbackAspectRatio
    }

    static func maxPanelSize(in visibleFrame: CGRect) -> CGSize {
        CGSize(width: visibleFrame.width * maxWidthFraction, height: visibleFrame.height * maxHeightFraction)
    }

    /// Centered in `visibleFrame`. The layout's minimum-size fallback can exceed the maximum panel
    /// size with very many windows, so the frame is clamped and never leaves the screen.
    static func panelFrame(size: CGSize, in visibleFrame: CGRect) -> CGRect {
        let clamped = CGSize(width: min(size.width, visibleFrame.width), height: min(size.height, visibleFrame.height))
        return PanelPlacement.centered(size: clamped, in: visibleFrame)
    }
}
