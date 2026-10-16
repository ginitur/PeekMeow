import AppKit
import CoreGraphics
import Foundation
import Observation
import PeekMeowCore

/// UI state. SQLite is the source of truth; this object reloads after each successful write.
@Observable
@MainActor
final class AppState {
    var categories: [PeekMeowCore.Category]
    var items: [MemoItem]
    var selectedDate: Date = DailyView.startOfDay(Date())
    /// The history page lists every earlier day's tasks on one page.
    var showsHistory = false
    var categoryFilter: CategoryFilter = .all
    var showDatePicker = false
    var editingItemID: UUID?
    var composingParentID: UUID?
    var composingType: ItemType = .task
    var draftText: String = ""
    var isComposing: Bool = false
    var expandedTaskIDs: Set<UUID> = []
    /// Last measured panel content size. A zero reading is ignored so the quote and mark keep a real size.
    var panelWidth: CGFloat = PanelSizeMetrics.defaultWidth
    var panelHeight: CGFloat = PanelSizeMetrics.defaultHeight

    private let store: MemoStore?
    /// True while the panel is showing the real current day, including across midnight.
    private var followsToday = true
    private var dayObservers: [any NSObjectProtocol] = []

    var activeCategories: [PeekMeowCore.Category] {
        categories.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var dateTitle: String {
        DateHeaderText.format(selected: selectedDate, now: Date())
    }

    var dailyStats: (completed: Int, total: Int) {
        DailyView.rootTaskStats(in: visibleDayItems, on: selectedDate)
    }

    var isViewingToday: Bool {
        DailyView.isViewingToday(selectedDate)
    }

    private var filteredCategoryID: UUID? {
        if case .category(let id) = categoryFilter { return id }
        return nil
    }

    var visibleDayItems: [MemoItem] {
        DailyView.scheduledRoots(in: items, on: selectedDate, categoryId: filteredCategoryID)
    }

    var pastUnfinishedItems: [MemoItem] {
        guard isViewingToday, !showsHistory else { return [] }
        return DailyView.pastUnfinishedRoots(in: items, before: selectedDate, categoryId: filteredCategoryID)
    }

    var historyDays: [DailyView.HistoryDay] {
        DailyView.historyDays(
            in: items,
            before: DailyView.startOfDay(Date()),
            categoryId: filteredCategoryID
        )
    }

    var isEditing: Bool {
        isComposing || editingItemID != nil
    }

    var filterLabel: String {
        switch categoryFilter {
        case .all:
            CategoryFilterLabel.allTasks
        case .category(let id):
            CategoryFilterLabel.title(selectedName: categories.first(where: { $0.id == id })?.name)
        }
    }

    init(store: MemoStore? = nil) {
        if let store {
            self.store = store
        } else {
            do {
                self.store = try MemoStore.openDefault()
            } catch {
                self.store = nil
                Self.log(error)
            }
        }
        categories = []
        items = []
        selectedDate = DailyView.startOfDay(Date())
        reloadFromStore()
        observeDayChanges()
    }

    isolated deinit {
        for observer in dayObservers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    func categoryForItem(_ item: MemoItem) -> PeekMeowCore.Category? {
        guard let id = item.categoryId else { return nil }
        return categories.first(where: { $0.id == id })
    }

    func children(of item: MemoItem) -> [MemoItem] {
        TaskHierarchy.children(of: item.id, in: items)
    }

    func progress(of item: MemoItem) -> (done: Int, total: Int) {
        TaskHierarchy.progress(of: item, in: items)
    }

    func beginComposing(parent: MemoItem? = nil, type: ItemType = .task) {
        editingItemID = nil
        isComposing = true
        composingParentID = parent?.id
        composingType = parent == nil ? type : .task
        draftText = ""
        if let parent {
            expandedTaskIDs.insert(parent.id)
        }
    }

    func isTaskExpanded(_ id: UUID) -> Bool {
        expandedTaskIDs.contains(id)
    }

    func toggleTaskExpanded(_ id: UUID) {
        if expandedTaskIDs.contains(id) {
            expandedTaskIDs.remove(id)
        } else {
            expandedTaskIDs.insert(id)
        }
    }

    func beginEditing(_ item: MemoItem) {
        isComposing = false
        composingParentID = nil
        editingItemID = item.id
        draftText = item.title
    }

    @discardableResult
    func saveDraft(continueSubtask: Bool = false) -> Bool {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        let parent = composingParentID
        if text.isEmpty {
            if continueSubtask, parent != nil { return true }
            cancelEdit()
            return false
        }
        guard let store else {
            Self.log(PersistenceError.databaseUnavailable("database is not open"))
            return false
        }
        do {
            if let id = editingItemID {
                guard var item = items.first(where: { $0.id == id }) else {
                    Self.log(PersistenceError.notFound(id))
                    return false
                }
                item.title = text
                try store.memos.updateItem(item)
                reloadFromStore()
                cancelEdit()
                return false
            }
            if isComposing {
                if let parent {
                    try store.memos.createSubtask(parentID: parent, title: text)
                    expandedTaskIDs.insert(parent)
                } else if composingType == .note {
                    try store.memos.createNote(
                        title: text,
                        scheduledDate: dayForNewRootItem(),
                        categoryId: targetCategoryID(for: nil)
                    )
                } else {
                    try store.memos.createTask(
                        title: text,
                        scheduledDate: dayForNewRootItem(),
                        categoryId: targetCategoryID(for: nil)
                    )
                }
                reloadFromStore()
                if continueSubtask, parent != nil {
                    draftText = ""
                    isComposing = true
                    composingParentID = parent
                    composingType = .task
                    editingItemID = nil
                    return true
                }
            }
            cancelEdit()
            return false
        } catch {
            Self.log(error)
            return false
        }
    }

    func commitComposerIfNeeded() {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            cancelEdit()
        } else {
            saveDraft(continueSubtask: false)
        }
    }

    func cancelEdit() {
        isComposing = false
        composingParentID = nil
        composingType = .task
        editingItemID = nil
        draftText = ""
        catchUpWithToday()
    }

    private func observeDayChanges() {
        let catchUp: @Sendable (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in
                self?.catchUpWithToday()
            }
        }
        for name in [Notification.Name.NSCalendarDayChanged, .NSSystemClockDidChange, .NSSystemTimeZoneDidChange] {
            dayObservers.append(
                NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil, using: catchUp)
            )
        }
        dayObservers.append(
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: nil,
                using: catchUp
            )
        )
    }

    func toggleCompleted(_ item: MemoItem) {
        guard let store else {
            Self.log(PersistenceError.databaseUnavailable("database is not open"))
            return
        }
        do {
            try store.memos.toggleCompleted(id: item.id)
            reloadFromStore()
        } catch {
            Self.log(error)
        }
    }

    func delete(_ item: MemoItem) {
        guard let store else {
            Self.log(PersistenceError.databaseUnavailable("database is not open"))
            return
        }
        do {
            try store.memos.deleteItem(id: item.id)
            if editingItemID == item.id || composingParentID == item.id {
                cancelEdit()
            }
            expandedTaskIDs.remove(item.id)
            reloadFromStore()
        } catch {
            Self.log(error)
        }
    }

    func selectDate(_ date: Date) {
        let day = DailyView.startOfDay(date)
        followsToday = DailyView.isViewingToday(day)
        guard !DailyView.isSameDay(selectedDate, day) else { return }
        selectedDate = day
        showDatePicker = false
        reloadFromStore()
    }

    /// New tasks use the real current day when the panel is following today.
    private func dayForNewRootItem() -> Date {
        DailyView.followedDay(selected: selectedDate, followsToday: followsToday, now: Date())
    }

    /// Moves a today-panel onto the real current day. A day opened on purpose stays put.
    /// An open edit of an existing row waits until that edit ends, so the row does not vanish.
    func catchUpWithToday() {
        guard editingItemID == nil, composingParentID == nil else { return }
        selectDate(DailyView.followedDay(selected: selectedDate, followsToday: followsToday, now: Date()))
    }

    func goToPreviousDay() {
        selectDate(DailyView.shiftDay(selectedDate, by: -1))
    }

    func goToNextDay() {
        selectDate(DailyView.shiftDay(selectedDate, by: 1))
    }

    func goToToday() {
        openDay(Date())
    }

    func showTodayPage() {
        guard showsHistory || !DailyView.isViewingToday(selectedDate) else { return }
        openDay(Date())
    }

    func showHistoryPage() {
        guard !showsHistory else { return }
        if isEditing { cancelEdit() }
        showsHistory = true
        reloadFromStore()
    }

    /// Leaves the history page and shows `date`, even when that day is already selected.
    func openDay(_ date: Date) {
        if isEditing { cancelEdit() }
        showsHistory = false
        selectedDate = DailyView.startOfDay(date)
        followsToday = DailyView.isViewingToday(selectedDate)
        showDatePicker = false
        reloadFromStore()
    }

    func addCategory(name: String = "New Category") {
        guard let store else {
            Self.log(PersistenceError.databaseUnavailable("database is not open"))
            return
        }
        do {
            let category = try store.categories.createCategory(name: name)
            reloadFromStore()
            categoryFilter = .category(category.id)
        } catch {
            Self.log(error)
        }
    }

    @discardableResult
    func renameCategory(id: UUID, name: String) -> Bool {
        guard let store else {
            Self.log(PersistenceError.databaseUnavailable("database is not open"))
            return false
        }
        do {
            try store.categories.renameCategory(id: id, name: name)
            reloadFromStore()
            return true
        } catch {
            Self.log(error)
            return false
        }
    }

    @discardableResult
    func recolorCategory(id: UUID, color: RGBAColor) -> Bool {
        guard let store else {
            Self.log(PersistenceError.databaseUnavailable("database is not open"))
            return false
        }
        do {
            try store.categories.updateColor(id: id, color: color)
            reloadFromStore()
            return true
        } catch {
            Self.log(error)
            return false
        }
    }

    @discardableResult
    func archiveCategory(id: UUID) -> Bool {
        guard let store else {
            Self.log(PersistenceError.databaseUnavailable("database is not open"))
            return false
        }
        do {
            try store.categories.archiveCategory(id: id)
            if case .category(let selected) = categoryFilter, selected == id {
                categoryFilter = .all
            }
            reloadFromStore()
            return true
        } catch {
            Self.log(error)
            return false
        }
    }

    @discardableResult
    func moveCategory(_ id: UUID, by delta: Int) -> Bool {
        guard let store else {
            Self.log(PersistenceError.databaseUnavailable("database is not open"))
            return false
        }
        var ids = activeCategories.map(\.id)
        guard let index = ids.firstIndex(of: id) else { return false }
        let target = index + delta
        guard ids.indices.contains(target) else { return false }
        ids.swapAt(index, target)
        do {
            try store.categories.reorderCategories(ids)
            reloadFromStore()
            return true
        } catch {
            Self.log(error)
            return false
        }
    }

    private func targetCategoryID(for parent: UUID?) -> UUID? {
        if let parent, let item = items.first(where: { $0.id == parent }) {
            return item.categoryId
        }
        if case .category(let id) = categoryFilter {
            return id
        }
        return nil
    }

    /// Loads the selected day, and — on Today only — unfinished root tasks from earlier days.
    /// The history page loads every earlier root task instead.
    /// A failed read leaves the previous UI state in place.
    private func reloadFromStore() {
        guard let store else { return }
        do {
            let storedCategories = try store.categories.fetchCategories()
            let roots = try showsHistory
                ? historyRoots(in: store)
                : store.memos.fetchItems(for: selectedDate)
            var loaded = roots
            for root in roots {
                loaded.append(contentsOf: try store.memos.fetchChildren(parentId: root.id))
            }
            if !showsHistory, DailyView.isViewingToday(selectedDate) {
                let past = try store.memos.fetchPastUnfinished(before: selectedDate)
                for root in past where !loaded.contains(where: { $0.id == root.id }) {
                    loaded.append(root)
                    loaded.append(contentsOf: try store.memos.fetchChildren(parentId: root.id))
                }
            }
            categories = storedCategories
            items = loaded
        } catch {
            Self.log(error)
        }
    }

    private func historyRoots(in store: MemoStore) throws -> [MemoItem] {
        try store.memos.fetchHistoryRoots(before: DailyView.startOfDay(Date()))
    }

    private static func log(_ error: Error) {
        #if DEBUG
        print("[Persistence] \(error)")
        #endif
    }
}
