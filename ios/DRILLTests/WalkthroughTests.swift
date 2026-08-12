import XCTest
@testable import DRILL

/// The phase expansion is the piece of logic the whole timer rests on, and the
/// loop cases are the easiest thing in the app to get subtly wrong — "8 sprints,
/// rest after every 2" has to produce 8 sprints and 3 rests, not 8 rests.
final class WalkthroughTests: XCTestCase {
    private func walkthrough(_ id: String) throws -> Walkthrough {
        let exercise = try XCTUnwrap(ExerciseLibrary.shared[id], "missing exercise \(id)")
        return Walkthrough(exercise: exercise)
    }

    // MARK: - Get ready

    func testGetReadyTakesSetupAndFormSteps() throws {
        let pushups = try walkthrough("pushups")
        XCTAssertEqual(pushups.getReady.setup.count, 0)
        XCTAssertEqual(pushups.getReady.form.count, 3)

        let sprints = try walkthrough("sprintIntervals")
        XCTAssertEqual(sprints.getReady.setup.count, 2)
        XCTAssertEqual(sprints.getReady.form.count, 0)
    }

    /// The whole point of the `role` field: 129 screens become 64 gates.
    func testOnlyActionStepsProducePhases() throws {
        let pushups = try walkthrough("pushups")
        XCTAssertEqual(pushups.exercise.steps.count, 5)
        // One action step, expanded into 3 sets and 2 rests.
        XCTAssertEqual(pushups.phases.count, 5)
    }

    // MARK: - Intervals

    func testIntervalWithTimedWork() throws {
        // Plank Hold: hold 30s, rest 20s, three times.
        let phases = try walkthrough("plankHold").phases
        XCTAssertEqual(phases.map(\.kind), [
            .work(seconds: 30), .rest(seconds: 20),
            .work(seconds: 30), .rest(seconds: 20),
            .work(seconds: 30),
        ])
        XCTAssertEqual(phases[0].round?.label, "Set 1 of 3")
        XCTAssertEqual(phases[4].round?.label, "Set 3 of 3")
    }

    func testIntervalWithRepsShowsNoClock() throws {
        // Push-Ups: 10 reps, rest 30s, three sets.
        let phases = try walkthrough("pushups").phases
        XCTAssertEqual(phases.map(\.kind), [
            .reps(count: 10, each: nil), .rest(seconds: 30),
            .reps(count: 10, each: nil), .rest(seconds: 30),
            .reps(count: 10, each: nil),
        ])
        XCTAssertNil(phases[0].kind.seconds, "a reps phase must not carry a countdown")
        XCTAssertFalse(phases[0].kind.advancesAutomatically)
        XCTAssertTrue(phases[1].kind.advancesAutomatically, "rest is timed")
    }

    func testIntervalWithSelfPacedWork() throws {
        // Stride Drills step 5: bound 20 yards, rest, repeat twice.
        let phases = try walkthrough("strideDrills").phases
        XCTAssertEqual(phases.count, 7)
        XCTAssertEqual(phases.suffix(3).map(\.kind), [.selfPaced, .rest(seconds: 30), .selfPaced])
    }

    // MARK: - Loops

    func testLoopRepeatsTheBodyNotTheLoopStep() throws {
        // Sprint Intervals: sprint + walk back, 8 times, resting after every 2.
        let phases = try walkthrough("sprintIntervals").phases
        XCTAssertEqual(phases.count, 19, "8 rounds × 2 steps + 3 rests")
        XCTAssertEqual(phases.count { $0.kind.isRest }, 3)
        XCTAssertEqual(phases.count { $0.kind == .rest(seconds: 45) }, 3)
        XCTAssertEqual(phases.last?.round?.label, "Set 8 of 8")
    }

    func testLoopRestsFallBetweenGroupsNotAfterTheLastOne() throws {
        let phases = try walkthrough("sprintIntervals").phases
        let restIndices = phases.indices.filter { phases[$0].kind.isRest }
        // Two sprint steps per round: rests land after rounds 2, 4 and 6.
        XCTAssertEqual(restIndices, [4, 9, 14])
        XCTAssertFalse(phases.last?.kind.isRest ?? true, "an exercise must not end on a rest")
    }

    func testLoopWithRestEveryRound() throws {
        // Cone Dribbling: two passes through the cones, three sets, rest between.
        let phases = try walkthrough("coneDribbling").phases
        XCTAssertEqual(phases.count, 8, "3 sets × 2 steps + 2 rests")
        XCTAssertEqual(phases.count { $0.kind.isRest }, 2)
    }

    func testSingleStepLoop() throws {
        // Duck Walks: one action step repeated three times.
        let phases = try walkthrough("duckWalks").phases
        XCTAssertEqual(phases.count, 5, "3 rounds + 2 rests")
    }

    /// The loop step's own text describes the rest, so it belongs on the rest
    /// screen rather than being spoken as if it were work.
    func testLoopStepTextBecomesRestDetail() throws {
        let phases = try walkthrough("coneDribbling").phases
        let rest = try XCTUnwrap(phases.first { $0.kind.isRest })
        XCTAssertEqual(rest.title, "Rest")
        XCTAssertEqual(rest.detail, "Rest 30 seconds, then repeat. Try to go a little faster each set.")
        XCTAssertEqual(rest.spoken, "Rest. 30 seconds.")
    }

    // MARK: - Open blocks

    func testOpenBlockIsASingleClock() throws {
        let juggling = try walkthrough("jugglingBasic")
        XCTAssertEqual(juggling.phases.count, 1)
        XCTAssertEqual(juggling.phases[0].kind, .block(seconds: 600))
        XCTAssertEqual(juggling.phases[0].cues.count, 2, "cues ride along with the block")
    }

    // MARK: - Cues

    func testCueAttachesToTheFollowingActionStep() throws {
        // "Keep your core tight the whole time" sits before the work it describes.
        let phases = try walkthrough("pushups").phases
        XCTAssertTrue(phases[0].cues.contains { $0.hasPrefix("Keep your core tight") })
    }

    func testTrailingCueAttachesToThePrecedingActionStep() throws {
        // Plank Hold's "Too easy?" cue is the last step, after the only action.
        let phases = try walkthrough("plankHold").phases
        XCTAssertEqual(phases[0].cues.count, 2)
        XCTAssertTrue(phases[0].cues.contains { $0.hasPrefix("Too easy?") })
    }

    func testCuesNeverGate() throws {
        for exercise in ExerciseLibrary.shared.all {
            let phases = Walkthrough(exercise: exercise).phases
            for phase in phases {
                XCTAssertFalse(
                    exercise.steps.contains { $0.role == .cue && $0.text == phase.title },
                    "\(exercise.id): a cue became a phase of its own"
                )
            }
        }
    }

    // MARK: - Whole library

    func testEveryExerciseProducesAtLeastOnePhase() {
        for exercise in ExerciseLibrary.shared.all {
            XCTAssertFalse(
                Walkthrough(exercise: exercise).phases.isEmpty,
                "\(exercise.id) expands to nothing"
            )
        }
    }

    func testNoExerciseEndsOnARest() {
        for exercise in ExerciseLibrary.shared.all {
            let phases = Walkthrough(exercise: exercise).phases
            XCTAssertFalse(phases.last?.kind.isRest ?? false, "\(exercise.id) ends on a rest phase")
        }
    }

    /// A round label that reads "Set 4 of 3" would be worse than none at all.
    func testRoundLabelsStayInRange() {
        for exercise in ExerciseLibrary.shared.all {
            for phase in Walkthrough(exercise: exercise).phases {
                guard let round = phase.round else { continue }
                XCTAssertGreaterThanOrEqual(round.index, 1, "\(exercise.id)")
                XCTAssertLessThanOrEqual(round.index, round.total, "\(exercise.id)")
            }
        }
    }

    /// Guards against a loop expanding without bound if the content ever grows a
    /// nested one.
    func testExpansionStaysBounded() {
        for exercise in ExerciseLibrary.shared.all {
            XCTAssertLessThan(
                Walkthrough(exercise: exercise).phases.count, 100,
                "\(exercise.id) expanded to an implausible number of phases"
            )
        }
    }
}
