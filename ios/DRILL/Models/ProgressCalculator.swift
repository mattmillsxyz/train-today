import Foundation

/// How a single day reads on the calendar heat map.
enum DayStatus: Sendable {
    /// Not a training day. Deliberately neutral — it is not a miss.
    case rest
    /// A training day still ahead.
    case upcoming
    /// A training day that came and went with nothing ticked off.
    case missed
    /// Some of the session done.
    case partial
    /// Everything ticked off.
    case complete
}

struct ProgressStats: Sendable {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    /// Days with at least one exercise completed.
    var daysTrained: Int = 0
    /// Days where every exercise in the session was ticked off.
    var workoutsFinished: Int = 0
    var exercisesCompleted: Int = 0
    var recordsLogged: Int = 0
}

/// Derives streaks, the heat map and badge eligibility from the store.
///
/// The streak rule is deliberately forgiving: **rest days never break a streak**,
/// and today does not break it until the day is actually over. A missed Tuesday
/// on a Mon/Wed/Fri plan is not a miss at all. A 9-year-old should not be punished
/// by the plan he configured himself.
struct ProgressCalculator {
    let store: TrainingStore
    let settings: PlanSettings
    let today: Date

    init(store: TrainingStore, settings: PlanSettings, today: Date = .now) {
        self.store = store
        self.settings = settings
        self.today = TrainingCalendar.startOfDay(today)
    }

    // MARK: - Sessions, cached per week

    /// Streak and badge maths sweep hundreds of days, and each one wants its
    /// week's session list. Generating a week is cheap but not free, so results
    /// are memoized against everything that can change them.
    @MainActor
    private final class WeekCache {
        static let shared = WeekCache()
        private var weeks: [String: [Session?]] = [:]

        func week(containing date: Date, settings: PlanSettings) -> [Session?] {
            let key = """
            \(settings.seed)|\(TrainingCalendar.weekIndex(of: date))\
            |\(settings.sports.map(\.rawValue).sorted().joined(separator: ","))\
            |\(settings.trainingDays.sorted().map(String.init).joined(separator: ","))\
            |\(settings.sessionMinutes)
            """
            if let cached = weeks[key] { return cached }
            let week = PlanGenerator.week(containing: date, settings: settings)
            weeks[key] = week
            return week
        }
    }

    private func week(containing date: Date) -> [Session?] {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { WeekCache.shared.week(containing: date, settings: settings) }
        }
        return PlanGenerator.week(containing: date, settings: settings)
    }

    private func session(on date: Date) -> Session? {
        week(containing: date)[TrainingCalendar.weekday(date)]
    }

    // MARK: - Status

    func status(of date: Date) -> DayStatus {
        let day = TrainingCalendar.startOfDay(date)
        let key = TrainingCalendar.dayKey(day)
        let done = store.completedCount(dayKey: key)

        guard settings.isTrainingDay(TrainingCalendar.weekday(day)) else {
            return done > 0 ? .complete : .rest
        }
        if done == 0 {
            // Today counts as still ahead until the day is over, and days before
            // he ever used the app are not misses — a calendar full of red for
            // the months before you installed it is just discouraging.
            guard day < today, let earliest = earliestDay, day >= earliest else { return .upcoming }
            return .missed
        }
        let total = session(on: day)?.exercises.count ?? done
        return done >= total ? .complete : .partial
    }

    // MARK: - Streaks

    /// A day counts toward a streak when at least one exercise was completed.
    /// Finishing the whole session is what the badges measure; showing up is
    /// what the streak measures.
    private func trained(_ date: Date) -> Bool {
        store.completedCount(dayKey: TrainingCalendar.dayKey(date)) > 0
    }

    private var earliestDay: Date? {
        store.trainedDayKeys
            .compactMap(TrainingCalendar.date(fromDayKey:))
            .min()
    }

    func currentStreak() -> Int {
        guard let earliest = earliestDay else { return 0 }
        var count = 0
        var day = today
        while day >= earliest {
            if settings.isTrainingDay(TrainingCalendar.weekday(day)) {
                if trained(day) {
                    count += 1
                } else if !TrainingCalendar.isSameDay(day, today) {
                    break
                }
                // Today with nothing done yet: the day is not over, so it neither
                // counts nor breaks.
            } else if trained(day) {
                // Training on a rest day is a bonus, and it counts.
                count += 1
            }
            day = TrainingCalendar.adding(days: -1, to: day)
        }
        return count
    }

    func longestStreak() -> Int {
        guard let earliest = earliestDay else { return 0 }
        var best = 0
        var run = 0
        var day = earliest
        while day <= today {
            if trained(day) {
                run += 1
                best = max(best, run)
            } else if settings.isTrainingDay(TrainingCalendar.weekday(day)),
                      !TrainingCalendar.isSameDay(day, today) {
                run = 0
            }
            day = TrainingCalendar.adding(days: 1, to: day)
        }
        return best
    }

    // MARK: - Aggregates

    func stats() -> ProgressStats {
        var stats = ProgressStats()
        stats.currentStreak = currentStreak()
        stats.longestStreak = longestStreak()
        stats.recordsLogged = store.totalRecordsLogged

        for key in store.trainedDayKeys {
            guard let day = TrainingCalendar.date(fromDayKey: key) else { continue }
            let done = store.completedCount(dayKey: key)
            stats.daysTrained += 1
            stats.exercisesCompleted += done
            if let total = session(on: day)?.exercises.count, done >= total {
                stats.workoutsFinished += 1
            }
        }
        return stats
    }

    // MARK: - Badges

    /// Every badge whose condition is currently satisfied. The store filters out
    /// the ones already earned.
    func eligibleBadges() -> [String] {
        let stats = stats()
        var earned: [String] = []

        if stats.exercisesCompleted >= 1 { earned.append("firstExercise") }
        if stats.workoutsFinished >= 1 { earned.append("firstWorkout") }
        if stats.workoutsFinished >= 10 { earned.append("workouts10") }
        if stats.workoutsFinished >= 50 { earned.append("workouts50") }
        if stats.workoutsFinished >= 100 { earned.append("workouts100") }
        if stats.currentStreak >= 3 || stats.longestStreak >= 3 { earned.append("streak3") }
        if stats.currentStreak >= 7 || stats.longestStreak >= 7 { earned.append("streak7") }
        if stats.currentStreak >= 30 || stats.longestStreak >= 30 { earned.append("streak30") }
        if stats.recordsLogged >= 1 { earned.append("firstPR") }
        if stats.recordsLogged >= 10 { earned.append("prs10") }
        if hasPerfectWeek() { earned.append("perfectWeek") }
        if hasEverySportWeek() { earned.append("everySport") }

        return earned
    }

    /// Every training day of some week fully completed.
    private func hasPerfectWeek() -> Bool {
        mondays().contains { monday in
            let week = week(containing: monday)
            let trainingDays = week.enumerated().compactMap { $0.element == nil ? nil : $0.offset }
            guard !trainingDays.isEmpty else { return false }
            return trainingDays.allSatisfy { weekday in
                guard let session = week[weekday] else { return false }
                let day = TrainingCalendar.adding(days: weekday, to: monday)
                return store.completedCount(dayKey: TrainingCalendar.dayKey(day)) >= session.exercises.count
            }
        }
    }

    /// Every chosen sport touched inside a single week.
    private func hasEverySportWeek() -> Bool {
        guard !settings.sports.isEmpty else { return false }
        return mondays().contains { monday in
            var seen: Set<Tag> = []
            for offset in 0..<7 {
                let day = TrainingCalendar.adding(days: offset, to: monday)
                let key = TrainingCalendar.dayKey(day)
                guard let done = store.completions[key], !done.isEmpty else { continue }
                for id in done {
                    if let tag = ExerciseLibrary.shared[id]?.tag { seen.insert(tag) }
                }
            }
            return settings.sports.isSubset(of: seen)
        }
    }

    /// The Mondays of every week that has any completed exercise in it.
    private func mondays() -> [Date] {
        let days = store.trainedDayKeys.compactMap(TrainingCalendar.date(fromDayKey:))
        return Array(Set(days.map(TrainingCalendar.monday(of:)))).sorted()
    }
}
