import SwiftUI

/// Streak, headline numbers, badge shelf, personal records. The day-by-day
/// picture lives on the Calendar tab.
struct ProgressScreen: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(TrainingStore.self) private var store

    private var settings: PlanSettings { settingsStore.settings }

    var body: some View {
        let stats = ProgressCalculator(store: store, settings: settings).stats()

        ScrollView {
            VStack(spacing: 16) {
                streakCard(stats)
                statGrid(stats)
                badgeShelf
                recordsList
            }
            .appColumn()
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
        }
        .background(Theme.bg)
        .navigationTitle("Progress")
    }

    // MARK: - Streak

    private func streakCard(_ stats: ProgressStats) -> some View {
        VStack(spacing: 4) {
            Text("🔥").font(.system(size: 40))
            Text("\(stats.currentStreak)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text(stats.currentStreak == 1 ? "day streak" : "days in a row")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.7))
            Text("Rest days don't break it.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink.opacity(0.6))
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Theme.green, in: .rect(cornerRadius: Theme.cardRadius))
    }

    private func statGrid(_ stats: ProgressStats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statTile("Workouts finished", "\(stats.workoutsFinished)", "checkmark.seal")
            statTile("Days trained", "\(stats.daysTrained)", "calendar")
            statTile("Longest streak", "\(stats.longestStreak)", "flame")
            statTile("Records logged", "\(stats.recordsLogged)", "trophy")
        }
    }

    private func statTile(_ label: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.green)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: .rect(cornerRadius: 14))
    }

    // MARK: - Badges

    private var badgeShelf: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(text: "Badges · \(store.earnedBadges.count) of \(Badge.all.count)")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                ForEach(Badge.all) { badge in
                    BadgeTile(badge: badge, isEarned: store.hasBadge(badge.id))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 14))
    }

    // MARK: - Records

    private var recordsList: some View {
        let tracked = ExerciseLibrary.shared.all.filter { $0.prMetric != nil }
        let logged = tracked.filter { !store.history(for: $0.id).isEmpty }

        return VStack(alignment: .leading, spacing: 10) {
            SectionHeading(text: "Personal records")
            if logged.isEmpty {
                Text("Finish an exercise that tracks a record — juggling, broad jumps, cone dribbling — and log your number. This is where it lives.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(logged) { exercise in
                    RecordRow(exercise: exercise, history: store.history(for: exercise.id))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 14))
    }
}

// MARK: - Pieces

struct BadgeTile: View {
    let badge: Badge
    let isEarned: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: badge.symbol)
                .font(.system(size: 26))
                .foregroundStyle(isEarned ? Theme.green : Theme.textSecondary.opacity(0.4))
                .frame(height: 32)
            Text(badge.title)
                .font(.system(size: 12, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(isEarned ? Theme.text : Theme.textSecondary)
            Text(badge.detail)
                .font(.system(size: 10))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(isEarned ? Theme.greenLight : Theme.bg, in: .rect(cornerRadius: 12))
        .opacity(isEarned ? 1 : 0.55)
    }
}

/// One tracked metric with its best value and a sparkline of everything logged.
struct RecordRow: View {
    let exercise: Exercise
    let history: [PersonalRecord]

    var body: some View {
        let metric = exercise.prMetric
        let values = history.map(\.value)
        let best = metric?.higherIsBetter == false ? values.min() : values.max()

        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(metric?.label ?? exercise.name)
                    .font(.system(size: 15, weight: .semibold))
                Text(exercise.name)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Sparkline(values: values, higherIsBetter: metric?.higherIsBetter ?? true)
                .frame(width: 70, height: 24)
            Text(best.map { format($0, metric) } ?? "—")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.green)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    private func format(_ value: Double, _ metric: PRMetric?) -> String {
        let number = value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
        return number + (metric?.unit.suffix ?? "")
    }
}

struct Sparkline: View {
    let values: [Double]
    let higherIsBetter: Bool

    var body: some View {
        GeometryReader { geo in
            let points = normalized()
            if points.count > 1 {
                Path { path in
                    for (index, value) in points.enumerated() {
                        let x = geo.size.width * Double(index) / Double(points.count - 1)
                        let y = geo.size.height * (1 - value)
                        index == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(Theme.green, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            } else if let only = points.first {
                Circle()
                    .fill(Theme.green)
                    .frame(width: 5, height: 5)
                    .position(x: geo.size.width / 2, y: geo.size.height * (1 - only))
            }
        }
    }

    /// Scales to 0...1, flipping when a lower number is the better one.
    private func normalized() -> [Double] {
        guard let low = values.min(), let high = values.max() else { return [] }
        let span = high - low
        return values.map { value in
            let t = span == 0 ? 0.5 : (value - low) / span
            return higherIsBetter ? t : 1 - t
        }
    }
}

/// Shown when a badge is earned. Small, quick, and dismissible.
struct BadgeUnlockedSheet: View {
    let badges: [Badge]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text(badges.count == 1 ? "Badge unlocked!" : "\(badges.count) badges unlocked!")
                .font(.system(size: 26, weight: .bold))
            ForEach(badges) { badge in
                HStack(spacing: 14) {
                    Image(systemName: badge.symbol)
                        .font(.system(size: 30))
                        .foregroundStyle(Theme.green)
                        .frame(width: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(badge.title).font(.system(size: 17, weight: .bold))
                        Text(badge.detail).font(.system(size: 14)).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(Theme.greenLight, in: .rect(cornerRadius: 14))
            }
            Button("Nice") { dismiss() }
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.green, in: .capsule)
                .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Theme.bg)
        .presentationDetents([.medium])
    }
}
