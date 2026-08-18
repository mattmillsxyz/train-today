import SwiftUI
import UserNotifications

struct SettingsScreen: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(TrainingStore.self) private var store

    @State private var showResetConfirmation = false
    @State private var showLibrary = false
    @State private var notificationStatus: UNAuthorizationStatusMirror = .notDetermined

    var body: some View {
        @Bindable var settingsStore = settingsStore

        Form {
            Section("Athlete") {
                TextField("Name", text: $settingsStore.settings.athleteName)
                    .autocorrectionDisabled()
            }

            Section {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Tag.selectable) { tag in
                        SportChoiceCard(tag: tag, isSelected: settingsStore.settings.sports.contains(tag)) {
                            toggleSport(tag)
                        }
                    }
                }
                .padding(.vertical, 6)
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            } header: {
                Text("Sports")
            } footer: {
                Text("Changing these changes future sessions. Everything you've already finished stays put.")
            }

            Section("Schedule") {
                WeekdayPicker(selection: $settingsStore.settings.trainingDays)
                    .padding(.vertical, 4)
                Picker("Session length", selection: $settingsStore.settings.sessionMinutes) {
                    ForEach(PlanSettings.sessionLengthOptions, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
            }

            Section {
                Toggle("Daily reminder", isOn: $settingsStore.settings.reminderEnabled)
                    .tint(Theme.green)
                if settingsStore.settings.reminderEnabled {
                    DatePicker(
                        "Time",
                        selection: reminderTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text(reminderFooter)
            }

            Section {
                Toggle("Speak each step", isOn: speechBinding)
                    .tint(Theme.green)
                Toggle("Sounds", isOn: soundBinding)
                    .tint(Theme.green)
                Toggle("Haptics", isOn: hapticsBinding)
                    .tint(Theme.green)
            } header: {
                Text("During a workout")
            } footer: {
                Text("Spoken steps are what let him put the phone down mid-drill.")
            }

            Section("Exercise library") {
                Button("Browse all \(ExerciseLibrary.shared.all.count) exercises") { showLibrary = true }
            }

            Section {
                Button("Re-run setup") {
                    settingsStore.settings.hasOnboarded = false
                }
                Button("Delete all progress", role: .destructive) {
                    showResetConfirmation = true
                }
            } header: {
                Text("Start over")
            } footer: {
                Text("DRILL keeps everything on this phone. There is no account, no tracking, and nothing is ever uploaded.")
            }

            aboutSection
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showLibrary) { LibraryScreen() }
        .confirmationDialog(
            "Delete every completed workout, record and badge?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete everything", role: .destructive) { store.deleteAllHistory() }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: settingsStore.settings.reminderEnabled) { _, enabled in
            Task {
                if enabled { await NotificationService.shared.requestAuthorization() }
                await reschedule()
            }
        }
        .onChange(of: settingsStore.settings.trainingDays) { _, _ in Task { await reschedule() } }
        .onChange(of: settingsStore.settings.reminderHour) { _, _ in Task { await reschedule() } }
        .onChange(of: settingsStore.settings.reminderMinute) { _, _ in Task { await reschedule() } }
        .task {
            await NotificationService.shared.refreshAuthorization()
            notificationStatus = .init(NotificationService.shared.authorization)
        }
    }

    // MARK: - Bindings

    private var reminderTimeBinding: Binding<Date> {
        let store = settingsStore
        return Binding(
            get: {
                TrainingCalendar.calendar.date(
                    from: DateComponents(
                        hour: store.settings.reminderHour,
                        minute: store.settings.reminderMinute
                    )
                ) ?? .now
            },
            set: {
                let c = TrainingCalendar.calendar.dateComponents([.hour, .minute], from: $0)
                store.settings.reminderHour = c.hour ?? 16
                store.settings.reminderMinute = c.minute ?? 0
            }
        )
    }

    private var speechBinding: Binding<Bool> {
        Binding(
            get: { SpeechService.shared.isEnabled },
            set: {
                SpeechService.shared.isEnabled = $0
                UserDefaults.standard.set($0, forKey: FeatureToggles.speech)
            }
        )
    }

    private var soundBinding: Binding<Bool> {
        Binding(
            get: { SoundService.shared.isEnabled },
            set: {
                SoundService.shared.isEnabled = $0
                UserDefaults.standard.set($0, forKey: FeatureToggles.sound)
            }
        )
    }

    private var hapticsBinding: Binding<Bool> {
        Binding(
            get: { Haptics.isEnabled },
            set: {
                Haptics.isEnabled = $0
                UserDefaults.standard.set($0, forKey: FeatureToggles.haptics)
            }
        )
    }

    private var reminderFooter: String {
        guard settingsStore.settings.reminderEnabled else {
            return "One local notification per training day. Nothing leaves the phone."
        }
        if notificationStatus == .denied {
            return "Notifications are turned off for DRILL in the iOS Settings app. Reminders won't appear until they're turned back on."
        }
        let days = settingsStore.settings.trainingDays.sorted().map { Weekdays.names[$0] }
        return days.isEmpty ? "Pick some training days first." : "Reminding you on \(days.joined(separator: ", "))."
    }

    /// Version, and the one way out of the app.
    ///
    /// `Link` hands the URL to Safari; the app itself still makes no network
    /// request of its own, so "Data Not Collected" stays true.
    private var aboutSection: some View {
        Section {
            Link(destination: Self.siteURL) {
                Label("Help and support", systemImage: "questionmark.circle")
            }
        } header: {
            Text("About")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("DRILL \(Self.versionString)")
                    Spacer()
                    Text("© 2026 Matthew Mills")
                }
                Text("trainwithdrill.com")
            }
            // Otherwise the last line sits right on top of the tab bar.
            .padding(.bottom, 28)
        }
    }

    /// The same support page the App Store listing points at.
    private static let siteURL = URL(string: "https://trainwithdrill.com/support")!

    /// Reads the bundle rather than hardcoding, so the build number in Settings
    /// always matches whatever TestFlight is showing.
    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }

    private func toggleSport(_ tag: Tag) {
        if settingsStore.settings.sports.contains(tag) {
            if settingsStore.settings.sports.count > 1 { settingsStore.settings.sports.remove(tag) }
        } else {
            settingsStore.settings.sports.insert(tag)
        }
        Haptics.tick()
    }

    private func reschedule() async {
        await NotificationService.shared.reschedule(for: settingsStore.settings)
        await NotificationService.shared.refreshAuthorization()
        notificationStatus = .init(NotificationService.shared.authorization)
    }
}

/// `UserDefaults` keys for the three during-a-workout toggles. They live outside
/// `PlanSettings` because they are device preferences, not part of the plan.
enum FeatureToggles {
    static let speech = "trainToday.speech"
    static let sound = "trainToday.sound"
    static let haptics = "trainToday.haptics"

    static func restore() {
        let defaults = UserDefaults.standard
        SpeechService.shared.isEnabled = defaults.object(forKey: speech) as? Bool ?? true
        SoundService.shared.isEnabled = defaults.object(forKey: sound) as? Bool ?? true
        Haptics.isEnabled = defaults.object(forKey: haptics) as? Bool ?? true
    }
}

/// A tiny, `Equatable` stand-in so the view can compare authorization state
/// without matching every case `UNAuthorizationStatus` might grow.
enum UNAuthorizationStatusMirror {
    case notDetermined, denied, authorized

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .denied: self = .denied
        case .authorized, .provisional, .ephemeral: self = .authorized
        default: self = .notDetermined
        }
    }
}
