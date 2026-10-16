import Foundation
import PeekMeowCore

enum SelectedDateNavigationTests {
    static func run() throws {
        try shiftMovesOneDay()
        try startOfDayIsStable()
        try followingTodayMovesAcrossMidnight()
        try followingTodaySkipsToTheRealDayAfterSeveralNights()
        try aChosenDayStaysAcrossMidnight()
    }

    static func shiftMovesOneDay() throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let next = DailyView.shiftDay(day, by: 1, calendar: calendar)
        let prev = DailyView.shiftDay(day, by: -1, calendar: calendar)
        try expect(!DailyView.isSameDay(day, next, calendar: calendar))
        try expect(!DailyView.isSameDay(day, prev, calendar: calendar))
        try expect(DailyView.isSameDay(DailyView.shiftDay(next, by: -1, calendar: calendar), day, calendar: calendar))
    }

    static func startOfDayIsStable() throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let a = DailyView.startOfDay(day, calendar: calendar)
        let b = DailyView.startOfDay(a.addingTimeInterval(10_000), calendar: calendar)
        try expect(DailyView.isSameDay(a, b, calendar: calendar))
    }

    static func followingTodayMovesAcrossMidnight() throws {
        let calendar = Calendar(identifier: .gregorian)
        let selected = DailyView.startOfDay(Date(timeIntervalSince1970: 1_700_000_000), calendar: calendar)
        let nextMorning = DailyView.shiftDay(selected, by: 1, calendar: calendar).addingTimeInterval(9 * 3_600)
        let followed = DailyView.followedDay(
            selected: selected,
            followsToday: true,
            now: nextMorning,
            calendar: calendar
        )
        try expect(DailyView.isSameDay(followed, nextMorning, calendar: calendar))
        let sameEvening = DailyView.followedDay(
            selected: selected,
            followsToday: true,
            now: selected.addingTimeInterval(20 * 3_600),
            calendar: calendar
        )
        try expect(DailyView.isSameDay(sameEvening, selected, calendar: calendar))
    }

    static func followingTodaySkipsToTheRealDayAfterSeveralNights() throws {
        let calendar = Calendar(identifier: .gregorian)
        let selected = DailyView.startOfDay(Date(timeIntervalSince1970: 1_700_000_000), calendar: calendar)
        let later = DailyView.shiftDay(selected, by: 3, calendar: calendar)
        let followed = DailyView.followedDay(
            selected: selected,
            followsToday: true,
            now: later,
            calendar: calendar
        )
        try expect(DailyView.isSameDay(followed, later, calendar: calendar))
    }

    static func aChosenDayStaysAcrossMidnight() throws {
        let calendar = Calendar(identifier: .gregorian)
        let selected = DailyView.startOfDay(Date(timeIntervalSince1970: 1_700_000_000), calendar: calendar)
        let nextMorning = DailyView.shiftDay(selected, by: 1, calendar: calendar)
        let stayed = DailyView.followedDay(
            selected: selected,
            followsToday: false,
            now: nextMorning,
            calendar: calendar
        )
        try expect(DailyView.isSameDay(stayed, selected, calendar: calendar))
    }
}
