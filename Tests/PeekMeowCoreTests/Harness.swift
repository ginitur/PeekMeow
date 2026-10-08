import Foundation

struct CheckError: Error, CustomStringConvertible {
    var message: String
    var description: String { message }
}

func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String = "expectation failed",
    file: String = #fileID,
    line: Int = #line
) throws {
    if !condition() {
        throw CheckError(message: "\(file):\(line) \(message)")
    }
}

func expectEqual<T: Equatable>(
    _ actual: T,
    _ expected: T,
    file: String = #fileID,
    line: Int = #line
) throws {
    try expect(actual == expected, "\(actual) != \(expected)", file: file, line: line)
}

@main
enum PeekMeowCoreTestsMain {
    static func main() {
        let suites: [(String, () throws -> Void)] = [
            ("EdgeGeometry", EdgeGeometryTests.run),
            ("ScreenMigration", ScreenMigrationTests.run),
            ("ScreenAdjacency", ScreenAdjacencyTests.run),
            ("HoverEngine", HoverEngineTests.run),
            ("HoverRegion", HoverRegionTests.run),
            ("PanelAnimator", PanelAnimatorTests.run),
            ("AnchorPersistence", AnchorPersistenceTests.run),
            ("CornerClampAnchor", CornerClampAnchorTests.run),
            ("TaskHierarchy", TaskHierarchyTests.run),
            ("TaskCompletion", TaskCompletionTests.run),
            ("ColorSerialization", ColorSerializationTests.run),
            ("DailyViewQuery", DailyViewQueryTests.run),
            ("DailyCompletionAsOf", DailyCompletionAsOfTests.run),
            ("SelectedDateNavigation", SelectedDateNavigationTests.run),
            ("ScheduledDate", ScheduledDateTests.run),
            ("DragHandleHitRegion", DragHandleHitRegionTests.run),
            ("CategoryFilter", CategoryFilterTests.run),
            ("DailyCategoryQuery", DailyCategoryQueryTests.run),
            ("CompletedStayVisible", CompletedStayVisibleTests.run),
            ("SubtaskIndent", SubtaskIndentModelTests.run),
            ("AddTaskDefaultDate", AddTaskDefaultDateTests.run),
            ("PastUnfinished", PastUnfinishedTests.run),
            ("UncategorizedDisplay", UncategorizedDisplayTests.run),
            ("NoteDailyQuery", NoteDailyQueryTests.run),
            ("ProgressExcludesNotes", ProgressExcludesNotesTests.run),
            ("DatabaseMigration", DatabaseMigrationTests.run),
            ("CategoryRepository", CategoryRepositoryTests.run),
            ("MemoRepository", MemoRepositoryTests.run),
            ("DailyQuery", DailyQueryTests.run),
            ("PastUnfinishedPersistence", PastUnfinishedPersistenceTests.run),
            ("TaskHierarchyPersistence", TaskHierarchyPersistenceTests.run),
            ("CompletionTransaction", CompletionTransactionTests.run),
            ("NotePersistence", NotePersistenceTests.run),
            ("CategoryFilterPersistence", CategoryFilterPersistenceTests.run),
            ("RestartPersistence", RestartPersistenceTests.run),
            ("HoverExitCollapse", HoverExitCollapseTests.run),
            ("TemporaryInteractionHold", TemporaryInteractionHoldTests.run),
            ("EditModeTransition", EditModeTransitionTests.run),
            ("PinnedVsInteractive", PinnedVsInteractiveTests.run),
            ("CategorySelectionState", CategorySelectionStateTests.run),
            ("DragHandleIsolation", DragHandleIsolationTests.run),
            ("PreferencesDefaults", PreferencesDefaultsTests.run),
            ("PreferencesPersistence", PreferencesPersistenceTests.run),
            ("PreferencesReset", PreferencesResetTests.run),
            ("ColorPreference", ColorPreferenceTests.run),
            ("PanelSizingPreference", PanelSizingPreferenceTests.run),
            ("PanelSizeMigration", PanelSizeMigrationTests.run),
            ("CustomPanelSizePersistence", CustomPanelSizePersistenceTests.run),
            ("PanelResizeClamp", PanelResizeClampTests.run),
            ("AnchorStableDuringResize", AnchorStableDuringResizeTests.run),
            ("ResizeHandleRect", ResizeHandleRectTests.run),
            ("ResizeHandleDoesNotCoverContent", ResizeHandleDoesNotCoverContentTests.run),
            ("ResizeHitTesting", ResizeHitTestingTests.run),
            ("BackgroundPreference", BackgroundPreferenceTests.run),
            ("BackgroundImageCopy", BackgroundImageCopyTests.run),
            ("BackgroundFallback", BackgroundFallbackTests.run),
            ("BackgroundDoesNotTouchSQLite", BackgroundDoesNotTouchSQLiteTests.run),
            ("HoverDelayPreference", HoverDelayPreferenceTests.run),
            ("ReduceMotionPreference", ReduceMotionPreferenceTests.run),
            ("DateHeaderText", DateHeaderTextTests.run),
            ("BrandQuote", BrandQuoteTests.run),
            ("CategoryFilterLabel", CategoryFilterLabelTests.run),
            ("EdgeRevealMotion", EdgeRevealMotionTests.run),
            ("AtmosphereMark", AtmosphereMarkTests.run),
        ]

        var failed = 0
        for (name, body) in suites {
            do {
                try body()
                print("ok   \(name)")
            } catch {
                failed += 1
                print("FAIL \(name): \(error)")
            }
        }

        if failed > 0 {
            print("\(failed) suite(s) failed")
            Foundation.exit(1)
        }
        print("all suites passed")
    }
}
