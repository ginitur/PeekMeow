import Foundation

public enum DailyView: Sendable {
    public static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    public static func endOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        let start = startOfDay(date, calendar: calendar)
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? start
    }

    public static func nextDayStart(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: startOfDay(date, calendar: calendar)) ?? date
    }

    public static func isViewingToday(_ selected: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        isSameDay(selected, now, calendar: calendar)
    }

    /// While the panel is on today, the selected day becomes the real current day.
    /// A day opened on purpose stays selected across midnight.
    public static func followedDay(
        selected: Date,
        followsToday: Bool,
        now: Date,
        calendar: Calendar = .current
    ) -> Date {
        guard followsToday else { return startOfDay(selected, calendar: calendar) }
        return startOfDay(now, calendar: calendar)
    }

    public static func isSameDay(_ a: Date, _ b: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    /// Planned for a given day. `forToday` is a legacy fallback only when `scheduledDate` is nil
    /// and `day` is the current calendar day.
    public static func isScheduled(_ item: MemoItem, on day: Date, calendar: Calendar = .current, now: Date = Date()) -> Bool {
        if let scheduled = item.scheduledDate {
            return isSameDay(scheduled, day, calendar: calendar)
        }
        if item.forToday, isSameDay(day, now, calendar: calendar) {
            return true
        }
        return false
    }

    public static func scheduledRoots(
        in items: [MemoItem],
        on day: Date,
        categoryId: UUID? = nil,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [MemoItem] {
        items.filter { item in
            item.parentId == nil
                && !item.isArchived
                && isScheduled(item, on: day, calendar: calendar, now: now)
                && matches(item, filter: categoryId)
        }
        .sorted { $0.sortOrder < $1.sortOrder }
    }

    public static func matches(_ item: MemoItem, filter categoryId: UUID?) -> Bool {
        guard let categoryId else { return true }
        return item.categoryId == categoryId
    }

    /// One earlier day on the history page. Newest day first; tasks keep their sort order.
    public struct HistoryDay: Equatable, Sendable, Identifiable {
        public var day: Date
        public var items: [MemoItem]

        public var id: Date { day }

        public init(day: Date, items: [MemoItem]) {
            self.day = day
            self.items = items
        }
    }

    /// Root tasks scheduled before `day`, completed and unfinished, grouped by day.
    /// Notes, subtasks, and the current day stay off this page.
    public static func historyDays(
        in items: [MemoItem],
        before day: Date,
        categoryId: UUID? = nil,
        calendar: Calendar = .current
    ) -> [HistoryDay] {
        let dayStart = startOfDay(day, calendar: calendar)
        let roots = items.filter { item in
            item.parentId == nil
                && item.type == .task
                && !item.isArchived
                && matches(item, filter: categoryId)
                && (item.scheduledDate.map { $0 < dayStart } ?? false)
        }
        let grouped = Dictionary(grouping: roots) { item in
            startOfDay(item.scheduledDate ?? .distantPast, calendar: calendar)
        }
        return grouped.keys.sorted(by: >).map { key in
            HistoryDay(
                day: key,
                items: (grouped[key] ?? []).sorted { $0.sortOrder < $1.sortOrder }
            )
        }
    }

    /// Unfinished root tasks from earlier days. Does not rewrite `scheduledDate`.
    /// Shown only on Today. Subtasks follow their parent in the UI.
    public static func pastUnfinishedRoots(
        in items: [MemoItem],
        before day: Date,
        categoryId: UUID? = nil,
        calendar: Calendar = .current
    ) -> [MemoItem] {
        let dayStart = startOfDay(day, calendar: calendar)
        return items.filter { item in
            item.parentId == nil
                && item.type == .task
                && !item.isArchived
                && !item.isCompleted
                && matches(item, filter: categoryId)
                && (item.scheduledDate.map { $0 < dayStart } ?? false)
        }
        .sorted { lhs, rhs in
            let a = lhs.scheduledDate ?? .distantPast
            let b = rhs.scheduledDate ?? .distantPast
            if a != b { return a > b }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    /// Category chip on a row. Nil category has no badge — never "Uncategorized".
    public static func categoryBadgeName(for item: MemoItem, in categories: [Category]) -> String? {
        guard let id = item.categoryId else { return nil }
        return categories.first(where: { $0.id == id && !$0.isArchived })?.name
    }

    public static func dueRoots(
        in items: [MemoItem],
        on day: Date,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [MemoItem] {
        items.filter { item in
            item.parentId == nil
                && !item.isArchived
                && item.dueDate.map { isSameDay($0, day, calendar: calendar) } == true
                && !isScheduled(item, on: day, calendar: calendar, now: now)
        }
        .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Whether the item counts as completed at the end of `day`.
    /// Later completion does not rewrite a past day's rate.
    public static func isCompleted(_ item: MemoItem, asOf day: Date, calendar: Calendar = .current) -> Bool {
        guard item.type == .task, let completedAt = item.completedAt else { return false }
        return completedAt <= endOfDay(day, calendar: calendar)
    }

    public static func completedRoots(
        in items: [MemoItem],
        on day: Date,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [MemoItem] {
        scheduledRoots(in: items, on: day, calendar: calendar, now: now)
            .filter { isCompleted($0, asOf: day, calendar: calendar) }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    public static func openScheduledRoots(
        in items: [MemoItem],
        on day: Date,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [MemoItem] {
        scheduledRoots(in: items, on: day, calendar: calendar, now: now)
            .filter { !isCompleted($0, asOf: day, calendar: calendar) }
    }

    /// Root **tasks** only. Notes never enter the percentage.
    public static func rootTaskStats(
        in items: [MemoItem],
        on day: Date,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> (completed: Int, total: Int) {
        let roots = scheduledRoots(in: items, on: day, calendar: calendar, now: now)
            .filter { $0.type == .task }
        let done = roots.filter { isCompleted($0, asOf: day, calendar: calendar) }.count
        return (done, roots.count)
    }

    public static func shiftDay(_ date: Date, by days: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: startOfDay(date, calendar: calendar)) ?? date
    }
}
