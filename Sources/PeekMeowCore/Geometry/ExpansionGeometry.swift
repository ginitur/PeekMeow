import CoreGraphics
import Foundation

/// Expand / collapse around a fixed `EdgeAnchor`. Hover never mutates `offset`.
public enum ExpansionGeometry: Sendable {
    public static func layout(
        anchor: EdgeAnchor,
        screen: ScreenGeometry,
        panelSize: CGSize,
        stackLength: CGFloat,
        inset: CGFloat = 0
    ) -> ExpansionLayout {
        let collapsed = EdgeGeometry.collapsedPlacement(
            screen: screen,
            edge: anchor.edge,
            offset: anchor.offset,
            stackLength: stackLength,
            inset: inset
        )
        let point = anchorPoint(anchor: anchor, screen: screen, inset: inset)
        let visible = screen.visibleFrame
        let outer = EdgeGeometry.outerCoordinate(edge: anchor.edge, screen: screen, inset: inset)

        var panel: CGRect
        var attachment: CGPoint
        var handleOffset: CGFloat
        var clamped = false

        switch anchor.edge {
        case .right:
            let unclampedY = point.y - panelSize.height / 2
            let y = min(max(unclampedY, visible.minY), visible.maxY - panelSize.height)
            clamped = abs(y - unclampedY) > 0.5
            panel = CGRect(x: outer - panelSize.width, y: y, width: panelSize.width, height: panelSize.height)
            attachment = CGPoint(x: outer, y: point.y)
            handleOffset = panel.maxY - point.y
        case .left:
            let unclampedY = point.y - panelSize.height / 2
            let y = min(max(unclampedY, visible.minY), visible.maxY - panelSize.height)
            clamped = abs(y - unclampedY) > 0.5
            panel = CGRect(x: outer, y: y, width: panelSize.width, height: panelSize.height)
            attachment = CGPoint(x: outer, y: point.y)
            handleOffset = panel.maxY - point.y
        case .top:
            let unclampedX = point.x - panelSize.width / 2
            let x = min(max(unclampedX, visible.minX), visible.maxX - panelSize.width)
            clamped = abs(x - unclampedX) > 0.5
            panel = CGRect(x: x, y: outer - panelSize.height, width: panelSize.width, height: panelSize.height)
            attachment = CGPoint(x: point.x, y: outer)
            handleOffset = point.x - panel.minX
        case .bottom:
            let unclampedX = point.x - panelSize.width / 2
            let x = min(max(unclampedX, visible.minX), visible.maxX - panelSize.width)
            clamped = abs(x - unclampedX) > 0.5
            panel = CGRect(x: x, y: outer, width: panelSize.width, height: panelSize.height)
            attachment = CGPoint(x: point.x, y: outer)
            handleOffset = point.x - panel.minX
        }

        return ExpansionLayout(
            panelFrame: panel,
            collapsedFrame: collapsed.frame,
            anchorPoint: point,
            handleAttachmentPoint: attachment,
            handleOffsetInsidePanel: handleOffset,
            offset: anchor.offset,
            wasClamped: clamped
        )
    }

    public static func anchorPoint(anchor: EdgeAnchor, screen: ScreenGeometry, inset: CGFloat = 0) -> CGPoint {
        let visible = screen.visibleFrame
        let outer = EdgeGeometry.outerCoordinate(edge: anchor.edge, screen: screen, inset: inset)
        switch anchor.edge {
        case .left, .right:
            return CGPoint(x: outer, y: visible.maxY - anchor.offset)
        case .top, .bottom:
            return CGPoint(x: visible.minX + anchor.offset, y: outer)
        }
    }
}
