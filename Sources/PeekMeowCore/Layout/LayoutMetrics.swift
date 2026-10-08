import CoreGraphics
import Foundation

/// Canonical layout and interaction numbers. Do not scatter these as literals.
public enum LayoutMetrics: Sendable {
    /// Distance from a screen edge at which a drag magnetically snaps.
    public static let magnetRange: CGFloat = 24

    /// Pointer movement required before a press becomes a drag.
    public static let dragThreshold: CGFloat = 6

    /// Visible thickness of the Edge Tab wedge, in points.
    public static let visibleTabThickness: CGFloat = 3

    /// Mouse-tracking thickness of the collapsed window, in points.
    public static let hoverHitThickness: CGFloat = 14

    /// Pull the window off an edge that touches another display, so the drag rail can be clicked.
    public static let sharedEdgeClearance: CGFloat = 28

    /// Extra padding around the union of tab + panel so a 1–2 px animation gap does not collapse hover.
    public static let hoverRegionPadding: CGFloat = 6

    /// Delay after mouse-exit before the engine is told the pointer left.
    public static let hoverGracePeriod: TimeInterval = 0.08

    public static let defaultHoverOpenDelay: TimeInterval = 0.16
    public static let defaultHoverCloseDelay: TimeInterval = 0.35

    /// Handle reveal. About 100 ms.
    public static let handleRevealDuration: TimeInterval = 0.10

    /// Panel expand. Ease-out frame plus a short content spring.
    public static let expandDuration: TimeInterval = 0.24

    /// Panel collapse. Slightly faster than expand.
    public static let collapseDuration: TimeInterval = 0.18

    /// Content fade starts this long after the shell begins expanding.
    public static let contentFadeDelay: TimeInterval = 0.04

    /// Brief content fade before the shell collapses.
    public static let contentFadeOutDuration: TimeInterval = 0.05

    /// Legacy alias used by a few call sites; prefer expand/collapse durations.
    public static let panelAnimationDuration: TimeInterval = expandDuration

    public static let defaultPanelWidth: CGFloat = PanelSizeMetrics.defaultWidth
    public static let defaultPanelHeight: CGFloat = PanelSizeMetrics.defaultHeight
    public static let previewPanelWidth: CGFloat = PanelSizeMetrics.defaultWidth
    public static let previewPanelHeight: CGFloat = PanelSizeMetrics.defaultHeight

    public static let defaultStackLength: CGFloat = 56
    public static let subtaskIndent: CGFloat = 18

    /// Category control hit height. Kept clear of the drag rail.
    public static let categoryHitHeight: CGFloat = 32

    /// In-panel buttons. The glyph stays small; the clickable square is larger.
    public static let controlHit: CGFloat = 32
    public static let defaultOpacity: Double = 0.92
    public static let minimumOpacity: Double = 0.5
    public static let maximumOpacity: Double = 1.0
}

/// v0.1 snaps to Left, Right, and Bottom. Top remains in `ScreenEdge` for shared geometry only.
public enum PlacementPolicy: Sendable {
    public static func isSupported(_ edge: ScreenEdge) -> Bool {
        edge != .top
    }
}
