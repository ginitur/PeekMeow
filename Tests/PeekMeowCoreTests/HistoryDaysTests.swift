import Foundation
import PeekMeowCore

enum HistoryDaysTests {
    static func run() throws {
        try groupsEarlierTasksNewestDayFirst()
        try completedTasksStayInTheirDay()
        try todayNotesAndSubtasksStayOut()
        try categoryFilterKeepsThatCategory()
    }

    static func groupsEarlierTasksNewestDayFirst() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let yesterday = DailyView.shiftDay(today, by: -1, calendar: calendar)
        let older = DailyView.shiftDay(today, by: -3, calendar: calendar)
        let items = [
            MemoItem(type: .task, title: "Older", sortOrder: 0, scheduledDate: older),
            MemoItem(type: .task, title: "Yesterday B", sortOrder: 1, scheduledDate: yesterday),
            MemoItem(type: .task, title: "Yesterday A", sortOrder: 0, scheduledDate: yesterday),
        ]
        let days = DailyView.historyDays(in: items, before: today, calendar: calendar)
        try expectEqual(days.map(\.day), [yesterday, older])
        try expectEqual(days[0].items.map(\.title), ["Yesterday A", "Yesterday B"])
        try expectEqual(days[1].items.map(\.title), ["Older"])
    }

    static func completedTasksStayInTheirDay() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let yesterday = DailyView.shiftDay(today, by: -1, calendar: calendar)
        let items = [
            MemoItem(
                type: .task,
                title: "Done",
                isCompleted: true,
                completedAt: yesterday,
                sortOrder: 0,
                scheduledDate: yesterday
            ),
        ]
        let days = DailyView.historyDays(in: items, before: today, calendar: calendar)
        try expectEqual(days.flatMap(\.items).map(\.title), ["Done"])
    }

    static func todayNotesAndSubtasksStayOut() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let yesterday = DailyView.shiftDay(today, by: -1, calendar: calendar)
        let parent = MemoItem(type: .task, title: "Parent", sortOrder: 0, scheduledDate: yesterday)
        let items = [
            parent,
            MemoItem(parentId: parent.id, type: .task, title: "Child", sortOrder: 0, scheduledDate: yesterday),
            MemoItem(type: .note, title: "Note", sortOrder: 1, scheduledDate: yesterday),
            MemoItem(type: .task, title: "Today", sortOrder: 0, scheduledDate: today),
            MemoItem(type: .task, title: "Undated", sortOrder: 2, scheduledDate: nil),
        ]
        let days = DailyView.historyDays(in: items, before: today, calendar: calendar)
        try expectEqual(days.flatMap(\.items).map(\.title), ["Parent"])
    }

    static func categoryFilterKeepsThatCategory() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let yesterday = DailyView.shiftDay(today, by: -1, calendar: calendar)
        let work = UUID()
        let items = [
            MemoItem(categoryId: work, type: .task, title: "Work", sortOrder: 0, scheduledDate: yesterday),
            MemoItem(type: .task, title: "None", sortOrder: 1, scheduledDate: yesterday),
        ]
        let days = DailyView.historyDays(in: items, before: today, categoryId: work, calendar: calendar)
        try expectEqual(days.flatMap(\.items).map(\.title), ["Work"])
    }
}
