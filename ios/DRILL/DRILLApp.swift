import SwiftData
import SwiftUI

@main
struct DRILLApp: App {
    @State private var appState = AppState()
    @State private var settingsStore = SettingsStore()
    @State private var trainingStore: TrainingStore
    private let container: ModelContainer

    init() {
        let container = Self.makeContainer()
        self.container = container
        _trainingStore = State(initialValue: TrainingStore(context: ModelContext(container)))
        FeatureToggles.restore()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(settingsStore)
                .environment(trainingStore)
                .modelContainer(container)
                .tint(Theme.green)
        }
    }

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([CompletionRecord.self, PersonalRecord.self, EarnedBadge.self])
        do {
            return try ModelContainer(for: schema)
        } catch {
            // A corrupt store should not be a permanently broken app. Fall back
            // to memory so he can still train today; history reappears if the
            // on-disk store recovers.
            return try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
    }
}

struct RootView: View {
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        if settingsStore.settings.hasOnboarded {
            MainTabs()
        } else {
            OnboardingFlow()
        }
    }
}

struct MainTabs: View {
    @Environment(AppState.self) private var app
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        @Bindable var app = app

        TabView(selection: $app.tab) {
            TodayScreen()
                .tabItem { Label("Today", systemImage: "figure.run") }
                .tag(AppState.Tab.today)

            NavigationStack { CalendarScreen() }
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(AppState.Tab.calendar)

            NavigationStack { ProgressScreen() }
                .tabItem { Label("Progress", systemImage: "flame") }
                .tag(AppState.Tab.progress)

            NavigationStack { SettingsScreen() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppState.Tab.settings)
        }
        .task {
            // Keep the scheduled triggers honest with the current settings on
            // every launch — the plan can change on another device restore, and
            // stale reminders are worse than none.
            await NotificationService.shared.refreshAuthorization()
            await NotificationService.shared.reschedule(for: settingsStore.settings)
        }
    }
}
