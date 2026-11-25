import PeekMeowCore

enum HoverEngineTests {
    static func run() throws {
        try enterWaitsThenExpands()
        try leaveDuringDelayCancelsOpen()
        try leaveExpandedSchedulesClose()
        try reenteringPanelCancelsClose()
        try clickOpensWithoutPinning()
        try pinnedIgnoresPointerExit()
        try doubleClickEntersEditingAndAllowsKey()
        try delaysComeFromSettings()
        try editingIgnoresPointerExit()
        try peekDoesNotAllowKey()
    }

    static func enterWaitsThenExpands() throws {
        var engine = HoverEngine()
        let scheduled = engine.handle(.pointerEnteredRegion)
        try expectEqual(engine.phase, .hovering)
        try expectEqual(scheduled, .scheduleOpen(LayoutMetrics.defaultHoverOpenDelay))

        let opened = engine.handle(.openDelayElapsed)
        try expectEqual(engine.phase, .expanded)
        try expectEqual(opened, .expand)
        try expect(engine.isVisuallyExpanded)
        try expect(!engine.allowsKeyWindow)
    }

    static func leaveDuringDelayCancelsOpen() throws {
        var engine = HoverEngine()
        _ = engine.handle(.pointerEnteredRegion)
        let cancelled = engine.handle(.pointerExitedRegion)
        try expectEqual(engine.phase, .collapsed)
        try expectEqual(cancelled, .cancelTimers)
    }

    static func leaveExpandedSchedulesClose() throws {
        var engine = HoverEngine(phase: .expanded)
        let close = engine.handle(.pointerExitedRegion)
        try expectEqual(close, .scheduleClose(LayoutMetrics.defaultHoverCloseDelay))
        try expectEqual(engine.phase, .expanded)

        let collapsed = engine.handle(.closeDelayElapsed)
        try expectEqual(collapsed, .collapse)
        try expectEqual(engine.phase, .collapsed)
    }

    static func reenteringPanelCancelsClose() throws {
        var engine = HoverEngine(phase: .expanded)
        _ = engine.handle(.pointerExitedRegion)
        let cancel = engine.handle(.pointerEnteredRegion)
        try expectEqual(cancel, .cancelTimers)
        try expectEqual(engine.phase, .expanded)
    }

    static func clickOpensWithoutPinning() throws {
        var collapsed = HoverEngine()
        try expectEqual(collapsed.handle(.click), .expand)
        try expectEqual(collapsed.phase, .expanded)
        try expect(!collapsed.isPinned)
        let exit = collapsed.handle(.pointerExitedRegion)
        try expectEqual(exit, .scheduleClose(LayoutMetrics.defaultHoverCloseDelay))

        var expanded = HoverEngine(phase: .expanded, pointerInside: true)
        try expectEqual(expanded.handle(.click), .none)
        try expectEqual(expanded.phase, .expanded)
        try expect(!expanded.isPinned)
    }

    static func pinnedIgnoresPointerExit() throws {
        var engine = HoverEngine(phase: .pinned)
        let output = engine.handle(.pointerExitedRegion)
        try expectEqual(output, .none)
        try expectEqual(engine.phase, .pinned)
    }

    static func doubleClickEntersEditingAndAllowsKey() throws {
        var engine = HoverEngine(phase: .expanded)
        let output = engine.handle(.doubleClick)
        try expectEqual(output, .beginEditing)
        try expectEqual(engine.phase, .editing)
        try expect(engine.allowsKeyWindow)

        _ = engine.handle(.pointerExitedRegion)
        try expectEqual(engine.phase, .editing)

        let ended = engine.handle(.endEditing)
        try expectEqual(ended, .endEditing)
        try expectEqual(engine.phase, .expanded)
        try expect(!engine.isPinned)
        try expect(!engine.allowsKeyWindow)
    }

    static func editingIgnoresPointerExit() throws {
        var engine = HoverEngine(phase: .editing)
        try expect(engine.allowsKeyWindow)
        let output = engine.handle(.pointerExitedRegion)
        try expectEqual(output, .none)
        try expectEqual(engine.phase, .editing)
    }

    static func peekDoesNotAllowKey() throws {
        var engine = HoverEngine(phase: .expanded)
        try expect(!engine.allowsKeyWindow)
        _ = engine.handle(.click)
        try expect(!engine.allowsKeyWindow)
        _ = engine.handle(.doubleClick)
        try expect(engine.allowsKeyWindow)
    }

    static func delaysComeFromSettings() throws {
        var engine = HoverEngine(openDelay: 0.2, closeDelay: 0.4)
        try expectEqual(engine.handle(.pointerEnteredRegion), .scheduleOpen(0.2))

        var expanded = HoverEngine(phase: .expanded, openDelay: 0.2, closeDelay: 0.4)
        try expectEqual(expanded.handle(.pointerExitedRegion), .scheduleClose(0.4))
    }
}
