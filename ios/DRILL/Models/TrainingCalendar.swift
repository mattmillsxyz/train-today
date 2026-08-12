import Foundation

/// Date arithmetic shared by the generator, the store and the views.
///
/// Everything is Monday-anchored and day-granular. `dayKey` matches the string
/// the web app wrote to localStorage, so a future importer has a format to read.
enum TrainingCalendar {
    /// The web app's `EPOCH` — June 16, 2025, an arbitrary fixed Monday. Kept so
    /// week numbering stays continuous with the app he has been using.
    static let epoch: Date = {
        var c = DateComponents()
        c.year = 2025
        c.month = 6
        c.day = 16
        return calendar.date(from: c)!
    }()

    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Monday == 0 … Sunday == 6.
    static func weekday(_ date: Date) -> PlanSettings.Weekday {
        (calendar.component(.weekday, from: date) + 5) % 7
    }

    /// The Monday of the week containing `date`.
    static func monday(of date: Date) -> Date {
        calendar.date(byAdding: .day, value: -weekday(date), to: startOfDay(date))!
    }

    /// Whole weeks between the epoch Monday and the Monday of `date`. Negative
    /// before the epoch, which is fine — the generator floor-mods it.
    static func weekIndex(of date: Date) -> Int {
        let days = calendar.dateComponents([.day], from: epoch, to: monday(of: date)).day ?? 0
        return Int((Double(days) / 7).rounded(.down))
    }

    static func startOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    }

    static func adding(days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date)!
    }

    static func days(from: Date, to: Date) -> Int {
        calendar.dateComponents([.day], from: startOfDay(from), to: startOfDay(to)).day ?? 0
    }

    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    /// `2026-08-11`. Stable, sortable, timezone-free once written.
    static func dayKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(fromDayKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

/// Non-negative modulo. `-1 % 7` is `-1` in Swift; weeks before the epoch need `6`.
func floorMod(_ a: Int, _ n: Int) -> Int {
    precondition(n > 0)
    let r = a % n
    return r < 0 ? r + n : r
}
