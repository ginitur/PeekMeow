import CoreGraphics
import Foundation

/// Edges where two displays meet. A window flush with that seam does not receive clicks.
public enum ScreenAdjacency: Sendable {
    public static func clearance(
        edge: ScreenEdge,
        screen: ScreenGeometry,
        screens: [ScreenGeometry]
    ) -> CGFloat {
        shares(edge, screen: screen, screens: screens) ? LayoutMetrics.sharedEdgeClearance : 0
    }

    public static func shares(
        _ edge: ScreenEdge,
        screen: ScreenGeometry,
        screens: [ScreenGeometry]
    ) -> Bool {
        let mine = screen.frame
        for other in screens where other.identifier != screen.identifier {
            let theirs = other.frame
            switch edge {
            case .right:
                guard abs(theirs.minX - mine.maxX) <= 1,
                      rangesOverlap(mine.minY, mine.maxY, theirs.minY, theirs.maxY) else { continue }
                return true
            case .left:
                guard abs(theirs.maxX - mine.minX) <= 1,
                      rangesOverlap(mine.minY, mine.maxY, theirs.minY, theirs.maxY) else { continue }
                return true
            case .bottom:
                guard abs(theirs.maxY - mine.minY) <= 1,
                      rangesOverlap(mine.minX, mine.maxX, theirs.minX, theirs.maxX) else { continue }
                return true
            case .top:
                guard abs(theirs.minY - mine.maxY) <= 1,
                      rangesOverlap(mine.minX, mine.maxX, theirs.minX, theirs.maxX) else { continue }
                return true
            }
        }
        return false
    }

    private static func rangesOverlap(
        _ start: CGFloat,
        _ end: CGFloat,
        _ otherStart: CGFloat,
        _ otherEnd: CGFloat
    ) -> Bool {
        min(end, otherEnd) - max(start, otherStart) > 40
    }
}
