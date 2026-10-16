import Foundation
import GRDB

public struct MemoRepository: Sendable {
    let writer: DatabaseQueue

    public init(writer: DatabaseQueue) {
        self.writer = writer
    }

    public func fetchItems(for date: Date, categoryId: UUID? = nil, calendar: Calendar = .current) throws -> [MemoItem] {
        let start = DailyView.startOfDay(date, calendar: calendar)
        let end = DailyView.nextDayStart(date, calendar: calendar)
        return try writer.read { db in
            var request = MemoItemRecord
                .filter(Column("parent_id") == nil)
                .filter(Column("is_archived") == false)
                .filter(Column("scheduled_date") >= start)
                .filter(Column("scheduled_date") < end)
            if let categoryId {
                request = request.filter(Column("category_id") == categoryId.uuidString)
            }
            return try request
                .order(Column("sort_order"))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    /// Root tasks scheduled before `day`, including completed ones. Notes and subtasks stay out.
    public func fetchHistoryRoots(before day: Date, calendar: Calendar = .current) throws -> [MemoItem] {
        let start = DailyView.startOfDay(day, calendar: calendar)
        return try writer.read { db in
            try MemoItemRecord
                .filter(Column("parent_id") == nil)
                .filter(Column("type") == ItemType.task.rawValue)
                .filter(Column("is_archived") == false)
                .filter(Column("scheduled_date") < start)
                .order(Column("scheduled_date").desc, Column("sort_order").asc)
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    /// Unfinished root tasks scheduled before `day`. Does not change `scheduledDate`.
    public func fetchPastUnfinished(before day: Date, calendar: Calendar = .current) throws -> [MemoItem] {
        let start = DailyView.startOfDay(day, calendar: calendar)
        return try writer.read { db in
            try MemoItemRecord
                .filter(Column("parent_id") == nil)
                .filter(Column("type") == ItemType.task.rawValue)
                .filter(Column("is_archived") == false)
                .filter(Column("is_completed") == false)
                .filter(Column("scheduled_date") < start)
                .order(Column("scheduled_date").desc, Column("sort_order").asc)
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    public func fetchChildren(parentId: UUID) throws -> [MemoItem] {
        try writer.read { db in
            try MemoItemRecord
                .filter(Column("parent_id") == parentId.uuidString)
                .filter(Column("is_archived") == false)
                .order(Column("sort_order"))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    @discardableResult
    public func createTask(title: String, scheduledDate: Date, categoryId: UUID?, sortOrder: Int? = nil) throws -> MemoItem {
        try writer.write { db in
            let order = try sortOrder ?? Self.nextRootOrder(on: scheduledDate, db: db)
            let now = Date()
            let item = MemoItem(
                categoryId: categoryId,
                type: .task,
                title: title,
                sortOrder: order,
                scheduledDate: DailyView.startOfDay(scheduledDate),
                createdAt: now,
                updatedAt: now
            )
            try MemoItemRecord(item).insert(db)
            return item
        }
    }

    @discardableResult
    public func createNote(title: String, scheduledDate: Date, categoryId: UUID?, body: String = "") throws -> MemoItem {
        try writer.write { db in
            let order = try Self.nextRootOrder(on: scheduledDate, db: db)
            let now = Date()
            let item = MemoItem(
                categoryId: categoryId,
                type: .note,
                title: title,
                body: body,
                sortOrder: order,
                scheduledDate: DailyView.startOfDay(scheduledDate),
                createdAt: now,
                updatedAt: now
            )
            try MemoItemRecord(item).insert(db)
            return item
        }
    }

    @discardableResult
    public func createSubtask(parentID: UUID, title: String) throws -> MemoItem {
        try writer.write { db in
            guard let parent = try MemoItemRecord.fetchOne(db, key: parentID.uuidString)?.model() else {
                throw PersistenceError.notFound(parentID)
            }
            guard parent.type == .task else {
                throw PersistenceError.noteCannotHaveSubtask
            }
            guard parent.parentId == nil else {
                throw PersistenceError.cannotNestSubtask
            }
            let order = try Self.nextChildOrder(parentID: parentID, db: db)
            let now = Date()
            let item = MemoItem(
                categoryId: parent.categoryId,
                parentId: parentID,
                type: .task,
                title: title,
                sortOrder: order,
                scheduledDate: parent.scheduledDate,
                createdAt: now,
                updatedAt: now
            )
            try MemoItemRecord(item).insert(db)
            return item
        }
    }

    public func updateItem(_ item: MemoItem) throws {
        if item.type == .note, item.parentId != nil {
            throw PersistenceError.noteCannotHaveSubtask
        }
        try writer.write { db in
            var stored = item
            stored.updatedAt = Date()
            try MemoItemRecord(stored).update(db)
        }
    }

    public func deleteItem(id: UUID) throws {
        try writer.write { db in
            try db.execute(sql: "DELETE FROM memo_items WHERE parent_id = ?", arguments: [id.uuidString])
            try db.execute(sql: "DELETE FROM memo_items WHERE id = ?", arguments: [id.uuidString])
            if db.changesCount == 0 {
                throw PersistenceError.notFound(id)
            }
        }
    }

    public func toggleCompleted(id: UUID, at date: Date = Date()) throws {
        try writer.write { db in
            guard let current = try MemoItemRecord.fetchOne(db, key: id.uuidString)?.model() else {
                throw PersistenceError.notFound(id)
            }
            guard current.type == .task else {
                throw PersistenceError.notesAreNotCompletable
            }
            let rootID = current.parentId ?? current.id
            guard let root = try MemoItemRecord.fetchOne(db, key: rootID.uuidString)?.model() else {
                throw PersistenceError.notFound(rootID)
            }
            let children = try MemoItemRecord
                .filter(Column("parent_id") == rootID.uuidString)
                .fetchAll(db)
                .map { try $0.model() }
            var family = [root] + children
            TaskHierarchy.setCompleted(id, to: !current.isCompleted, items: &family, at: date)
            for item in family {
                try MemoItemRecord(item).update(db)
            }
        }
    }

    public func reorderItems(_ ids: [UUID]) throws {
        try writer.write { db in
            let now = Date()
            for (index, id) in ids.enumerated() {
                try db.execute(
                    sql: "UPDATE memo_items SET sort_order = ?, updated_at = ? WHERE id = ?",
                    arguments: [index, now, id.uuidString]
                )
            }
        }
    }

    private static func nextRootOrder(on date: Date, db: Database) throws -> Int {
        let start = DailyView.startOfDay(date)
        let end = DailyView.nextDayStart(date)
        return try Int.fetchOne(
            db,
            sql: """
            SELECT COALESCE(MAX(sort_order), -1) + 1 FROM memo_items
            WHERE parent_id IS NULL AND scheduled_date >= ? AND scheduled_date < ?
            """,
            arguments: [start, end]
        ) ?? 0
    }

    private static func nextChildOrder(parentID: UUID, db: Database) throws -> Int {
        try Int.fetchOne(
            db,
            sql: "SELECT COALESCE(MAX(sort_order), -1) + 1 FROM memo_items WHERE parent_id = ?",
            arguments: [parentID.uuidString]
        ) ?? 0
    }
}

public struct MemoStore: Sendable {
    public let database: AppDatabase
    public let categories: CategoryRepository
    public let memos: MemoRepository

    public init(database: AppDatabase) {
        self.database = database
        categories = CategoryRepository(writer: database.writer)
        memos = MemoRepository(writer: database.writer)
    }

    public static func open(path: String) throws -> MemoStore {
        try MemoStore(database: AppDatabase(path: path))
    }

    public static func openDefault() throws -> MemoStore {
        try MemoStore(database: AppDatabase.openDefault())
    }
}
