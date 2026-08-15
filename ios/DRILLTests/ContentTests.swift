import XCTest
@testable import DRILL

/// Guards the bundled library against the numbers `tools/validate-content.js`
/// reports. If the JSON changes, one of these fails and the mismatch is obvious.
final class ContentTests: XCTestCase {
    private let library = ExerciseLibrary.shared

    func testLibraryDecodes() {
        XCTAssertEqual(library.all.count, 39)
        XCTAssertEqual(library.all.reduce(0) { $0 + $1.steps.count }, 203)
    }

    func testModeSplit() {
        XCTAssertEqual(library.all.count { $0.mode == .stepped }, 27)
        XCTAssertEqual(library.all.count { $0.mode == .openBlock }, 12)
    }

    func testRoleCounts() {
        var counts: [StepRole: Int] = [:]
        for step in library.all.flatMap(\.steps) {
            counts[step.role, default: 0] += 1
        }
        XCTAssertEqual(counts[.setup], 21)
        XCTAssertEqual(counts[.form], 42)
        XCTAssertEqual(counts[.cue], 37)
        XCTAssertEqual(counts[.action], 103)
    }

    /// The claim the walkthrough design rests on: only action steps gate, and
    /// there are 68 of them across the stepped exercises.
    func testWalkthroughGateCount() {
        let gates = library.all
            .filter { $0.mode == .stepped }
            .reduce(0) { $0 + $1.actionSteps.count }
        XCTAssertEqual(gates, 68)
    }

    func testEveryTimedStepIsAnAction() {
        for exercise in library.all {
            for (index, step) in exercise.steps.enumerated() where step.timing != nil {
                XCTAssertEqual(
                    step.role, .action,
                    "\(exercise.id) step \(index + 1) carries a clock but is a '\(step.role.rawValue)'"
                )
            }
        }
    }

    func testEveryExerciseHasAtLeastOneAction() {
        for exercise in library.all {
            XCTAssertFalse(exercise.actionSteps.isEmpty, "\(exercise.id) would open and immediately finish")
        }
    }

    func testUniqueIDsAndLookup() {
        XCTAssertEqual(Set(library.all.map(\.id)).count, library.all.count)
        XCTAssertEqual(library["plankHold"]?.name, "Plank Hold")
        XCTAssertNil(library["nope"])
    }

    /// Every tag the generator draws from has to have something in it.
    func testEveryTagHasExercises() {
        for tag in Tag.allCases {
            XCTAssertFalse(library.exercises(tagged: tag).isEmpty, "\(tag.rawValue) pool is empty")
        }
    }

    /// Two `Set<Tag>` values with the same elements are not guaranteed to iterate
    /// in the same order, which silently broke the generator's determinism once.
    func testTagPoolOrderDoesNotDependOnSetOrdering() {
        let expected = library.exercises(taggedAnyOf: [Tag.football, .soccer])
        for _ in 0..<50 {
            let set: Set<Tag> = [.soccer, .football]
            XCTAssertEqual(library.exercises(taggedAnyOf: set).map(\.id), expected.map(\.id))
        }
    }

    func testTimingShapesDecodeAsExpected() {
        XCTAssertEqual(library["plankHold"]?.steps[3].timing,
                       .interval(work: 30, reps: nil, each: nil, rest: 20, rounds: 3))
        XCTAssertEqual(library["pushups"]?.steps[4].timing,
                       .interval(work: nil, reps: 10, each: nil, rest: 30, rounds: 3))
        XCTAssertEqual(library["sprintIntervals"]?.steps[4].timing,
                       .loop(repeatFrom: 3, rounds: 8, rest: 45, restEvery: 2))
        XCTAssertEqual(library["dynamicWarmup"]?.steps[0].timing, .work(seconds: 60))
        XCTAssertEqual(library["dynamicWarmup"]?.steps[3].timing, .reps(count: 10, each: "leg"))
    }

    /// The prompts the content already made in prose are now logged numbers.
    func testPersonalRecordMetrics() {
        let tracked = library.all.filter { $0.prMetric != nil }
        XCTAssertEqual(tracked.count, 12)
        XCTAssertEqual(library["jugglingBasic"]?.prMetric?.label, "Best juggling streak")
        XCTAssertEqual(library["coneDribbling"]?.prMetric?.higherIsBetter, false)
    }
}
