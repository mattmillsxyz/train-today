import SwiftUI

/// Welcome → name → sports → schedule → safety → reminders → first-week preview.
///
/// The notification prompt fires on the reminder page, in context, never on
/// launch — a permission dialog with nothing behind it is the fastest way to a
/// permanent "Don't Allow".
struct OnboardingFlow: View {
    @Environment(SettingsStore.self) private var settingsStore

    @State private var page = 0
    @State private var draft = PlanSettings.default
    @State private var notificationDenied = false
    /// The name field is the only keyboard in the flow. It has to give the
    /// keyboard back on the way out, or it covers the sports grid on the very
    /// next page with no obvious way to close it.
    @FocusState private var nameFocused: Bool
    /// Measured from the floating footer, so page content can be padded clear
    /// of it. Seeded with roughly the real height to avoid a first-layout jump.
    @State private var footerHeight: CGFloat = 84

    private let pageCount = 6

    var body: some View {
        VStack(spacing: 0) {
            // The welcome page is full-bleed and carries its own button, so the
            // shared chrome steps out of its way.
            if !isWelcome {
                progressDots
            }

            TabView(selection: $page) {
                WelcomePage(onContinue: { page = 1 }).tag(0)
                namePage.tag(1)
                sportsPage.tag(2)
                schedulePage.tag(3)
                remindersPage.tag(4)
                previewPage.tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)
            // An overlay rather than a sibling or a safe-area inset. Both of
            // those shrink the pages, and content then stops dead against the
            // controls instead of passing under them. An overlay leaves the
            // pages full height; `page()` pads its content by the measured
            // height so nothing ends up stranded underneath.
            .overlay(alignment: .bottom) {
                if !isWelcome {
                    footer.background {
                        GeometryReader { proxy in
                            Color.clear
                                .onAppear { footerHeight = proxy.size.height }
                                .onChange(of: proxy.size.height) { _, height in
                                    footerHeight = height
                                }
                        }
                    }
                }
            }
        }
        .background(isWelcome ? Theme.ink : Theme.bg)
        // Covers every way off the name page: Next, Back, and a swipe.
        .onChange(of: page) { _, _ in nameFocused = false }
        .task { draft.seed = UInt64.random(in: 1...UInt64.max) }
    }

    private var isWelcome: Bool { page == 0 }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index <= page ? Theme.green : Theme.border)
                    .frame(width: index == page ? 20 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: page)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Pages

    private var namePage: some View {
        page(title: "Who's training?", subtitle: "Just a first name. It's only used to say hello.") {
            TextField("Name", text: $draft.athleteName)
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .semibold))
                .padding(16)
                .background(Theme.card, in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.border))
                .autocorrectionDisabled()
                .textContentType(.givenName)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit { nameFocused = false }
        }
    }

    private var sportsPage: some View {
        page(title: "Pick your sports", subtitle: "Sessions get weighted toward these. Change them any time.") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Tag.selectable) { tag in
                    SportChoiceCard(tag: tag, isSelected: draft.sports.contains(tag)) {
                        if draft.sports.contains(tag) {
                            // Keep at least one — an empty plan generates nothing.
                            if draft.sports.count > 1 { draft.sports.remove(tag) }
                        } else {
                            draft.sports.insert(tag)
                        }
                        Haptics.tick()
                    }
                }
            }
        }
    }

    private var schedulePage: some View {
        page(title: "When do you train?", subtitle: "Days you don't pick are rest days, and they never break your streak.") {
            VStack(alignment: .leading, spacing: 24) {
                WeekdayPicker(selection: $draft.trainingDays)

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeading(text: "How long is a session?")
                    Picker("Session length", selection: $draft.sessionMinutes) {
                        ForEach(PlanSettings.sessionLengthOptions, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                SafetyNote()
            }
        }
    }

    private var remindersPage: some View {
        page(title: "Want a nudge?", subtitle: "A reminder on each training day. No account, nothing sent anywhere.") {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Remind me to train", isOn: $draft.reminderEnabled)
                    .font(.system(size: 17, weight: .semibold))
                    .tint(Theme.green)

                if draft.reminderEnabled {
                    DatePicker(
                        "Time",
                        selection: Binding(
                            get: {
                                TrainingCalendar.calendar.date(
                                    from: DateComponents(hour: draft.reminderHour, minute: draft.reminderMinute)
                                ) ?? .now
                            },
                            set: {
                                let c = TrainingCalendar.calendar.dateComponents([.hour, .minute], from: $0)
                                draft.reminderHour = c.hour ?? 16
                                draft.reminderMinute = c.minute ?? 0
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .font(.system(size: 17, weight: .semibold))

                    Text(remindersSummary)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                }

                if notificationDenied {
                    Text("Notifications are turned off for DRILL. You can switch them on in the iOS Settings app whenever you like, and everything else works without them.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: .rect(cornerRadius: 14))
        }
    }

    private var previewPage: some View {
        page(title: "Your first week", subtitle: "This is what the plan looks like. It refreshes every week.") {
            WeekPreview(settings: draft)
        }
    }

    // MARK: - Chrome

    private func page(title: String, subtitle: String, @ViewBuilder content: () -> some View) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 30, weight: .bold))
                        .kerning(-0.5)
                    Text(subtitle)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textSecondary)
                }
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appColumn()
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, footerHeight + 12)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// Floats over the page rather than sitting on a bar of its own, so the
    /// background stays transparent and content passes underneath. Both
    /// controls therefore carry their own solid shape — "Back" was bare text,
    /// which is unreadable over a scrolling list.
    ///
    /// Padding lives inside each label so the whole capsule is the hit target,
    /// not just the glyphs.
    private var footer: some View {
        HStack {
            if page > 0 {
                Button { page -= 1 } label: {
                    Text("Back")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(Theme.card, in: .capsule)
                        .overlay(Capsule().strokeBorder(Theme.border))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button {
                Task { await next() }
            } label: {
                Text(page == pageCount - 1 ? "Start training" : "Next")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Theme.green, in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(nextDisabled)
            .opacity(nextDisabled ? 0.4 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .appColumn()
    }

    private var nextDisabled: Bool {
        switch page {
        case 2: draft.sports.isEmpty
        case 3: draft.trainingDays.isEmpty
        default: false
        }
    }

    private var remindersSummary: String {
        let days = draft.trainingDays.sorted().map { Weekdays.names[$0] }.joined(separator: ", ")
        return days.isEmpty ? "Pick some training days first." : "You'll be reminded on \(days)."
    }

    private func next() async {
        // Before anything awaits, so the keyboard starts leaving the moment the
        // button is hit rather than after the page has already slid across.
        nameFocused = false
        if page == 4, draft.reminderEnabled {
            let granted = await NotificationService.shared.requestAuthorization()
            notificationDenied = !granted
            if !granted { draft.reminderEnabled = false }
        }
        guard page < pageCount - 1 else { return finish() }
        page += 1
    }

    private func finish() {
        draft.hasOnboarded = true
        settingsStore.settings = draft
        let settings = draft
        Task { await NotificationService.shared.reschedule(for: settings) }
    }
}

// MARK: - Pieces

/// A large tappable sport card, using the emoji set the web app already had.
struct SportChoiceCard: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(tag.emoji).font(.system(size: 34))
                Text(tag.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(isSelected ? Theme.greenLight : Theme.card, in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Theme.green : Theme.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Day-of-week chips, styled off the web app's `.week-strip` day cells.
struct WeekdayPicker: View {
    @Binding var selection: Set<PlanSettings.Weekday>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(text: "Training days")
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { day in
                    let isOn = selection.contains(day)
                    Button {
                        if isOn { selection.remove(day) } else { selection.insert(day) }
                        Haptics.tick()
                    } label: {
                        Text(Weekdays.initials[day])
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(isOn ? Theme.ink : Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(isOn ? Theme.green : Theme.card, in: .rect(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isOn ? .clear : Theme.border))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Weekdays.names[day])
                }
            }
        }
    }
}

/// Guideline 1.4.1, and just sensible for an 8-12 audience.
struct SafetyNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 18))
                .foregroundStyle(Theme.green)
            Text("Check with a parent before starting a new training plan. Warm up first, drink water, and stop if something hurts.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .background(Theme.card, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.border))
    }
}

/// The generated week, so onboarding ends on something concrete.
struct WeekPreview: View {
    let settings: PlanSettings

    var body: some View {
        let week = PlanGenerator.week(containing: .now, settings: settings)
        VStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { day in
                HStack(alignment: .top, spacing: 12) {
                    Text(Weekdays.names[day])
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 40, alignment: .leading)

                    if let session = week[day] {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.title)
                                .font(.system(size: 16, weight: .semibold))
                            Text(session.exercises.map(\.name).joined(separator: " · "))
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(session.totalMinutes)m")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text("Rest")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14)
                .overlay(alignment: .bottom) {
                    if day < 6 { Rectangle().fill(Theme.border).frame(height: 1) }
                }
            }
        }
        .background(Theme.card, in: .rect(cornerRadius: 16))
    }
}
