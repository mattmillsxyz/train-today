import Foundation
import UserNotifications

/// Local reminders. No backend, no server, no push certificates — one repeating
/// calendar trigger per selected weekday, so at most seven pending requests
/// against iOS's limit of 64.
@Observable
final class NotificationService {
    static let shared = NotificationService()

    /// Mirrors the system setting so Settings can show the real state rather
    /// than what the app last asked for.
    private(set) var authorization: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private let identifierPrefix = "trainToday.reminder."

    private init() {}

    func refreshAuthorization() async {
        authorization = await center.notificationSettings().authorizationStatus
    }

    /// Asks for permission. Called from the reminder step of onboarding and from
    /// Settings — never on launch, so the prompt always has visible context.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthorization()
        return granted
    }

    /// Replaces every scheduled reminder with the ones `settings` describes.
    /// Always clears first, so turning days off actually removes their triggers.
    func reschedule(for settings: PlanSettings) async {
        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        guard settings.reminderEnabled else { return }
        await refreshAuthorization()
        guard authorization == .authorized || authorization == .provisional else { return }

        for weekday in settings.trainingDays.sorted() {
            let content = UNMutableNotificationContent()
            content.title = "DRILL"
            content.body = body(for: settings)
            content.sound = .default

            // UNCalendarNotificationTrigger counts Sunday as 1; the app counts
            // Monday as 0.
            var components = DateComponents()
            components.weekday = (weekday + 1) % 7 + 1
            components.hour = settings.reminderHour
            components.minute = settings.reminderMinute

            let request = UNNotificationRequest(
                identifier: "\(identifierPrefix)\(weekday)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
            try? await center.add(request)
        }
    }

    /// Useful when verifying delivery on a real device.
    func pendingReminderCount() async -> Int {
        await center.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(identifierPrefix) }
            .count
    }

    private func body(for settings: PlanSettings) -> String {
        let name = settings.athleteName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty
            ? "Today's workout is ready. Let's go!"
            : "\(name), today's workout is ready. Let's go!"
    }
}
