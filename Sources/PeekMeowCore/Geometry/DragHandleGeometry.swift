import CoreGraphics
import Foundation

public enum DragHandleGeometry: Sendable {
    /// The whole outer rail, not only the short capsule. Thickness stays the hover rail.
    /// AppKit view coordinates, origin bottom-left.
    public static func rect(
        in bounds: CGRect,
        edge: ScreenEdge,
        thickness: CGFloat = LayoutMetrics.hoverHitThickness
    ) -> CGRect {
        switch edge {
        case .right:
            return CGRect(x: bounds.width - thickness, y: bounds.minY, width: thickness, height: bounds.height)
        case .left:
            return CGRect(x: bounds.minX, y: bounds.minY, width: thickness, height: bounds.height)
        case .top:
            return CGRect(x: bounds.minX, y: bounds.height - thickness, width: bounds.width, height: thickness)
        case .bottom:
            return CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: thickness)
        }
    }
}


