import CoreGraphics
import PeekMeowCore

enum DragHandleIsolationTests {
    static func run() throws {
        try handleIsOnlyTheOuterRail()
        try headerDateAndTitlesAreNotDraggable()
        try categorySideIsOutsideTheHandle()
        try topEdgeHandleDoesNotCoverTheContentColumn()
    }

    static func handleIsOnlyTheOuterRail() throws {
        let bounds = CGRect(x: 0, y: 0, width: 280, height: 320)
        let handle = rightHandle(in: bounds)
        try expectEqual(handle.maxX, bounds.maxX)
        try expectEqual(handle.width, LayoutMetrics.hoverHitThickness)
        try expectEqual(handle.height, bounds.height)
        try expect(handle.minX > 0)
        try expect(handle.contains(CGPoint(x: handle.midX, y: bounds.height - 4)))
        try expect(handle.contains(CGPoint(x: handle.midX, y: 4)))
    }

    static func headerDateAndTitlesAreNotDraggable() throws {
        let bounds = CGRect(x: 0, y: 0, width: 280, height: 320)
        let handle = rightHandle(in: bounds)
        let header = CGRect(
            x: 0,
            y: bounds.height - 44,
            width: bounds.width - LayoutMetrics.hoverHitThickness,
            height: 44
        )
        try expect(!handle.intersects(header))
        let date = CGPoint(x: 120, y: bounds.height - 20)
        let title = CGPoint(x: 80, y: bounds.height - 90)
        let addTask = CGPoint(x: 70, y: 40)
        try expect(!handle.contains(date))
        try expect(!handle.contains(title))
        try expect(!handle.contains(addTask))
        try expect(handle.contains(CGPoint(x: handle.midX, y: handle.midY)))
    }

    static func categorySideIsOutsideTheHandle() throws {
        let bounds = CGRect(x: 0, y: 0, width: 280, height: 320)
        let handle = rightHandle(in: bounds)
        let category = CGPoint(x: bounds.width - LayoutMetrics.hoverHitThickness - 24, y: bounds.height - 20)
        try expect(!handle.contains(category))
    }

    static func topEdgeHandleDoesNotCoverTheContentColumn() throws {
        let bounds = CGRect(x: 0, y: 0, width: 280, height: 320)
        let handle = DragHandleGeometry.rect(in: bounds, edge: .top)
        let content = CGPoint(x: 140, y: bounds.height - LayoutMetrics.hoverHitThickness - 30)
        try expect(!handle.contains(content))
        try expect(handle.contains(CGPoint(x: handle.midX, y: handle.midY)))
    }

    private static func rightHandle(in bounds: CGRect) -> CGRect {
        DragHandleGeometry.rect(in: bounds, edge: .right)
    }
}
