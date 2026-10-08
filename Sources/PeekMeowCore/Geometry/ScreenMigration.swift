import CoreGraphics
import Foundation

public enum ScreenMigration: Sendable {
    /// Resolve a stored placement against the current display set.
    /// Missing displays fall back to the main screen, keeping edge and offset.
    public static func resolve(
        saved: DisplayPlacement,
        screens: [ScreenGeometry],
        mainScreenID: String
    ) -> (placement: DisplayPlacement, screen: ScreenGeometry?) {
        let saved = supported(saved)
        if let match = screens.first(where: { $0.identifier == saved.displayIdentifier }) {
            return (saved, match)
        }
        let fallbackID = screens.contains(where: { $0.identifier == mainScreenID })
            ? mainScreenID
            : screens.first?.identifier
        guard let fallbackID,
              let screen = screens.first(where: { $0.identifier == fallbackID })
        else {
            return (saved, nil)
        }
        let migrated = DisplayPlacement(
            displayIdentifier: fallbackID,
            edge: saved.edge,
            offset: saved.offset
        )
        return (migrated, screen)
    }

    /// Top is not a supported snap edge. A stored top placement becomes Right.
    private static func supported(_ saved: DisplayPlacement) -> DisplayPlacement {
        guard saved.edge == .top else { return saved }
        return DisplayPlacement(
            displayIdentifier: saved.displayIdentifier,
            edge: .right,
            offset: saved.offset
        )
    }

    public static func screenContaining(
        point: CGPoint,
        screens: [ScreenGeometry],
        preferring preferredID: String? = nil
    ) -> ScreenGeometry? {
        // A point on the shared pixel belongs to the next display. Keep the panel's
        // display until the pointer is clearly past the seam.
        if let preferredID,
           let preferred = screens.first(where: { $0.identifier == preferredID }) {
            let slop = LayoutMetrics.sharedEdgeClearance
            let expanded = preferred.frame.insetBy(dx: -slop, dy: -slop)
            if expanded.contains(point) {
                return preferred
            }
        }
        if let hit = screens.first(where: { $0.frame.contains(point) }) {
            return hit
        }
        return screens.min(by: { distance(point, to: $0.frame) < distance(point, to: $1.frame) })
    }

    private static func distance(_ point: CGPoint, to rect: CGRect) -> CGFloat {
        let x = min(max(point.x, rect.minX), rect.maxX)
        let y = min(max(point.y, rect.minY), rect.maxY)
        let dx = point.x - x
        let dy = point.y - y
        return (dx * dx + dy * dy).squareRoot()
    }
}
