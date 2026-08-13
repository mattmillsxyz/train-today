import XCTest
@testable import DRILL

final class PlanGeneratorTests: XCTestCase {
    private func settings(
        sports: Set<Tag> = [.soccer, .strength, .cardio],
        days: Set<Int> = [0, 1, 2, 3, 4],
        minutes: Int = 45,
        seed: UInt64 = 42
    ) -> PlanSettings {
        var s = PlanSettings.default
        s.sports = sports
        s.trainingDays = days
        s.sessionMinutes = minutes
        s.seed = seed
        s.hasOnboarded = true
        return s
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        TrainingCalendar.calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Determinism

    /// The plan must not reshuffle when he reopens the app mid-workout.
    func testSameInputsGiveTheSameSession() {
        let s = settings()
        let day = date(2026, 8, 11)
        let first = PlanGenerator.session(for: day, settings: s)
        for _ in 0..<20 {
            XCTAssertEqual(PlanGenerator.session(for: day, settings: s)?.exercises.map(\.id),
                           first?.exercises.map(\.id))
            XCTAssertEqual(PlanGenerator.session(for: day, settings: s)?.title, first?.title)
        }
    }

    func testDifferentSeedsGiveDifferentPlans() {
        let a = PlanGenerator.week(containing: date(2026, 8, 11), settings: settings(seed: 1))
        let b = PlanGenerator.week(containing: date(2026, 8, 11), settings: settings(seed: 2))
        XCTAssertNotEqual(a.map { $0?.exercises.map(\.id) }, b.map { $0?.exercises.map(\.id) })
    }

    /// A year of days, generated twice, must match exactly.
    func testDeterministicAcrossAYear() {
        let s = settings(sports: [.soccer, .football, .track, .plyo], days: [0, 2, 4, 5])
        var first: [String] = []
        var second: [String] = []
        for offset in 0..<365 {
            let day = TrainingCalendar.adding(days: offset, to: date(2026, 1, 1))
            first.append(PlanGenerator.session(for: day, settings: s)?.exercises.map(\.id).joined(separator: ",") ?? "rest")
        }
        for offset in 0..<365 {
            let day = TrainingCalendar.adding(days: offset, to: date(2026, 1, 1))
            second.append(PlanGenerator.session(for: day, settings: s)?.exercises.map(\.id).joined(separator: ",") ?? "rest")
        }
        XCTAssertEqual(first, second)
    }

    // MARK: - Shape

    func testSessionIsWarmupThenDrillsThenCooldown() {
        for offset in 0..<60 {
            let day = TrainingCalendar.adding(days: offset, to: date(2026, 3, 2))
            guard let session = PlanGenerator.session(for: day, settings: settings()) else { continue }
            XCTAssertEqual(session.exercises.first?.tag, .warmup, "\(session.dayKey) does not open with a warmup")
            XCTAssertEqual(session.exercises.last?.tag, .stretch, "\(session.dayKey) does not close with a cooldown")
            XCTAssertFalse(session.mainExercises.isEmpty, "\(session.dayKey) has no drills")
        }
    }

    func testNoDuplicateExercisesWithinASession() {
        for offset in 0..<120 {
            let day = TrainingCalendar.adding(days: offset, to: date(2026, 1, 5))
            guard let session = PlanGenerator.session(for: day, settings: settings()) else { continue }
            let ids = session.exercises.map(\.id)
            XCTAssertEqual(Set(ids).count, ids.count, "\(session.dayKey) repeats an exercise")
        }
    }

    // MARK: - Constraints

    func testOnlyChosenSportsAppear() {
        let chosen: Set<Tag> = [.soccer, .plyo]
        let s = settings(sports: chosen)
        for offset in 0..<120 {
            let day = TrainingCalendar.adding(days: offset, to: date(2026, 1, 5))
            guard let session = PlanGenerator.session(for: day, settings: s) else { continue }
            for exercise in session.mainExercises {
                XCTAssertTrue(
                    chosen.contains(exercise.tag),
                    "\(session.dayKey): \(exercise.id) is \(exercise.tag.rawValue), which was not chosen"
                )
            }
        }
    }

    func testRestDaysAreRestDays() {
        let s = settings(days: [0, 2, 4])
        let week = PlanGenerator.week(containing: date(2026, 8, 11), settings: s)
        XCTAssertNotNil(week[0])
        XCTAssertNil(week[1])
        XCTAssertNotNil(week[2])
        XCTAssertNil(week[3])
        XCTAssertNotNil(week[4])
        XCTAssertNil(week[5])
        XCTAssertNil(week[6])
    }

    func testSessionsLandWithinTheirBudget() {
        for minutes in PlanSettings.sessionLengthOptions {
            let s = settings(minutes: minutes)
            for offset in 0..<90 {
                let day = TrainingCalendar.adding(days: offset, to: date(2026, 1, 5))
                guard let session = PlanGenerator.session(for: day, settings: s) else { continue }
                XCTAssertLessThanOrEqual(
                    session.totalMinutes, minutes,
                    "\(session.dayKey) runs \(session.totalMinutes) min against a \(minutes) min budget"
                )
            }
        }
    }

    /// The within-week rule: consecutive training days never share a drill.
    func testNoDrillRepeatsOnConsecutiveDaysWithinAWeek() {
        let s = settings(sports: [.soccer, .strength, .cardio, .plyo], days: [0, 1, 2, 3, 4, 5, 6])
        for weekOffset in 0..<52 {
            let monday = TrainingCalendar.adding(days: weekOffset * 7, to: date(2026, 1, 5))
            let week = PlanGenerator.week(containing: monday, settings: s)
            for day in 1..<7 {
                guard let today = week[day], let yesterday = week[day - 1] else { continue }
                let shared = Set(today.mainExercises.map(\.id))
                    .intersection(yesterday.mainExercises.map(\.id))
                XCTAssertTrue(
                    shared.isEmpty,
                    "week \(weekOffset) day \(day) repeats \(shared.sorted()) from the day before"
                )
            }
        }
    }

    /// Sports should rotate rather than cluster: over a month, no single sport
    /// owns every session.
    func testSportsRotate() {
        let s = settings(sports: [.soccer, .football, .track, .strength])
        var focusCounts: [Tag: Int] = [:]
        for offset in 0..<28 {
            let day = TrainingCalendar.adding(days: offset, to: date(2026, 5, 4))
            guard let session = PlanGenerator.session(for: day, settings: s),
                  let focus = session.sports.first else { continue }
            focusCounts[focus, default: 0] += 1
        }
        XCTAssertGreaterThanOrEqual(focusCounts.count, 3, "sports are clustering: \(focusCounts)")
    }

    /// A long drill must not be able to eat the budget and leave a single-sport
    /// day: the generator reserves room for the mixed-sport drill up front.
    func testSessionsMixSportsWhenMoreThanOneIsChosen() {
        let s = settings(sports: [.soccer, .strength, .cardio], minutes: 60)
        var mixed = 0
        var total = 0
        for offset in 0..<60 {
            let day = TrainingCalendar.adding(days: offset, to: date(2026, 4, 6))
            guard let session = PlanGenerator.session(for: day, settings: s) else { continue }
            total += 1
            if session.sports.count >= 2 { mixed += 1 }
        }
        XCTAssertGreaterThan(total, 30)
        XCTAssertEqual(mixed, total, "every multi-sport session should touch at least two sports")
    }

    /// Every hand-written `dayWorkouts` entry closed on a strength or plyo drill
    /// before the cooldown. The generator holds budget back so it still can.
    func testSessionsCloseWithAStrengthOrPlyoFinisher() {
        let s = settings(sports: [.soccer, .cardio, .strength, .plyo], minutes: 60)
        for offset in 0..<60 {
            let day = TrainingCalendar.adding(days: offset, to: date(2026, 4, 6))
            guard let session = PlanGenerator.session(for: day, settings: s),
                  let focus = session.sports.first,
                  !Tag.finishers.contains(focus) else { continue }
            let last = session.mainExercises.last
            XCTAssertTrue(
                Tag.finishers.contains(last?.tag ?? .warmup),
                "\(session.dayKey) ends on \(last?.id ?? "nothing") instead of a finisher"
            )
        }
    }

    /// A single-sport plan is a legitimate configuration and must still generate.
    func testSingleSportPlan() {
        let s = settings(sports: [.balance], days: [0, 3])
        let week = PlanGenerator.week(containing: date(2026, 8, 11), settings: s)
        let sessions = week.compactMap { $0 }
        XCTAssertEqual(sessions.count, 2)
        for session in sessions {
            XCTAssertFalse(session.mainExercises.isEmpty)
            XCTAssertTrue(session.mainExercises.allSatisfy { $0.tag == .balance })
        }
    }

    func testEmptySportsOrDaysProducesNothingRatherThanCrashing() {
        XCTAssertTrue(PlanGenerator.week(containing: .now, settings: settings(sports: [])).allSatisfy { $0 == nil })
        XCTAssertTrue(PlanGenerator.week(containing: .now, settings: settings(days: [])).allSatisfy { $0 == nil })
    }

    // MARK: - Calendar

    func testWeekIndexIsMondayAnchored() {
        // The epoch itself is a Monday.
        XCTAssertEqual(TrainingCalendar.weekday(TrainingCalendar.epoch), 0)
        XCTAssertEqual(TrainingCalendar.weekIndex(of: TrainingCalendar.epoch), 0)
        XCTAssertEqual(TrainingCalendar.weekIndex(of: date(2025, 6, 22)), 0, "Sunday belongs to the week before")
        XCTAssertEqual(TrainingCalendar.weekIndex(of: date(2025, 6, 23)), 1)
    }

    func testWeekIndexHandlesDatesBeforeTheEpoch() {
        XCTAssertEqual(TrainingCalendar.weekIndex(of: date(2025, 6, 9)), -1)
        // Negative week indices must still land on a real sport.
        XCTAssertNotNil(PlanGenerator.session(for: date(2025, 6, 9), settings: settings()))
    }

    func testDayKeyRoundTrips() {
        let day = date(2026, 8, 11)
        XCTAssertEqual(TrainingCalendar.dayKey(day), "2026-08-11")
        XCTAssertEqual(TrainingCalendar.date(fromDayKey: "2026-08-11"), day)
    }
}
