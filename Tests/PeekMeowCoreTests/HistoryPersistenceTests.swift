import Foundation
import PeekMeowCore

enum HistoryPersistenceTests {
    static func run() throws {
        try historyKeepsCompletedTasksAndDropsToday()
    }

    static func historyKeepsCompletedTasksAndDropsToday() throws {
        let scratch = try PersistenceTestSupport.makeScratch()
        defer { PersistenceTestSupport.remove(scratch) }
        let store = try PersistenceTestSupport.open(scratch)
        let today = PersistenceTestSupport.today()
        let recent = PersistenceTestSupport.day(-1, from: today)
        let older = PersistenceTestSupport.day(-2, from: today)

        let done = try store.memos.createTask(title: "Done", scheduledDate: recent, categoryId: nil)
        try store.memos.toggleCompleted(id: done.id, at: recent.addingTimeInterval(3600))
        _ = try store.memos.createNote(title: "Note", scheduledDate: recent, categoryId: nil)
        let parent = try store.memos.createTask(title: "Parent", scheduledDate: older, categoryId: nil)
        _ = try store.memos.createSubtask(parentID: parent.id, title: "Child")
        _ = try store.memos.createTask(title: "Today", scheduledDate: today, categoryId: nil)
        _ = try store.memos.createTask(title: "Recent open", scheduledDate: recent, categoryId: nil)

        let roots = try store.memos.fetchHistoryRoots(before: today)
        try expectEqual(roots.map(\.title), ["Done", "Recent open", "Parent"])
        try expect(roots[0].isCompleted)
        let children = try store.memos.fetchChildren(parentId: parent.id)
        try expectEqual(children.map(\.title), ["Child"])
    }
}
