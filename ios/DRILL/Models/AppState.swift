import SwiftUI
import UIKit

/// The bit of UI state the tabs share: which day is open, which tab is
/// showing it, and what "today" currently means.
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

    /// The current day, republished when it actually rolls over.
    ///
    /// Views read this rather than `.now` so that a rollover re-renders them.
    /// Reading `.now` inside a body only samples the clock at whatever moment
    /// SwiftUI happened to last evaluate it, so the "today" ring and the
    /// calendar's month window would otherwise sit on yesterday until some
    /// unrelated state change forced a redraw.
    private(set) var today: Date = TrainingCalendar.startOfDay(.now)

    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        let refresh: (Notification) -> Void = { [weak self] _ in self?.refreshToday() }
        observers = [
            // Fires at midnight while the app is running.
            center.addObserver(
                forName: NSNotification.Name.NSCalendarDayChanged,
                object: nil, queue: .main, using: refresh
            ),
            // The day change never arrives while suspended, so coming back to
            // the foreground is what catches an overnight gap.
            center.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil, queue: .main, using: refresh
            ),
            // Time zone changes and manual clock changes.
            center.addObserver(
                forName: UIApplication.significantTimeChangeNotification,
                object: nil, queue: .main, using: refresh
            ),
        ]
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    /// Deliberately leaves `selectedDate` alone. Moving it would yank the
    /// screen out from under someone training just before midnight; the header
    /// offers "Jump to today" instead, which is now correct again.
    func refreshToday() {
        let start = TrainingCalendar.startOfDay(.now)
        guard start != today else { return }
        today = start
    }

    var isShowingToday: Bool {
        TrainingCalendar.isSameDay(selectedDate, today)
    }

    func open(_ date: Date) {
        selectedDate = TrainingCalendar.startOfDay(date)
        tab = .today
    }

    func jumpToToday() {
        refreshToday()
        selectedDate = today
    }

    func shiftDay(_ delta: Int) {
        selectedDate = TrainingCalendar.adding(days: delta, to: selectedDate)
    }
}
