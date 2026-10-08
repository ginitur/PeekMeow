import CoreGraphics
import PeekMeowCore

enum ScreenAdjacencyTests {
    static func run() throws {
        try loneScreenStaysFlush()
        try sideBySideScreensShareTheInnerEdges()
        try stackedScreensShareTheInnerEdges()
        try aCornerTouchDoesNotCount()
        try sharedEdgePullsTheWindowInward()
        try aSingleScreenStaysFlush()
    }

    static func loneScreenStaysFlush() throws {
        let screen = screen("only", CGRect(x: 0, y: 0, width: 1440, height: 900))
        for edge in ScreenEdge.allCases {
            try expectEqual(
                ScreenAdjacency.clearance(edge: edge, screen: screen, screens: [screen]),
                0
            )
        }
    }

    static func sideBySideScreensShareTheInnerEdges() throws {
        let pair = sideBySide()
        try expectEqual(
            ScreenAdjacency.clearance(edge: .right, screen: pair.left, screens: [pair.left, pair.right]),
            LayoutMetrics.sharedEdgeClearance
        )
        try expectEqual(
            ScreenAdjacency.clearance(edge: .left, screen: pair.right, screens: [pair.left, pair.right]),
            LayoutMetrics.sharedEdgeClearance
        )
        try expectEqual(
            ScreenAdjacency.clearance(edge: .left, screen: pair.left, screens: [pair.left, pair.right]),
            0
        )
        try expectEqual(
            ScreenAdjacency.clearance(edge: .right, screen: pair.right, screens: [pair.left, pair.right]),
            0
        )
        try expectEqual(
            ScreenAdjacency.clearance(edge: .top, screen: pair.left, screens: [pair.left, pair.right]),
            0
        )
    }

    static func stackedScreensShareTheInnerEdges() throws {
        let lower = screen("lower", CGRect(x: 0, y: 0, width: 1200, height: 800))
        let upper = screen("upper", CGRect(x: 0, y: 800, width: 1200, height: 700))
        let screens = [lower, upper]
        try expectEqual(ScreenAdjacency.clearance(edge: .top, screen: lower, screens: screens), LayoutMetrics.sharedEdgeClearance)
        try expectEqual(ScreenAdjacency.clearance(edge: .bottom, screen: upper, screens: screens), LayoutMetrics.sharedEdgeClearance)
        try expectEqual(ScreenAdjacency.clearance(edge: .bottom, screen: lower, screens: screens), 0)
        try expectEqual(ScreenAdjacency.clearance(edge: .top, screen: upper, screens: screens), 0)
    }

    static func aCornerTouchDoesNotCount() throws {
        let left = screen("left", CGRect(x: 0, y: 0, width: 1000, height: 800))
        let corner = screen("corner", CGRect(x: 1000, y: 760, width: 400, height: 40))
        try expectEqual(
            ScreenAdjacency.clearance(edge: .right, screen: left, screens: [left, corner]),
            0
        )
        let gap = screen("gap", CGRect(x: 1002, y: 0, width: 800, height: 800))
        try expectEqual(
            ScreenAdjacency.clearance(edge: .right, screen: left, screens: [left, gap]),
            0
        )
    }

    static func sharedEdgePullsTheWindowInward() throws {
        let pair = sideBySide()
        let inset = LayoutMetrics.sharedEdgeClearance
        let pulled = EdgeGeometry.collapsedPlacement(
            screen: pair.left,
            edge: .right,
            offset: 200,
            stackLength: 56,
            inset: inset
        )
        try expectEqual(pulled.frame.maxX, pair.left.frame.maxX - inset)

        let stored = DisplayPlacement(displayIdentifier: "left", edge: .right, offset: 200)
        let placed = EdgeGeometry.placement(
            from: stored,
            screen: pair.left,
            stackLength: 56,
            screens: [pair.left, pair.right]
        )
        try expectEqual(placed.frame.maxX, pair.left.frame.maxX - inset)

        let expanded = ExpansionGeometry.layout(
            anchor: EdgeAnchor(displayIdentifier: "left", edge: .right, offset: 200),
            screen: pair.left,
            panelSize: CGSize(width: 340, height: 460),
            stackLength: 56,
            inset: inset
        )
        try expectEqual(expanded.panelFrame.maxX, pair.left.frame.maxX - inset)
        try expectEqual(expanded.collapsedFrame.maxX, pair.left.frame.maxX - inset)
    }

    static func aSingleScreenStaysFlush() throws {
        let pair = sideBySide()
        let flush = EdgeGeometry.collapsedPlacement(
            screen: pair.left,
            edge: .right,
            offset: 200,
            stackLength: 56
        )
        try expectEqual(flush.frame.maxX, pair.left.frame.maxX)

        let expanded = ExpansionGeometry.layout(
            anchor: EdgeAnchor(displayIdentifier: "left", edge: .right, offset: 200),
            screen: pair.left,
            panelSize: CGSize(width: 340, height: 460),
            stackLength: 56
        )
        try expectEqual(expanded.panelFrame.maxX, pair.left.frame.maxX)
    }

    private static func sideBySide() -> (left: ScreenGeometry, right: ScreenGeometry) {
        (
            screen("left", CGRect(x: 0, y: 0, width: 1000, height: 800)),
            screen("right", CGRect(x: 1000, y: 0, width: 1920, height: 1080))
        )
    }

    private static func screen(_ identifier: String, _ frame: CGRect) -> ScreenGeometry {
        ScreenGeometry(identifier: identifier, frame: frame, visibleFrame: frame)
    }
}
