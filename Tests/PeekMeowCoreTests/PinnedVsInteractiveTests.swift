import Foundation
import PeekMeowCore

enum PinnedVsInteractiveTests {
    static func run() throws {
        try explicitClickDoesNotPin()
        try pinnedIgnoresPointerExit()
        try categoryInteractionDoesNotPin()
        try endingCategoryInteractionIsNotPinned()
        try editAndMenuDoNotPin()
    }

    static func explicitClickDoesNotPin() throws {
        var engine = HoverEngine(phase: .expanded, pointerInside: true)
        _ = engine.handle(.click)
        try expect(!engine.isPinned)
        try expectEqual(engine.phase, .expanded)
        let exit = engine.handle(.pointerExitedRegion)
        try expectEqual(exit, .scheduleClose(engine.closeDelay))
        try expectEqual(engine.phase, .expanded)
    }

    static func pinnedIgnoresPointerExit() throws {
        var engine = HoverEngine(phase: .pinned, pointerInside: true)
        _ = engine.handle(.pointerExitedRegion)
        try expectEqual(engine.phase, .pinned)
        try expect(!engine.pointerInside)
    }

    static func categoryInteractionDoesNotPin() throws {
        var engine = HoverEngine(phase: .expanded, pointerInside: true)
        var selection = CategorySelectionState()
        _ = engine.handle(.beginInteraction)
        let work = UUID()
        selection.applyMenuChoice(work)
        try expectEqual(selection.selectedCategoryID, work)
        try expect(!selection.pinned)
        try expect(!engine.isPinned)
        try expectEqual(engine.phase, .expanded)
        selection.applyMenuChoice(nil)
        try expect(selection.showsAll)
        try expect(selection.selectedCategoryID == nil)
        try expect(!engine.isPinned)
    }

    static func endingCategoryInteractionIsNotPinned() throws {
        var engine = HoverEngine(phase: .expanded, pointerInside: true)
        _ = engine.handle(.beginInteraction)
        _ = engine.handle(.pointerExitedRegion)
        _ = engine.handle(.endInteraction)
        try expect(!engine.isPinned)
        try expectEqual(engine.phase, .expanded)
    }

    static func editAndMenuDoNotPin() throws {
        var engine = HoverEngine(phase: .expanded, pointerInside: true)
        _ = engine.handle(.doubleClick)
        _ = engine.handle(.beginInteraction)
        try expectEqual(engine.phase, .editing)
        try expect(!engine.isPinned)
        _ = engine.handle(.endInteraction)
        _ = engine.handle(.endEditing)
        try expectEqual(engine.phase, .expanded)
        try expect(!engine.isPinned)
    }
}
