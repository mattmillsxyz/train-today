import SwiftData
import XCTest
@testable import DRILL

/// The streak rule is deliberately forgiving, and "forgiving" is exactly the
/// kind of thing that silently stops being true. These pin it down.
final class ProgressTests: XCTestCase {
    private var container: ModelContainer!
    private var store: TrainingStore!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Schema([CompletionRecord.self, PersonalRecord.self, EarnedBadge.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = TrainingStore(context: ModelContext(container))
    }

    override func tearDown() {
        store = nil
        container = nil
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        TrainingCalendar.calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func settings(days: Set<Int>) -> PlanSettings {
        var s = PlanSettings.default
        s.trainingDays = days
        s.sports = [.soccer, .strength]
        s.seed = 7
        s.hasOnboarded = true
        return s
    }

    private func markTrained(_ day: Date, exercises: Int = 1) {
        let key = TrainingCalendar.dayKey(day)
        for index in 0..<exercises {
            store.setCompleted(true, dayKey: key, exerciseID: "exercise\(index)")
        }
    }

    // MARK: - Streaks

    func testRestDaysDoNotBreakAStreak() {
        // Mon/Wed/Fri plan. Train all three; the Tue and Thu gaps are rest days.
        let s = settings(days: [0, 2, 4])
        let friday = date(2026, 8, 7)
        markTrained(date(2026, 8, 3))
        markTrained(date(2026, 8, 5))
        markTrained(friday)

        let calculator = ProgressCalculator(store: store, settings: s, today: friday)
        XCTAssertEqual(calculator.currentStreak(), 3)
    }

    func testAMissedTrainingDayBreaksTheStreak() {
        let s = settings(days: [0, 1, 2, 3, 4])
        markTrained(date(2026, 8, 3))
        // Tuesday skipped.
        markTrained(date(2026, 8, 5))
        markTrained(date(2026, 8, 6))

        let calculator = ProgressCalculator(store: store, settings: s, today: date(2026, 8, 6))
        XCTAssertEqual(calculator.currentStreak(), 2)
    }

    /// Opening the app on a training morning must not show a streak of zero.
    func testTodayDoesNotBreakTheStreakBeforeItIsOver() {
        let s = settings(days: [0, 1, 2, 3, 4])
        markTrained(date(2026, 8, 3))
        markTrained(date(2026, 8, 4))

        let calculator = ProgressCalculator(store: store, settings: s, today: date(2026, 8, 5))
        XCTAssertEqual(calculator.currentStreak(), 2, "an unfinished today should not reset the streak")
    }

    func testTrainingOnARestDayCounts() {
        let s = settings(days: [0, 2, 4])
        markTrained(date(2026, 8, 3))
        markTrained(date(2026, 8, 4)) // A Tuesday: not a training day.
        markTrained(date(2026, 8, 5))

        let calculator = ProgressCalculator(store: store, settings: s, today: date(2026, 8, 5))
        XCTAssertEqual(calculator.currentStreak(), 3)
    }

    func testLongestStreakSurvivesALaterBreak() {
        let s = settings(days: [0, 1, 2, 3, 4])
        for day in 3...7 { markTrained(date(2026, 8, day)) } // Mon-Fri
        // The next week: Monday only, then a miss.
        markTrained(date(2026, 8, 10))

        let calculator = ProgressCalculator(store: store, settings: s, today: date(2026, 8, 12))
        XCTAssertEqual(calculator.longestStreak(), 6)
        XCTAssertEqual(calculator.currentStreak(), 0, "Tuesday was missed and is in the past")
    }

    func testNoHistoryMeansNoStreak() {
        let calculator = ProgressCalculator(store: store, settings: settings(days: [0, 1, 2]), today: date(2026, 8, 11))
        XCTAssertEqual(calculator.currentStreak(), 0)
        XCTAssertEqual(calculator.longestStreak(), 0)
    }

    // MARK: - Day status

    func testDayStatus() {
        let s = settings(days: [0, 1, 2, 3, 4])
        let today = date(2026, 8, 12) // A Wednesday.
        markTrained(date(2026, 8, 10))

        let calculator = ProgressCalculator(store: store, settings: s, today: today)
        XCTAssertEqual(calculator.status(of: date(2026, 8, 10)), .partial)
        XCTAssertEqual(calculator.status(of: date(2026, 8, 11)), .missed)
        XCTAssertEqual(calculator.status(of: today), .upcoming, "today is not a miss until it's over")
        XCTAssertEqual(calculator.status(of: date(2026, 8, 13)), .upcoming)
        XCTAssertEqual(calculator.status(of: date(2026, 8, 15)), .rest, "Saturday is not a training day")
    }

    // MARK: - Records

    func testLogRecordReportsWhetherItBeatTheBest() throws {
        let juggling = try XCTUnwrap(ExerciseLibrary.shared["jugglingBasic"])
        XCTAssertTrue(store.logRecord(12, for: juggling), "the first record is always a PR")
        XCTAssertFalse(store.logRecord(9, for: juggling))
        XCTAssertTrue(store.logRecord(20, for: juggling))
        XCTAssertEqual(store.best(for: juggling), 20)
        XCTAssertEqual(store.history(for: juggling.id).count, 3)
    }

    /// Cone dribbling is timed, so a *lower* number is the better one.
    func testLowerIsBetterMetrics() throws {
        let cones = try XCTUnwrap(ExerciseLibrary.shared["coneDribbling"])
        XCTAssertEqual(cones.prMetric?.higherIsBetter, false)
        XCTAssertTrue(store.logRecord(30, for: cones))
        XCTAssertTrue(store.logRecord(24, for: cones))
        XCTAssertFalse(store.logRecord(28, for: cones))
        XCTAssertEqual(store.best(for: cones), 24)
    }

    // MARK: - Badges

    func testFirstBadgesArriveOnDayOne() {
        let s = settings(days: [0, 1, 2, 3, 4])
        markTrained(date(2026, 8, 10))
        let calculator = ProgressCalculator(store: store, settings: s, today: date(2026, 8, 10))
        XCTAssertTrue(calculator.eligibleBadges().contains("firstExercise"))
    }

    func testBadgesAreAwardedOnlyOnce() {
        markTrained(date(2026, 8, 10))
        XCTAssertEqual(store.award(["firstExercise"]), ["firstExercise"])
        XCTAssertEqual(store.award(["firstExercise"]), [])
        XCTAssertTrue(store.hasBadge("firstExercise"))
    }

    func testEveryBadgeIDInTheCatalogIsReachable() {
        // Guards against a badge being awarded under an id nothing displays.
        let s = settings(days: [0, 1, 2, 3, 4])
        let calculator = ProgressCalculator(store: store, settings: s, today: date(2026, 8, 10))
        for id in calculator.eligibleBadges() {
            XCTAssertNotNil(Badge.named(id), "awarded '\(id)' has no entry in Badge.all")
        }
    }

    // MARK: - History

    func testDeleteAllHistoryClearsEverything() throws {
        let juggling = try XCTUnwrap(ExerciseLibrary.shared["jugglingBasic"])
        markTrained(date(2026, 8, 10), exercises: 3)
        store.logRecord(15, for: juggling)
        store.award(["firstExercise"])

        store.deleteAllHistory()

        XCTAssertTrue(store.completions.isEmpty)
        XCTAssertTrue(store.records.isEmpty)
        XCTAssertTrue(store.earnedBadges.isEmpty)
    }

    func testTogglingCompletionIsIdempotent() {
        let key = TrainingCalendar.dayKey(date(2026, 8, 10))
        store.setCompleted(true, dayKey: key, exerciseID: "pushups")
        store.setCompleted(true, dayKey: key, exerciseID: "pushups")
        XCTAssertEqual(store.completedCount(dayKey: key), 1)
        store.setCompleted(false, dayKey: key, exerciseID: "pushups")
        store.setCompleted(false, dayKey: key, exerciseID: "pushups")
        XCTAssertEqual(store.completedCount(dayKey: key), 0)
    }
}
