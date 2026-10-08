import CoreGraphics
import Foundation

public enum EdgeGeometry: Sendable {
    public static func collapsedWindowSize(edge: ScreenEdge, stackLength: CGFloat) -> CGSize {
        switch edge {
        case .left, .right:
            CGSize(width: LayoutMetrics.hoverHitThickness, height: stackLength)
        case .top, .bottom:
            CGSize(width: stackLength, height: LayoutMetrics.hoverHitThickness)
        }
    }

    public static func usableSpan(edge: ScreenEdge, screen: ScreenGeometry) -> CGFloat {
        switch edge {
        case .left, .right:
            screen.visibleFrame.height
        case .top, .bottom:
            screen.visibleFrame.width
        }
    }

    public static func clampOffset(
        _ offset: CGFloat,
        edge: ScreenEdge,
        screen: ScreenGeometry,
        stackLength: CGFloat
    ) -> CGFloat {
        let span = usableSpan(edge: edge, screen: screen)
        let half = stackLength / 2
        let minOffset = min(half, span / 2)
        let maxOffset = max(span - half, minOffset)
        return min(max(offset, minOffset), maxOffset)
    }

    /// Outer coordinate of an edge, in screen space.
    /// Uses `visibleFrame` when the Dock insets that edge so the tab stays hittable.
    /// `inset` pulls a shared display seam inward so the drag rail stays on this screen.
    public static func outerCoordinate(
        edge: ScreenEdge,
        screen: ScreenGeometry,
        inset: CGFloat = 0
    ) -> CGFloat {
        let frame = screen.frame
        let visible = screen.visibleFrame
        let base: CGFloat
        switch edge {
        case .left:
            base = visible.minX - frame.minX > 1 ? visible.minX : frame.minX
        case .right:
            base = frame.maxX - visible.maxX > 1 ? visible.maxX : frame.maxX
        case .bottom:
            base = visible.minY - frame.minY > 1 ? visible.minY : frame.minY
        case .top:
            // Menu bar always insets the top. Normal Top mode sits under it.
            base = visible.maxY
        }
        let pull = max(inset, 0)
        switch edge {
        case .left, .bottom:
            return base + pull
        case .right, .top:
            return base - pull
        }
    }

    public static func collapsedPlacement(
        screen: ScreenGeometry,
        edge: ScreenEdge,
        offset: CGFloat,
        stackLength: CGFloat,
        inset: CGFloat = 0
    ) -> PanelPlacement {
        let clamped = clampOffset(offset, edge: edge, screen: screen, stackLength: stackLength)
        let size = collapsedWindowSize(edge: edge, stackLength: stackLength)
        let frame = collapsedFrame(
            screen: screen,
            edge: edge,
            offset: clamped,
            size: size,
            inset: inset
        )
        return PanelPlacement(
            displayIdentifier: screen.identifier,
            edge: edge,
            offset: clamped,
            frame: frame,
            isSnapped: true
        )
    }

    public static func placement(
        from stored: DisplayPlacement,
        screen: ScreenGeometry,
        stackLength: CGFloat,
        screens: [ScreenGeometry] = []
    ) -> PanelPlacement {
        let edge: ScreenEdge = PlacementPolicy.isSupported(stored.edge) ? stored.edge : .right
        return collapsedPlacement(
            screen: screen,
            edge: edge,
            offset: stored.offset,
            stackLength: stackLength,
            inset: ScreenAdjacency.clearance(edge: edge, screen: screen, screens: screens)
        )
    }

    /// Live placement while the pointer is down.
    /// Follows the cursor until within `magnetRange` of an edge, then snaps.
    public static func draggingPlacement(
        pointer: CGPoint,
        screen: ScreenGeometry,
        stackLength: CGFloat,
        grabSize: CGSize,
        magnetRange: CGFloat = LayoutMetrics.magnetRange,
        screens: [ScreenGeometry] = []
    ) -> PanelPlacement {
        let (edge, distance) = nearestSnappableEdge(to: pointer, on: screen)
        let inset = ScreenAdjacency.clearance(edge: edge, screen: screen, screens: screens)
        // Live drag is always a visible tab. Cloak only commits on mouse-up.
        if distance <= magnetRange {
            let offset = offsetAlongEdge(pointer: pointer, edge: edge, stackLength: stackLength, screen: screen)
            return collapsedPlacement(
                screen: screen,
                edge: edge,
                offset: offset,
                stackLength: stackLength,
                inset: inset
            )
        }

        let frame = CGRect(
            x: pointer.x - grabSize.width / 2,
            y: pointer.y - grabSize.height / 2,
            width: grabSize.width,
            height: grabSize.height
        )
        let offset = offsetAlongEdge(pointer: pointer, edge: edge, stackLength: stackLength, screen: screen)
        return PanelPlacement(
            displayIdentifier: screen.identifier,
            edge: edge,
            offset: offset,
            frame: frame,
            isSnapped: false
        )
    }

    /// Mouse-up always commits to the nearest legal edge.
    public static func committedPlacement(
        pointer: CGPoint,
        screen: ScreenGeometry,
        stackLength: CGFloat,
        screens: [ScreenGeometry] = []
    ) -> PanelPlacement {
        let (edge, _) = nearestSnappableEdge(to: pointer, on: screen)
        let offset = offsetAlongEdge(pointer: pointer, edge: edge, stackLength: stackLength, screen: screen)
        return collapsedPlacement(
            screen: screen,
            edge: edge,
            offset: offset,
            stackLength: stackLength,
            inset: ScreenAdjacency.clearance(edge: edge, screen: screen, screens: screens)
        )
    }

    public static func nearestEdge(to point: CGPoint, on screen: ScreenGeometry) -> (ScreenEdge, CGFloat) {
        nearestEdge(to: point, on: screen, excluding: [])
    }

    public static func nearestSnappableEdge(to point: CGPoint, on screen: ScreenGeometry) -> (ScreenEdge, CGFloat) {
        nearestEdge(to: point, on: screen, excluding: [.top])
    }

    public static func nearestEdge(
        to point: CGPoint,
        on screen: ScreenGeometry,
        excluding: Set<ScreenEdge>
    ) -> (ScreenEdge, CGFloat) {
        let frame = screen.frame
        var candidates: [(ScreenEdge, CGFloat)] = [
            (.left, abs(point.x - frame.minX)),
            (.right, abs(point.x - frame.maxX)),
            (.bottom, abs(point.y - frame.minY)),
            (.top, abs(point.y - frame.maxY)),
        ]
        candidates.removeAll { excluding.contains($0.0) }
        return candidates.min(by: { $0.1 < $1.1 }) ?? (.right, 0)
    }

    public static func offsetAlongEdge(
        pointer: CGPoint,
        edge: ScreenEdge,
        stackLength: CGFloat,
        screen: ScreenGeometry
    ) -> CGFloat {
        let visible = screen.visibleFrame
        let raw: CGFloat = switch edge {
        case .left, .right:
            visible.maxY - pointer.y
        case .top, .bottom:
            pointer.x - visible.minX
        }
        return clampOffset(raw, edge: edge, screen: screen, stackLength: stackLength)
    }

    public static func expandedFrame(
        collapsed: PanelPlacement,
        screen: ScreenGeometry,
        panelSize: CGSize
    ) -> CGRect {
        let stack = collapsed.edge.isVertical ? collapsed.frame.height : collapsed.frame.width
        let layout = ExpansionGeometry.layout(
            anchor: EdgeAnchor.from(collapsed.stored),
            screen: screen,
            panelSize: panelSize,
            stackLength: stack
        )
        return layout.panelFrame
    }

    private static func collapsedFrame(
        screen: ScreenGeometry,
        edge: ScreenEdge,
        offset: CGFloat,
        size: CGSize,
        inset: CGFloat
    ) -> CGRect {
        let visible = screen.visibleFrame
        let outer = outerCoordinate(edge: edge, screen: screen, inset: inset)
        switch edge {
        case .right:
            let anchorY = visible.maxY - offset
            let y = min(max(anchorY - size.height / 2, visible.minY), visible.maxY - size.height)
            return CGRect(x: outer - size.width, y: y, width: size.width, height: size.height)
        case .left:
            let anchorY = visible.maxY - offset
            let y = min(max(anchorY - size.height / 2, visible.minY), visible.maxY - size.height)
            return CGRect(x: outer, y: y, width: size.width, height: size.height)
        case .top:
            let anchorX = visible.minX + offset
            let x = min(max(anchorX - size.width / 2, visible.minX), visible.maxX - size.width)
            return CGRect(x: x, y: outer - size.height, width: size.width, height: size.height)
        case .bottom:
            let anchorX = visible.minX + offset
            let x = min(max(anchorX - size.width / 2, visible.minX), visible.maxX - size.width)
            return CGRect(x: x, y: outer, width: size.width, height: size.height)
        }
    }
}
