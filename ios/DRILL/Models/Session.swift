import Foundation

/// One day's workout. Composed by `PlanGenerator`, never stored — regenerating
/// from `(seed, date, settings)` always gives the same answer, so there is
/// nothing to persist except which exercises got completed.
struct Session: Equatable, Identifiable, Sendable {
    let date: Date
    let title: String
    /// The sports on show, for the header pills. Warmup and stretch are omitted.
    let sports: [Tag]
    let exercises: [Exercise]

    var id: String { TrainingCalendar.dayKey(date) }
    var dayKey: String { id }
    var totalMinutes: Int { exercises.reduce(0) { $0 + $1.estimatedMinutes } }

    /// The drills the session is actually *about* — used by the no-repeats rule,
    /// which has no opinion about the warmup and cooldown that bookend every day.
    var mainExercises: [Exercise] {
        exercises.filter { $0.tag != .warmup && $0.tag != .stretch }
    }
}
