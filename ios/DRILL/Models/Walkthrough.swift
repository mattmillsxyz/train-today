import Foundation

/// One screen of the walkthrough.
///
/// Phases are the unit the timer advances through, and there are far fewer of
/// them than there are steps: only `action` steps produce one. Setup and form
/// steps go to the get-ready screen before the clock starts, and cues ride
/// alongside the work without ever gating it.
struct WalkPhase: Identifiable, Equatable {
    enum Kind: Equatable {
        /// A clock that runs down and moves on by itself.
        case work(seconds: Int)
        /// A count with no clock. Waits for a tap.
        case reps(count: Int, each: String?)
        /// Genuinely self-paced. Waits for a tap.
        case selfPaced
        /// Between rounds. Runs down and moves on by itself.
        case rest(seconds: Int)
        /// `openBlock` mode: one clock for the whole exercise.
        case block(seconds: Int)

        var seconds: Int? {
            switch self {
            case .work(let s), .rest(let s), .block(let s): s
            case .reps, .selfPaced: nil
            }
        }

        var isRest: Bool {
            if case .rest = self { return true }
            return false
        }

        /// Timed phases move on by themselves; only genuinely self-paced work waits.
        var advancesAutomatically: Bool { seconds != nil }
    }

    let id: Int
    let kind: Kind
    /// The large centered line.
    let title: String
    /// A quieter second line — what a rest phase is resting *from*, mostly.
    let detail: String?
    /// What gets said out loud.
    let spoken: String
    /// Reminders shown during the work. Never gates.
    let cues: [String]
    /// "Set 3 of 8", when the phase is part of a repeated block.
    let round: Round?

    struct Round: Equatable {
        let index: Int
        let total: Int
        var label: String { "Set \(index) of \(total)" }
    }
}

/// What to read before the clock starts: the cones to put out, and what the
/// movement should look like.
struct GetReady: Equatable {
    let setup: [String]
    let form: [String]

    var isEmpty: Bool { setup.isEmpty && form.isEmpty }
}

/// An exercise expanded into the screens the walkthrough will show.
struct Walkthrough: Equatable {
    let exercise: Exercise
    let getReady: GetReady
    let phases: [WalkPhase]

    /// Total clock time, ignoring self-paced phases.
    var timedSeconds: Int {
        phases.reduce(0) { $0 + ($1.kind.seconds ?? 0) }
    }

    init(exercise: Exercise) {
        self.exercise = exercise
        self.getReady = GetReady(
            setup: exercise.setupSteps.map(\.text),
            form: exercise.formSteps.map(\.text)
        )
        self.phases = Self.buildPhases(for: exercise)
    }

    // MARK: - Expansion

    private static func buildPhases(for exercise: Exercise) -> [WalkPhase] {
        var builder = Builder(exercise: exercise)
        builder.run()
        return builder.phases
    }

    private struct Builder {
        let exercise: Exercise
        let cuesByStep: [Int: [String]]
        var phases: [WalkPhase] = []
        private var nextID = 0

        init(exercise: Exercise) {
            self.exercise = exercise
            self.cuesByStep = Self.attachCues(in: exercise.steps)
        }

        /// A cue belongs to the next action step at or after it; if the exercise
        /// has run out of action steps, it belongs to the last one before it.
        /// "Keep your core tight" sits before the work; "Too easy? Lift one foot"
        /// sits after it. Both are about the same set.
        private static func attachCues(in steps: [Step]) -> [Int: [String]] {
            var map: [Int: [String]] = [:]
            for (index, step) in steps.enumerated() where step.role == .cue {
                let following = steps.indices[(index + 1)...].first { steps[$0].role == .action }
                let preceding = steps.indices[..<index].last { steps[$0].role == .action }
                if let owner = following ?? preceding {
                    map[owner, default: []].append(step.text)
                }
            }
            return map
        }

        mutating func run() {
            guard exercise.mode == .stepped else {
                appendOpenBlock()
                return
            }
            for index in exercise.steps.indices where exercise.steps[index].role == .action {
                append(stepAt: index)
            }
        }

        private mutating func appendOpenBlock() {
            let seconds = exercise.estimatedMinutes * 60
            let opening = exercise.actionSteps.first?.text ?? exercise.name
            phases.append(
                WalkPhase(
                    id: takeID(),
                    kind: .block(seconds: seconds),
                    title: exercise.name,
                    detail: "\(exercise.estimatedMinutes) minutes of practice",
                    spoken: "\(exercise.name). \(exercise.estimatedMinutes) minutes. \(opening)",
                    cues: exercise.steps.filter { $0.role == .cue }.map(\.text),
                    round: nil
                )
            )
        }

        /// Emits every phase a single action step is responsible for.
        ///
        /// `opensRound` is false for the second and later steps inside one round
        /// of a loop, which is what keeps the round label from being announced
        /// over and over within the same round.
        private mutating func append(
            stepAt index: Int,
            round: WalkPhase.Round? = nil,
            opensRound: Bool = true
        ) {
            let step = exercise.steps[index]
            let cues = cuesByStep[index] ?? []

            switch step.timing {
            case .none:
                emit(.selfPaced, step: step, cues: cues, round: round, opensRound: opensRound)

            case .work(let seconds):
                emit(.work(seconds: seconds), step: step, cues: cues, round: round, opensRound: opensRound)

            case .reps(let count, let each):
                emit(.reps(count: count, each: each), step: step, cues: cues, round: round, opensRound: opensRound)

            case .interval(let work, let reps, let each, let rest, let rounds):
                // Work and rest that both live inside this one step.
                let kind: WalkPhase.Kind = if let work {
                    .work(seconds: work)
                } else if let reps {
                    .reps(count: reps, each: each)
                } else {
                    .selfPaced
                }
                for round in 1...max(rounds, 1) {
                    let info = WalkPhase.Round(index: round, total: rounds)
                    emit(kind, step: step, cues: cues, round: rounds > 1 ? info : nil)
                    if round < rounds, rest > 0 {
                        emitRest(seconds: rest, detail: nil, round: info)
                    }
                }

            case .loop(let repeatFrom, let rounds, let rest, let restEvery):
                // The body already ran once inline, as the steps before this one.
                // This step is the rest phase plus the jump back.
                let body = bodyStepIndices(from: repeatFrom, before: index)
                guard rounds > 1, !body.isEmpty else {
                    if rest > 0 { emitRest(seconds: rest, detail: step.text, round: nil) }
                    return
                }
                for round in 2...rounds {
                    if (round - 1) % max(restEvery, 1) == 0 {
                        emitRest(
                            seconds: rest,
                            detail: step.text,
                            round: WalkPhase.Round(index: round - 1, total: rounds)
                        )
                    }
                    let info = WalkPhase.Round(index: round, total: rounds)
                    for (offset, bodyIndex) in body.enumerated() {
                        append(stepAt: bodyIndex, round: info, opensRound: offset == 0)
                    }
                }
            }
        }

        /// The action steps a loop repeats: `repeatFrom` is 1-based and inclusive,
        /// up to but not including the loop step itself. Nested loops are excluded
        /// — the content has none, and honouring one would not terminate.
        private func bodyStepIndices(from repeatFrom: Int, before index: Int) -> [Int] {
            let start = max(repeatFrom - 1, 0)
            guard start < index else { return [] }
            return (start..<index).filter {
                guard exercise.steps[$0].role == .action else { return false }
                if case .loop = exercise.steps[$0].timing { return false }
                return true
            }
        }

        private mutating func emit(
            _ kind: WalkPhase.Kind,
            step: Step,
            cues: [String],
            round: WalkPhase.Round?,
            opensRound: Bool = true
        ) {
            phases.append(
                WalkPhase(
                    id: takeID(),
                    kind: kind,
                    title: step.text,
                    detail: round?.label,
                    spoken: spokenText(for: kind, step: step, round: round, opensRound: opensRound),
                    cues: cues,
                    round: round
                )
            )
        }

        private mutating func emitRest(seconds: Int, detail: String?, round: WalkPhase.Round?) {
            phases.append(
                WalkPhase(
                    id: takeID(),
                    kind: .rest(seconds: seconds),
                    title: "Rest",
                    detail: detail,
                    spoken: "Rest. \(spokenDuration(seconds)).",
                    cues: [],
                    round: round
                )
            )
        }

        /// The first round says the whole step; later rounds are shortened,
        /// because he already knows what he is doing by then.
        ///
        /// Shortened, not dropped: this used to say only "Set 2 of 3. Go." for
        /// every step in the round, so a loop over two or three steps spoke the
        /// identical sentence several times in a row and there was no way to
        /// hear that the step had changed. The first sentence of the step is
        /// short enough to stay out of the way and still name the movement.
        private func spokenText(
            for kind: WalkPhase.Kind,
            step: Step,
            round: WalkPhase.Round?,
            opensRound: Bool
        ) -> String {
            guard let round, round.index > 1 else { return step.text }
            let reminder = Self.firstSentence(of: step.text)
            return opensRound ? "\(round.label). \(reminder)" : reminder
        }

        /// The opening sentence of a step, which the content writes as a short
        /// imperative: "Walk back slowly." out of "Walk back slowly. This is
        /// your rest." Falls back to the whole thing when the split would leave
        /// a fragment too short to mean anything.
        private static func firstSentence(of text: String) -> String {
            guard let end = text.rangeOfCharacter(from: CharacterSet(charactersIn: ".!?")) else {
                return text
            }
            let sentence = String(text[..<end.upperBound]).trimmingCharacters(in: .whitespaces)
            return sentence.split(separator: " ").count >= 3 ? sentence : text
        }

        private func spokenDuration(_ seconds: Int) -> String {
            if seconds >= 60, seconds % 60 == 0 {
                let minutes = seconds / 60
                return minutes == 1 ? "one minute" : "\(minutes) minutes"
            }
            return "\(seconds) seconds"
        }

        private mutating func takeID() -> Int {
            defer { nextID += 1 }
            return nextID
        }
    }
}
