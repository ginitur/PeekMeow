import CoreGraphics
import Foundation
import PeekMeowCore

enum AnchorStableDuringResizeTests {
    static func run() throws {
        try rightEdgeKeepsMaxXAndTheAnchor()
        try leftEdgeKeepsMinX()
        try bottomEdgeKeepsMinY()
        try gripStaysOffTheDragHandle()
        try resizeChangesWidthAndHeightIndependently()
    }

    static func rightEdgeKeepsMaxXAndTheAnchor() throws {
        let screen = Fixtures.external
        let anchor = EdgeAnchor(displayIdentifier: screen.identifier, edge: .right, offset: 240)
        let before = layout(anchor, screen: screen, size: CGSize(width: 354, height: 460))
        let after = layout(anchor, screen: screen, size: CGSize(width: 420, height: 600))
        try expectEqual(before.offset, after.offset)
        try expectEqual(before.anchorPoint, after.anchorPoint)
        try expectEqual(before.panelFrame.maxX, after.panelFrame.maxX)
        try expectEqual(before.handleAttachmentPoint, after.handleAttachmentPoint)
        try expect(after.panelFrame.minX < before.panelFrame.minX)
        try expect(after.panelFrame.width > before.panelFrame.width)
    }

    static func leftEdgeKeepsMinX() throws {
        let screen = Fixtures.external
        let anchor = EdgeAnchor(displayIdentifier: screen.identifier, edge: .left, offset: 180)
        let before = layout(anchor, screen: screen, size: CGSize(width: 354, height: 460))
        let after = layout(anchor, screen: screen, size: CGSize(width: 500, height: 360))
        try expectEqual(before.offset, after.offset)
        try expectEqual(before.panelFrame.minX, after.panelFrame.minX)
        try expectEqual(before.anchorPoint, after.anchorPoint)
        try expect(after.panelFrame.maxX > before.panelFrame.maxX)
    }

    static func bottomEdgeKeepsMinY() throws {
        let screen = Fixtures.external
        let anchor = EdgeAnchor(displayIdentifier: screen.identifier, edge: .bottom, offset: 400)
        let before = layout(anchor, screen: screen, size: CGSize(width: 340, height: 474))
        let after = layout(anchor, screen: screen, size: CGSize(width: 300, height: 620))
        try expectEqual(before.offset, after.offset)
        try expectEqual(before.panelFrame.minY, after.panelFrame.minY)
        try expectEqual(before.anchorPoint, after.anchorPoint)
        try expect(after.panelFrame.maxY > before.panelFrame.maxY)
    }

    static func gripStaysOffTheDragHandle() throws {
        let window = CGRect(x: 0, y: 0, width: 354, height: 460)
        for edge in [ScreenEdge.right, .left, .bottom] {
            let content = PanelResizeGeometry.contentRect(in: window, edge: edge)
            let grip = PanelResizeGeometry.gripFrame(in: content, edge: edge)
            try expect(content.contains(grip))
            let handle = DragHandleGeometry.rect(in: window, edge: edge)
            try expect(grip.intersection(handle).isNull, "\(edge) grip overlaps the drag handle")
        }
        try expectEqual(PanelResizeGeometry.corner(for: .right), .bottomLeft)
        try expectEqual(PanelResizeGeometry.corner(for: .left), .bottomRight)
        try expectEqual(PanelResizeGeometry.corner(for: .bottom), .topRight)
    }

    static func resizeChangesWidthAndHeightIndependently() throws {
        let start = PanelContentSize(width: 340, height: 460)
        let visible = CGSize(width: 1512, height: 944)
        let wider = PanelResizeGeometry.resizedContent(
            start: start,
            translation: CGSize(width: -60, height: 0),
            edge: .right,
            visible: visible
        )
        try expectEqual(wider.width, 400)
        try expectEqual(wider.height, 460)
        let taller = PanelResizeGeometry.resizedContent(
            start: start,
            translation: CGSize(width: 0, height: 80),
            edge: .right,
            visible: visible
        )
        try expectEqual(taller.width, 340)
        try expectEqual(taller.height, 540)
        let bottom = PanelResizeGeometry.resizedContent(
            start: start,
            translation: CGSize(width: 40, height: -50),
            edge: .bottom,
            visible: visible
        )
        try expectEqual(bottom.width, 380)
        try expectEqual(bottom.height, 510)
    }

    private static func layout(_ anchor: EdgeAnchor, screen: ScreenGeometry, size: CGSize) -> ExpansionLayout {
        ExpansionGeometry.layout(anchor: anchor, screen: screen, panelSize: size, stackLength: 56)
    }
}
