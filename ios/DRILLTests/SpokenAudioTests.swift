import XCTest
@testable import DRILL

/// The walkthrough is listened to more than it is watched, so two phases in a
/// row must never say the same thing. If they do, the athlete cannot tell that
/// anything changed.
final class SpokenAudioTests: XCTestCase {
    func testNoTwoConsecutivePhasesSayTheSameThing() {
        var offenders: [String] = []
        for exercise in ExerciseLibrary.shared.all {
            let phases = Walkthrough(exercise: exercise).phases
            for (a, b) in zip(phases, phases.dropFirst()) where a.spoken == b.spoken {
                offenders.append("\(exercise.id): phase \(a.id) and \(b.id) both say \(a.spoken.debugDescription)")
            }
        }
        XCTAssertTrue(offenders.isEmpty, "Consecutive phases repeat themselves:\n" + offenders.joined(separator: "\n"))
    }
}
