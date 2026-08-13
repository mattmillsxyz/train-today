import Foundation

/// Composes a day's session from `PlanSettings`, replacing the web app's
/// hardcoded 10-week `weekPatterns` / `dayWorkouts` tables.
///
/// The shape those tables used already worked, so it is the shape kept here:
/// **warmup → main drills weighted to the chosen sports → a strength/plyo
/// finisher → cooldown**. Every one of the old entries followed exactly that.
///
/// Two properties matter and both are tested:
///
/// - **Deterministic.** Every draw comes from a seeded PRNG over
///   `(seed, weekIndex, weekday)`, so the same inputs always produce the same
///   session. Nothing reshuffles when the app is reopened mid-workout.
/// - **Regenerates cleanly.** Changing sports or days changes future sessions
///   only; completed history is keyed by `(dayKey, exerciseID)` and unaffected.
///
/// The no-repeats-on-consecutive-days rule is scoped to a single week: the first
/// training day of a week has no preceding context. Carrying context across the
/// week boundary would mean generating week *W-1* to generate week *W*, and so
/// on back to the epoch. Within-week is the version that terminates, and the
/// rule is a quality heuristic rather than a correctness one.
enum PlanGenerator {
    /// The seven days of the week containing `date`, Monday first. `nil` marks a
    /// rest day.
    static func week(containing date: Date, settings: PlanSettings) -> [Session?] {
        let monday = TrainingCalendar.monday(of: date)
        let weekIndex = TrainingCalendar.weekIndex(of: date)
        let library = ExerciseLibrary.shared

        let sports = settings.sports.sorted()
        let trainingDays = settings.trainingDays.sorted()
        guard !sports.isEmpty, !trainingDays.isEmpty else { return Array(repeating: nil, count: 7) }

        var out = [Session?](repeating: nil, count: 7)
        var previousIDs: Set<String> = []

        for (ordinal, weekday) in trainingDays.enumerated() {
            var rng = SeededGenerator(
                mixing: settings.seed, UInt64(bitPattern: Int64(weekIndex)), UInt64(weekday)
            )
            // Rotating by both the day's position in the week and the week
            // number keeps sports spread out rather than clustered, and stops
            // the same sport owning the same weekday forever.
            let focus = sports[floorMod(ordinal + weekIndex, sports.count)]
            let secondary = sports.count > 1
                ? sports[floorMod(ordinal + weekIndex + 1, sports.count)]
                : nil

            let session = compose(
                date: TrainingCalendar.adding(days: weekday, to: monday),
                focus: focus,
                secondary: secondary,
                avoiding: previousIDs,
                settings: settings,
                library: library,
                rng: &rng
            )
            previousIDs = Set(session.mainExercises.map(\.id))
            out[weekday] = session
        }
        return out
    }

    /// The session for a single date, or `nil` if it is a rest day.
    static func session(for date: Date, settings: PlanSettings) -> Session? {
        week(containing: date, settings: settings)[TrainingCalendar.weekday(date)]
    }

    // MARK: - Composition

    private static func compose(
        date: Date,
        focus: Tag,
        secondary: Tag?,
        avoiding avoid: Set<String>,
        settings: PlanSettings,
        library: ExerciseLibrary,
        rng: inout SeededGenerator
    ) -> Session {
        let warmup = library.exercises(tagged: .warmup).first
        let cooldown = pick(
            from: library.exercises(tagged: .stretch), avoiding: avoid, count: 1, rng: &rng
        ).first

        let bookendMinutes = (warmup?.estimatedMinutes ?? 0) + (cooldown?.estimatedMinutes ?? 0)
        let budget = max(settings.sessionMinutes - bookendMinutes, 0)

        let secondaryTag = secondary == focus ? nil : secondary
        let secondaryPool = secondaryTag.map { library.exercises(tagged: $0) } ?? []
        let finisherTags = Set(Tag.finishers).intersection(settings.sports).subtracting([focus])
        let finisherPool = library.exercises(taggedAnyOf: finisherTags)

        // Reserve room for the mixed-sport drill and the finisher *before*
        // spending anything on the focus sport. Without this, one long drill —
        // a 20-minute bike ride — eats the whole budget and the day comes out
        // single-sport with nothing to close it.
        let secondaryReserve = secondaryPool.map(\.estimatedMinutes).min() ?? 0
        let finisherReserve = finisherPool.map(\.estimatedMinutes).min() ?? 0

        var mains: [Exercise] = []
        var spent = 0

        /// Adds an exercise if it is new and still fits under `cap`.
        @discardableResult
        func add(_ exercise: Exercise?, cap: Int) -> Bool {
            guard let exercise, !mains.contains(where: { $0.id == exercise.id }) else { return false }
            guard spent + exercise.estimatedMinutes <= cap else { return false }
            mains.append(exercise)
            spent += exercise.estimatedMinutes
            return true
        }

        /// Walks a shuffled pool and takes the first entry that fits.
        func addFirstThatFits(from pool: [Exercise], cap: Int) {
            for candidate in pick(from: pool, avoiding: avoid, count: pool.count, rng: &rng)
            where add(candidate, cap: cap) {
                return
            }
        }

        // 1. The day's focus sport carries the session.
        let focusPool = library.exercises(tagged: focus)
        for exercise in pick(from: focusPool, avoiding: avoid, count: 3, rng: &rng) {
            add(exercise, cap: max(budget - secondaryReserve - finisherReserve, 0))
        }

        // 2. One drill from the next sport in the rotation, so days are mixed.
        if !secondaryPool.isEmpty {
            addFirstThatFits(from: secondaryPool, cap: budget - finisherReserve)
        }

        // 3. Anything still left goes on more of the day's own sports.
        if mains.count < 4 {
            let fillTags = Set([focus, secondaryTag].compactMap { $0 })
            for exercise in pick(from: library.exercises(taggedAnyOf: fillTags), avoiding: avoid, count: 4, rng: &rng)
            where mains.count < 4 {
                add(exercise, cap: budget - finisherReserve)
            }
        }

        // 4. A strength or plyo finisher closes the session, as every
        //    hand-written entry did — unless the day already *is* strength or plyo.
        if !finisherPool.isEmpty {
            addFirstThatFits(from: finisherPool, cap: budget)
        }

        // A session with no drills is not a session. Overshoot the budget rather
        // than hand him a warmup and a stretch.
        if mains.isEmpty, let fallback = pick(from: library.exercises(tagged: focus), avoiding: [], count: 1, rng: &rng).first {
            mains.append(fallback)
            spent += fallback.estimatedMinutes
        }

        var exercises: [Exercise] = []
        if let warmup { exercises.append(warmup) }
        exercises.append(contentsOf: mains)
        if let cooldown { exercises.append(cooldown) }

        var sports: [Tag] = []
        for exercise in mains where !sports.contains(exercise.tag) { sports.append(exercise.tag) }

        return Session(
            date: date,
            title: title(for: focus, rng: &rng),
            sports: sports,
            exercises: exercises
        )
    }

    /// Shuffles `pool` deterministically and returns up to `count` entries,
    /// dropping anything used on the previous training day.
    ///
    /// Dropping rather than de-prioritising matters: it means a tight budget can
    /// never quietly reintroduce yesterday's drill because it was the only one
    /// cheap enough to fit. Callers that would rather have *something* than
    /// nothing pass an empty `avoid`.
    private static func pick(
        from pool: [Exercise],
        avoiding avoid: Set<String>,
        count: Int,
        rng: inout SeededGenerator
    ) -> [Exercise] {
        guard !pool.isEmpty else { return [] }
        return Array(
            pool.shuffled(using: &rng)
                .filter { !avoid.contains($0.id) }
                .prefix(count)
        )
    }

    /// The titles the web app's `dayWorkouts` used, grouped by focus sport.
    private static func title(for focus: Tag, rng: inout SeededGenerator) -> String {
        let titles: [String]
        switch focus {
        case .soccer:
            titles = ["Soccer Skills", "Soccer Focus", "Ball Control Day", "Shooting Day",
                      "Dribbling & Passing", "Full Soccer Session"]
        case .football:
            titles = ["Football Day", "Football Agility"]
        case .track:
            titles = ["Track & Speed", "Speed & Form"]
        case .cardio:
            titles = ["Cardio Day", "Cardio Blast", "Endurance Day", "Speed Day"]
        case .strength:
            titles = ["Strength Day", "Strength Circuit", "Power Strength",
                      "Full Body Strength", "Strength & Core"]
        case .plyo:
            titles = ["Plyometrics Day", "Explosive Power", "Jump Training"]
        case .balance:
            titles = ["Balance & Agility"]
        case .warmup, .stretch:
            titles = ["Training Day"]
        }
        return titles.randomElement(using: &rng) ?? "Training Day"
    }
}
