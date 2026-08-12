import Foundation

/// What a step asks the athlete to do, and how the walkthrough should time it.
///
/// A `nil` timing means the step is self-paced: it shows, it is spoken, and it
/// waits for a tap. The four cases below are the shapes `tools/validate-content.js`
/// enforces in `exercises.json`.
enum Timing: Equatable, Hashable, Sendable {
    /// A clock. "Jog in place for 1 minute."
    case work(seconds: Int)

    /// A count, self-paced. `each` names the thing being doubled ("leg",
    /// "direction") when the count applies per side.
    case reps(count: Int, each: String?)

    /// Work and rest that both live inside *this* step. Exactly one of `work`
    /// (seconds) or `reps` (count) may be set; neither means the work is
    /// self-paced. "Hold 30 seconds. Rest 20 seconds. Repeat 3 times."
    case interval(work: Int?, reps: Int?, each: String?, rest: Int, rounds: Int)

    /// This step is a rest phase plus a jump back to an earlier step. The work
    /// lives in steps `repeatFrom ..< thisStep` (1-based, inclusive of
    /// `repeatFrom`). "Do 8 sprints total. Rest 45 seconds after every 2."
    case loop(repeatFrom: Int, rounds: Int, rest: Int, restEvery: Int)
}

extension Timing: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, seconds, count, each, work, reps, rest, rounds, repeatFrom, restEvery
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "work":
            self = .work(seconds: try c.decode(Int.self, forKey: .seconds))
        case "reps":
            self = .reps(
                count: try c.decode(Int.self, forKey: .count),
                each: try c.decodeIfPresent(String.self, forKey: .each)
            )
        case "interval":
            self = .interval(
                work: try c.decodeIfPresent(Int.self, forKey: .work),
                reps: try c.decodeIfPresent(Int.self, forKey: .reps),
                each: try c.decodeIfPresent(String.self, forKey: .each),
                rest: try c.decode(Int.self, forKey: .rest),
                rounds: try c.decode(Int.self, forKey: .rounds)
            )
        case "loop":
            self = .loop(
                repeatFrom: try c.decode(Int.self, forKey: .repeatFrom),
                rounds: try c.decode(Int.self, forKey: .rounds),
                rest: try c.decode(Int.self, forKey: .rest),
                restEvery: try c.decode(Int.self, forKey: .restEvery)
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c, debugDescription: "Unknown timing type '\(type)'"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .work(let seconds):
            try c.encode("work", forKey: .type)
            try c.encode(seconds, forKey: .seconds)
        case .reps(let count, let each):
            try c.encode("reps", forKey: .type)
            try c.encode(count, forKey: .count)
            try c.encode(each, forKey: .each)
        case .interval(let work, let reps, let each, let rest, let rounds):
            try c.encode("interval", forKey: .type)
            try c.encode(work, forKey: .work)
            try c.encode(reps, forKey: .reps)
            try c.encode(each, forKey: .each)
            try c.encode(rest, forKey: .rest)
            try c.encode(rounds, forKey: .rounds)
        case .loop(let repeatFrom, let rounds, let rest, let restEvery):
            try c.encode("loop", forKey: .type)
            try c.encode(repeatFrom, forKey: .repeatFrom)
            try c.encode(rounds, forKey: .rounds)
            try c.encode(rest, forKey: .rest)
            try c.encode(restEvery, forKey: .restEvery)
        }
    }
}
