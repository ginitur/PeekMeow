import Foundation

public enum HoverPhase: String, Sendable, Equatable {
    case collapsed
    case hovering
    case expanded
    case pinned
    case editing

    public var isVisuallyExpanded: Bool {
        switch self {
        case .expanded, .pinned, .editing: true
        case .collapsed, .hovering: false
        }
    }
}

public enum HoverInput: Sendable, Equatable {
    case pointerEnteredRegion
    case pointerExitedRegion
    case openDelayElapsed
    case closeDelayElapsed
    case click
    case doubleClick
    case endEditing
    /// Category menu, date picker, or another transient panel interaction.
    /// Pauses auto-collapse. Never pins.
    case beginInteraction
    case endInteraction
}

public enum HoverOutput: Sendable, Equatable {
    case none
    case scheduleOpen(TimeInterval)
    case scheduleClose(TimeInterval)
    case cancelTimers
    case expand
    case collapse
    case beginEditing
    case endEditing
}

/// Pure hover state machine. AppKit supplies events; this type does not read `NSEvent`.
public struct HoverEngine: Equatable, Sendable {
    public private(set) var phase: HoverPhase
    public private(set) var pointerInside: Bool
    public private(set) var interactionHoldCount: Int
    public var openDelay: TimeInterval
    public var closeDelay: TimeInterval

    public init(
        phase: HoverPhase = .collapsed,
        openDelay: TimeInterval = LayoutMetrics.defaultHoverOpenDelay,
        closeDelay: TimeInterval = LayoutMetrics.defaultHoverCloseDelay,
        pointerInside: Bool = false,
        interactionHoldCount: Int = 0
    ) {
        self.phase = phase
        self.openDelay = openDelay
        self.closeDelay = closeDelay
        self.pointerInside = pointerInside
        self.interactionHoldCount = interactionHoldCount
    }

    public var isVisuallyExpanded: Bool {
        phase.isVisuallyExpanded
    }

    public var allowsKeyWindow: Bool {
        phase == .editing
    }

    public var isPinned: Bool {
        phase == .pinned
    }

    public mutating func resetToCollapsed() {
        phase = .collapsed
        pointerInside = false
        interactionHoldCount = 0
    }

    @discardableResult
    public mutating func handle(_ input: HoverInput) -> HoverOutput {
        switch input {
        case .pointerEnteredRegion:
            pointerInside = true
        case .pointerExitedRegion:
            pointerInside = false
        case .beginInteraction:
            interactionHoldCount += 1
            return .cancelTimers
        case .endInteraction:
            interactionHoldCount = max(0, interactionHoldCount - 1)
            if interactionHoldCount == 0, !pointerInside, phase == .expanded {
                return .scheduleClose(closeDelay)
            }
            return .none
        default:
            break
        }

        switch (phase, input) {
        case (.collapsed, .pointerEnteredRegion):
            phase = .hovering
            return .scheduleOpen(openDelay)

        case (.hovering, .pointerExitedRegion):
            phase = .collapsed
            return .cancelTimers

        case (.hovering, .openDelayElapsed):
            phase = .expanded
            return .expand

        case (.hovering, .click):
            // A click on the edge opens the panel. It must not pin, or leaving the
            // pointer there keeps the panel out until Hide.
            phase = .expanded
            return .expand

        case (.hovering, .doubleClick):
            phase = .editing
            return .beginEditing

        case (.expanded, .pointerEnteredRegion):
            return .cancelTimers

        case (.expanded, .pointerExitedRegion):
            if interactionHoldCount > 0 {
                return .none
            }
            return .scheduleClose(closeDelay)

        case (.expanded, .closeDelayElapsed):
            // A stale close timer must not win over a pointer that came back,
            // or over a menu / date picker that is still open.
            guard interactionHoldCount == 0, !pointerInside else { return .none }
            phase = .collapsed
            return .collapse

        case (.expanded, .click):
            return .none

        case (.expanded, .doubleClick):
            phase = .editing
            return .beginEditing

        case (.pinned, .click):
            phase = .collapsed
            return .collapse

        case (.pinned, .doubleClick):
            phase = .editing
            return .beginEditing

        case (.pinned, .pointerEnteredRegion), (.pinned, .pointerExitedRegion):
            return .none

        case (.editing, .endEditing):
            // Edit is temporary. Return to peek so a later mouse leave can collapse.
            phase = .expanded
            return .endEditing

        case (.editing, .pointerEnteredRegion), (.editing, .pointerExitedRegion):
            return .none

        case (.editing, _):
            return .none

        case (.collapsed, .click):
            phase = .expanded
            return .expand

        case (.collapsed, .doubleClick):
            phase = .editing
            return .beginEditing

        default:
            return .none
        }
    }
}
