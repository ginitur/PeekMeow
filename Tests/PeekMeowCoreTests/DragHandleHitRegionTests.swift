import CoreGraphics
import PeekMeowCore

enum DragHandleHitRegionTests {
    static func run() throws {
        try rightHandleOnOuterEdge()
        try topHandleSitsAtTop()
    }

    static func rightHandleOnOuterEdge() throws {
        let bounds = CGRect(x: 0, y: 0, width: 280, height: 320)
        let rect = DragHandleGeometry.rect(in: bounds, edge: .right)
        try expectEqual(rect.maxX, bounds.maxX)
        try expectEqual(rect.minY, bounds.minY)
        try expectEqual(rect.width, LayoutMetrics.hoverHitThickness)
        try expectEqual(rect.height, bounds.height)
    }

    static func topHandleSitsAtTop() throws {
        let bounds = CGRect(x: 0, y: 0, width: 280, height: 320)
        let rect = DragHandleGeometry.rect(in: bounds, edge: .top)
        try expectEqual(rect.maxY, bounds.height)
        try expectEqual(rect.width, bounds.width)
        try expectEqual(rect.height, LayoutMetrics.hoverHitThickness)
    }
}
