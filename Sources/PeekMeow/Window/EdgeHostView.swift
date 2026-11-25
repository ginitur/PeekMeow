import AppKit
import PeekMeowCore

/// Transparent event view. Distinguishes click vs drag using `LayoutMetrics.dragThreshold`.
final class EdgeHostView: NSView {
    var onDragBegan: (() -> Void)?
    var onDrag: ((CGPoint) -> Void)?
    var onDragEnded: ((CGPoint) -> Void)?
    var onClick: (() -> Void)?
    var onPointerEntered: (() -> Void)?
    var onPointerExited: (() -> Void)?
    var onPointerMoved: ((CGPoint) -> Void)?

    /// When set, only this rect (view coordinates) starts a drag or an open click.
    var dragHandleRect: CGRect?

    private var isDragging = false

    override var isFlipped: Bool { false }
    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var isUpdatingTracking = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        // `point` is in the superview. Convert through the window so a flipped
        // hosting view does not mirror the drag handle into the content.
        let windowPoint = superview?.convert(point, to: nil) ?? point
        let local = convert(windowPoint, from: nil)
        guard bounds.contains(local) else { return nil }
        if let dragHandleRect {
            if dragHandleRect.contains(local) {
                return self
            }
            return super.hitTest(point)
        }
        return self
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        installTrackingArea()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        installTrackingArea()
    }

    func installTrackingArea() {
        guard !isUpdatingTracking else { return }
        isUpdatingTracking = true
        defer { isUpdatingTracking = false }
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .mouseMoved,
            .activeAlways,
            .inVisibleRect,
        ]
        addTrackingArea(NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        onPointerEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onPointerExited?()
    }

    override func mouseMoved(with event: NSEvent) {
        onPointerMoved?(NSEvent.mouseLocation)
    }

    override func mouseDown(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        if let dragHandleRect, !dragHandleRect.contains(local) {
            isDragging = false
            return
        }
        // A nonactivating panel does not deliver mouseDragged. Track inside mouseDown.
        let origin = NSEvent.mouseLocation
        isDragging = false
        let mask: NSEvent.EventTypeMask = [.leftMouseDragged, .leftMouseUp]
        while let next = window?.nextEvent(matching: mask, until: .distantFuture, inMode: .eventTracking, dequeue: true) {
            let location = NSEvent.mouseLocation
            if next.type == .leftMouseUp {
                if isDragging {
                    onDragEnded?(location)
                } else {
                    onClick?()
                }
                break
            }
            if !isDragging {
                let dx = location.x - origin.x
                let dy = location.y - origin.y
                if hypot(dx, dy) >= LayoutMetrics.dragThreshold {
                    isDragging = true
                    onDragBegan?()
                }
            }
            if isDragging {
                onDrag?(location)
            }
        }
        isDragging = false
    }
}
