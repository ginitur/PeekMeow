import AppKit

/// Borderless floating panel. Peeking stays non-key; editing may become key.
final class PeekPanel: NSPanel {
    var allowsKey: Bool = false {
        didSet {
            if !allowsKey, isKeyWindow {
                resignKey()
            }
        }
    }

    override var canBecomeKey: Bool { allowsKey }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
        ]
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isFloatingPanel = true
        worksWhenModal = true
        acceptsMouseMovedEvents = true
        // Read-only so screenshots and screen recordings can include the panel.
        sharingType = .readOnly
        title = "PeekMeow"
        identifier = NSUserInterfaceItemIdentifier("PeekMeow.PeekPanel")
    }
}
