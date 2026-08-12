import SwiftUI

/// The bit of UI state the tabs share: which day is open, and which tab is
/// showing it.
///
/// Tapping a date in Calendar has to both select that day and bring Today
/// forward, which neither screen can do on its own.
@Observable
final class AppState {
    enum Tab: Hashable {
        case today
        case calendar
        case progress
        case settings
    }

    var tab: Tab = .today
    var selectedDate: Date = TrainingCalendar.startOfDay(.now)

    var isShowingToday: Bool {
        TrainingCalendar.isSameDay(selectedDate, .now)
    }

    func open(_ date: Date) {
        selectedDate = TrainingCalendar.startOfDay(date)
        tab = .today
    }

    func jumpToToday() {
        selectedDate = TrainingCalendar.startOfDay(.now)
    }

    func shiftDay(_ delta: Int) {
        selectedDate = TrainingCalendar.adding(days: delta, to: selectedDate)
    }
}
