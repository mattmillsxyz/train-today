import Foundation

/// Everything the plan generator and the reminder scheduler need.
///
/// The web app hardcoded a 10-week rotation for one athlete. This replaces it:
/// the athlete picks sports, which days they train and how long a session runs,
/// and the generator composes each day from that.
struct PlanSettings: Codable, Equatable, Sendable {
    /// Weekday indices used throughout the app: Monday == 0 … Sunday == 6.
    /// The web app's `weekPatterns` rows were Mon-Sun, and so is this.
    typealias Weekday = Int

    var athleteName: String
    /// Chosen in onboarding. Never contains `warmup` or `stretch` — the
    /// generator always bookends a session with those.
    var sports: Set<Tag>
    /// Which weekdays are training days. Days not in this set are rest days,
    /// and the streak rule below treats them as such rather than as misses.
    var trainingDays: Set<Weekday>
    var sessionMinutes: Int
    /// Fixed at onboarding. Changing sports or days changes future sessions;
    /// this keeps the *shuffle* stable so nothing reshuffles underfoot.
    var seed: UInt64
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var hasOnboarded: Bool

    static let sessionLengthOptions = [30, 45, 60, 75]

    static let `default` = PlanSettings(
        athleteName: "",
        sports: [.soccer, .strength, .cardio],
        trainingDays: [0, 1, 2, 3, 4],
        sessionMinutes: 45,
        seed: UInt64.random(in: 1...UInt64.max),
        reminderEnabled: false,
        reminderHour: 16,
        reminderMinute: 0,
        hasOnboarded: false
    )

    /// A settings value good enough to render previews and the first-week
    /// preview during onboarding, before anything has been saved.
    static let preview = PlanSettings(
        athleteName: "Alex",
        sports: [.soccer, .strength, .cardio, .plyo],
        trainingDays: [0, 1, 2, 3, 4],
        sessionMinutes: 45,
        seed: 20_250_616,
        reminderEnabled: true,
        reminderHour: 16,
        reminderMinute: 0,
        hasOnboarded: true
    )

    var daysPerWeek: Int { trainingDays.count }

    func isTrainingDay(_ weekday: Weekday) -> Bool { trainingDays.contains(weekday) }

    var reminderTimeComponents: DateComponents {
        DateComponents(hour: reminderHour, minute: reminderMinute)
    }
}

/// Monday-first weekday labels, matching the app's `Weekday` indexing.
enum Weekdays {
    static let names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    static let initials = ["M", "T", "W", "T", "F", "S", "S"]
}
