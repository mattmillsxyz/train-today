import Foundation
import SwiftData

// MARK: - Persisted models

/// One exercise ticked off on one day. The pair `(dayKey, exerciseID)` is the
/// only history the app keeps, which is what lets the plan be regenerated freely
/// without disturbing what has already been done.
@Model
final class CompletionRecord {
    var dayKey: String = ""
    var exerciseID: String = ""
    var completedAt: Date = Date()

    init(dayKey: String, exerciseID: String, completedAt: Date = .now) {
        self.dayKey = dayKey
        self.exerciseID = exerciseID
        self.completedAt = completedAt
    }
}

/// A logged personal record. Every entry is kept, not just the best, so the
/// progress screen can draw the history the content keeps asking him to track.
@Model
final class PersonalRecord {
    var exerciseID: String = ""
    var value: Double = 0
    var recordedAt: Date = Date()

    init(exerciseID: String, value: Double, recordedAt: Date = .now) {
        self.exerciseID = exerciseID
        self.value = value
        self.recordedAt = recordedAt
    }
}

@Model
final class EarnedBadge {
    var badgeID: String = ""
    var earnedAt: Date = Date()

    init(badgeID: String, earnedAt: Date = .now) {
        self.badgeID = badgeID
        self.earnedAt = earnedAt
    }
}

// MARK: - Store

/// Reads everything into memory once and keeps it there.
///
/// The data is tiny — a handful of rows per training day — and every screen wants
/// cross-cutting views of it (streaks, heat maps, per-exercise history), which
/// `@Query` makes awkward. One observable snapshot is simpler and fast enough.
@Observable
final class TrainingStore {
    private let context: ModelContext

    private(set) var completions: [String: Set<String>] = [:]
    private(set) var records: [String: [PersonalRecord]] = [:]
    private(set) var earnedBadges: [String: Date] = [:]

    init(context: ModelContext) {
        self.context = context
        reload()
    }

    func reload() {
        completions = [:]
        for row in (try? context.fetch(FetchDescriptor<CompletionRecord>())) ?? [] {
            completions[row.dayKey, default: []].insert(row.exerciseID)
        }
        records = Dictionary(
            grouping: (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? [],
            by: \.exerciseID
        ).mapValues { $0.sorted { $0.recordedAt < $1.recordedAt } }
        earnedBadges = [:]
        for row in (try? context.fetch(FetchDescriptor<EarnedBadge>())) ?? [] {
            earnedBadges[row.badgeID] = row.earnedAt
        }
    }

    // MARK: Completions

    func isCompleted(dayKey: String, exerciseID: String) -> Bool {
        completions[dayKey]?.contains(exerciseID) ?? false
    }

    func completedCount(dayKey: String) -> Int {
        completions[dayKey]?.count ?? 0
    }

    /// Every day on which at least one exercise was completed.
    var trainedDayKeys: Set<String> {
        Set(completions.filter { !$0.value.isEmpty }.keys)
    }

    func setCompleted(_ completed: Bool, dayKey: String, exerciseID: String) {
        let existing = fetchCompletion(dayKey: dayKey, exerciseID: exerciseID)
        if completed {
            guard existing == nil else { return }
            context.insert(CompletionRecord(dayKey: dayKey, exerciseID: exerciseID))
            completions[dayKey, default: []].insert(exerciseID)
        } else {
            guard let existing else { return }
            context.delete(existing)
            completions[dayKey]?.remove(exerciseID)
        }
        save()
    }

    func toggleCompleted(dayKey: String, exerciseID: String) {
        setCompleted(!isCompleted(dayKey: dayKey, exerciseID: exerciseID),
                     dayKey: dayKey, exerciseID: exerciseID)
    }

    private func fetchCompletion(dayKey: String, exerciseID: String) -> CompletionRecord? {
        let descriptor = FetchDescriptor<CompletionRecord>(
            predicate: #Predicate { $0.dayKey == dayKey && $0.exerciseID == exerciseID }
        )
        return try? context.fetch(descriptor).first
    }

    // MARK: Personal records

    func history(for exerciseID: String) -> [PersonalRecord] {
        records[exerciseID] ?? []
    }

    /// The standing best, respecting whether higher or lower wins.
    func best(for exercise: Exercise) -> Double? {
        guard let metric = exercise.prMetric else { return nil }
        let values = history(for: exercise.id).map(\.value)
        return metric.higherIsBetter ? values.max() : values.min()
    }

    /// Logs a value and reports whether it beat the previous best.
    @discardableResult
    func logRecord(_ value: Double, for exercise: Exercise) -> Bool {
        let previous = best(for: exercise)
        let record = PersonalRecord(exerciseID: exercise.id, value: value)
        context.insert(record)
        records[exercise.id, default: []].append(record)
        save()

        guard let metric = exercise.prMetric else { return false }
        guard let previous else { return true }
        return metric.higherIsBetter ? value > previous : value < previous
    }

    var totalRecordsLogged: Int {
        records.values.reduce(0) { $0 + $1.count }
    }

    // MARK: Badges

    func hasBadge(_ id: String) -> Bool { earnedBadges[id] != nil }

    /// Awards any newly satisfied badges and returns just the new ones, so the
    /// caller can celebrate them.
    @discardableResult
    func award(_ ids: some Sequence<String>) -> [String] {
        var awarded: [String] = []
        for id in ids where !hasBadge(id) {
            let badge = EarnedBadge(badgeID: id)
            context.insert(badge)
            earnedBadges[id] = badge.earnedAt
            awarded.append(id)
        }
        if !awarded.isEmpty { save() }
        return awarded
    }

    // MARK: Reset

    /// Used by Settings' "start over". Wipes history; the caller resets settings.
    func deleteAllHistory() {
        for row in (try? context.fetch(FetchDescriptor<CompletionRecord>())) ?? [] { context.delete(row) }
        for row in (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? [] { context.delete(row) }
        for row in (try? context.fetch(FetchDescriptor<EarnedBadge>())) ?? [] { context.delete(row) }
        save()
        reload()
    }

    private func save() {
        try? context.save()
    }
}
