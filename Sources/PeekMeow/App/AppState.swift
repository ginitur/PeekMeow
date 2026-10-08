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
        guard isViewingToday else { return [] }
        return DailyView.pastUnfinishedRoots(in: items, before: selectedDate, categoryId: filteredCategoryID)
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
                        scheduledDate: selectedDate,
                        categoryId: targetCategoryID(for: nil)
                    )
                } else {
                    try store.memos.createTask(
                        title: text,
                        scheduledDate: selectedDate,
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
        selectedDate = DailyView.startOfDay(date)
        reloadFromStore()
    }

    func goToPreviousDay() {
        selectDate(DailyView.shiftDay(selectedDate, by: -1))
    }

    func goToNextDay() {
        selectDate(DailyView.shiftDay(selectedDate, by: 1))
    }

    func goToToday() {
        selectDate(Date())
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
    /// A failed read leaves the previous UI state in place.
    private func reloadFromStore() {
        guard let store else { return }
        do {
            let storedCategories = try store.categories.fetchCategories()
            let roots = try store.memos.fetchItems(for: selectedDate)
            var loaded = roots
            for root in roots {
                loaded.append(contentsOf: try store.memos.fetchChildren(parentId: root.id))
            }
            if DailyView.isViewingToday(selectedDate) {
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

    private static func log(_ error: Error) {
        #if DEBUG
        print("[Persistence] \(error)")
        #endif
    }
}
