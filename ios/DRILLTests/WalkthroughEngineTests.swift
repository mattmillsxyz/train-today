import XCTest
@testable import DRILL

/// Guards the rule that building an engine is inert.
///
/// SwiftUI evaluates `State(initialValue:)` every time a view struct is
/// created, which is on every redraw of the parent, so an engine that starts
/// itself in `init` announces the first step again on every redraw, over the
/// top of whatever step is actually showing.
final class WalkthroughEngineTests: XCTestCase {
    private var exercise: Exercise!

    override func setUp() {
        super.setUp()
        // Keep the suite silent, and off the audio session.
        SpeechService.shared.isEnabled = false
        SoundService.shared.isEnabled = false
        Haptics.isEnabled = false
        // No setup or form steps, so this one runs the moment it begins. That
        // is exactly the shape that used to speak from `init`.
        exercise = ExerciseLibrary.shared["dynamicWarmup"]
        XCTAssertNotNil(exercise)
        XCTAssertTrue(Walkthrough(exercise: exercise).getReady.isEmpty)
    }

    override func tearDown() {
        SpeechService.shared.isEnabled = true
        SoundService.shared.isEnabled = true
        Haptics.isEnabled = true
        super.tearDown()
    }

    func testBuildingAnEngineDoesNotStartIt() {
        let engine = WalkthroughEngine(exercise: exercise)
        XCTAssertEqual(engine.stage, .running, "no get-ready content, so it is ready to run")
        XCTAssertEqual(engine.remainingSeconds, 0, "building the engine must not start the clock")
    }

    func testBeginStartsTheFirstPhase() {
        let engine = WalkthroughEngine(exercise: exercise)
        engine.begin()
        XCTAssertEqual(engine.phaseIndex, 0)
        XCTAssertEqual(engine.remainingSeconds, engine.phases[0].kind.seconds)
    }

    /// The redraw case: `begin()` arriving again must not rewind the exercise.
    func testBeginIsIdempotent() {
        let engine = WalkthroughEngine(exercise: exercise)
        engine.begin()
        engine.skip()
        engine.skip()
        let reached = engine.phaseIndex
        XCTAssertEqual(reached, 2)

        engine.begin()
        XCTAssertEqual(engine.phaseIndex, reached, "a repeat begin must not restart the walkthrough")
    }

    /// An exercise that opens on a get-ready screen must not run until asked.
    func testGetReadyExerciseWaitsForStart() {
        guard let stepped = ExerciseLibrary.shared.all.first(where: {
            !Walkthrough(exercise: $0).getReady.isEmpty
        }) else { return XCTFail("no exercise with a get-ready screen") }

        let engine = WalkthroughEngine(exercise: stepped)
        XCTAssertEqual(engine.stage, .getReady)
        engine.begin()
        XCTAssertEqual(engine.stage, .getReady, "begin must not skip the get-ready screen")
        engine.start()
        XCTAssertEqual(engine.stage, .running)
    }
}
