import SwiftUI

/// The port of the web app's single screen: sticky green header, week strip,
/// progress bar, and a stack of expandable exercise cards.
struct TodayScreen: View {
    @Environment(AppState.self) private var app
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(TrainingStore.self) private var store

    @State private var expanded: Set<String> = []
    @State private var running: Exercise?
    @State private var newBadges: [Badge] = []

    private var settings: PlanSettings { settingsStore.settings }
    private var displayDate: Date { app.selectedDate }
    private var session: Session? { PlanGenerator.session(for: displayDate, settings: settings) }
    private var dayKey: String { TrainingCalendar.dayKey(displayDate) }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    if let session {
                        progressBar(for: session)
                        exerciseList(for: session)
                    } else {
                        restCard
                    }
                } header: {
                    header
                }
            }
            .appColumn()
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Theme.bg)
        .topSafeAreaCover()
        .fullScreenCover(item: $running) { exercise in
            WalkthroughScreen(exercise: exercise, dayKey: dayKey) { completed in
                if completed { complete(exercise) }
                running = nil
            }
        }
        .sheet(isPresented: .init(get: { !newBadges.isEmpty }, set: { if !$0 { newBadges = [] } })) {
            BadgeUnlockedSheet(badges: newBadges)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    navButton("chevron.left") { shiftDay(-1) }
                    Spacer()
                    VStack(spacing: 0) {
                        Text(displayDate, format: .dateTime.weekday(.wide).month(.wide).day())
                            .font(.system(size: 14))
                            .opacity(0.8)
                        if !app.isShowingToday {
                            Button("Jump to today") { withAnimation { app.jumpToToday() } }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .opacity(0.65)
                        }
                    }
                    Spacer()
                    navButton("chevron.right") { shiftDay(1) }
                }
                .padding(.bottom, 12)

                Text(session?.title ?? "Rest Day")
                    .font(.system(size: 24, weight: .bold))
                    .kerning(-0.3)

                if let session {
                    Text("\(session.exercises.count) activities · ~\(session.totalMinutes) min")
                        .font(.system(size: 15))
                        .opacity(0.8)
                        .padding(.top, 2)

                    if !session.sports.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(session.sports) { tag in
                                SportPill(text: tag.pillLabel)
                            }
                        }
                        .padding(.top, 10)
                    }
                }
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(Theme.green)
            .clipShape(UnevenRoundedRectangle(cornerRadii: .top(Theme.cardRadius)))
        }
        .padding(.top, 12)
        // The two-layer structure from the web app: the dark ground behind the
        // green card stops the exercise list showing through the rounded corners
        // as it scrolls under.
        .background(Theme.bg)
    }

    private func navButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 40)
                .background(.black.opacity(0.15), in: .circle)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Progress

    private func progressBar(for session: Session) -> some View {
        let done = doneCount(in: session)
        return VStack(spacing: 6) {
            HStack {
                Text("Progress")
                Spacer()
                Text("\(done) of \(session.exercises.count) done")
            }
            .font(.system(size: 14))
            .foregroundStyle(Theme.textSecondary)

            ThinProgressBar(fraction: Double(done) / Double(max(session.exercises.count, 1)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.card)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    // MARK: - Exercises

    private func exerciseList(for session: Session) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, exercise in
                ExerciseCard(
                    exercise: exercise,
                    isDone: store.isCompleted(dayKey: dayKey, exerciseID: exercise.id),
                    isExpanded: expanded.contains(exercise.id),
                    isLast: index == session.exercises.count - 1,
                    onToggleCheck: { toggle(exercise) },
                    onToggleExpand: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if expanded.contains(exercise.id) {
                                expanded.remove(exercise.id)
                            } else {
                                expanded.insert(exercise.id)
                            }
                        }
                    },
                    onStart: { running = exercise }
                )
            }
        }
    }

    private var restCard: some View {
        VStack(spacing: 6) {
            Text("😴").font(.system(size: 48)).padding(.bottom, 6)
            Text("Rest Day").font(.system(size: 20, weight: .bold))
            Text("No workout scheduled. Rest is when you actually get stronger, but a walk or a bike ride never hurts.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(Theme.card)
        .clipShape(UnevenRoundedRectangle(cornerRadii: .bottom(Theme.cardRadius)))
    }

    // MARK: - Actions

    private func shiftDay(_ delta: Int) {
        withAnimation { app.shiftDay(delta) }
    }

    private func doneCount(in session: Session) -> Int {
        session.exercises.count { store.isCompleted(dayKey: dayKey, exerciseID: $0.id) }
    }

    private func toggle(_ exercise: Exercise) {
        store.toggleCompleted(dayKey: dayKey, exerciseID: exercise.id)
        Haptics.tick()
        checkBadges()
    }

    private func complete(_ exercise: Exercise) {
        store.setCompleted(true, dayKey: dayKey, exerciseID: exercise.id)
        checkBadges()
    }

    private func checkBadges() {
        let calculator = ProgressCalculator(store: store, settings: settings)
        let awarded = store.award(calculator.eligibleBadges())
        let badges = awarded.compactMap(Badge.named)
        if !badges.isEmpty {
            newBadges = badges
            Haptics.success()
        }
    }
}

// MARK: - Exercise card

/// `.activity-item` — check circle, name, tag, duration, Start, and an
/// expandable step list.
private struct ExerciseCard: View {
    let exercise: Exercise
    let isDone: Bool
    let isExpanded: Bool
    let isLast: Bool
    let onToggleCheck: () -> Void
    let onToggleExpand: () -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggleCheck) {
                    ZStack {
                        Circle()
                            .strokeBorder(isDone ? Theme.green : Theme.border, lineWidth: 2)
                            .background(Circle().fill(isDone ? Theme.green : .clear))
                        if isDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 24, height: 24)
                    .padding(.top, 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isDone ? "Mark \(exercise.name) not done" : "Mark \(exercise.name) done")

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isDone ? Theme.textSecondary : Theme.text)
                        .strikethrough(isDone)
                    TagLabel(tag: exercise.tag)
                    Text(exercise.displayDuration)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)

                    Button(action: onStart) {
                        Label("Start", systemImage: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 6)
                            .background(Theme.green, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(.rect)
            .onTapGesture(perform: onToggleExpand)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeading(text: "How to do it:")
                    NumberedSteps(steps: exercise.steps.map(\.text))
                }
                .padding(.leading, 56)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Theme.card)
        .overlay(alignment: .bottom) {
            if !isLast { Rectangle().fill(Theme.border).frame(height: 1) }
        }
        .clipShape(UnevenRoundedRectangle(cornerRadii: isLast ? .bottom(Theme.cardRadius) : .init()))
    }
}
