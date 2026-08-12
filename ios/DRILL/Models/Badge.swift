import Foundation

/// Twelve concrete, reachable badges. Nothing here needs a lucky streak or a
/// year of use to unlock — the first two are earned on day one.
struct Badge: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let detail: String
    let symbol: String

    static let all: [Badge] = [
        Badge(id: "firstWorkout", title: "First Session",
              detail: "Finish your first workout", symbol: "flag.checkered"),
        Badge(id: "firstExercise", title: "Getting Started",
              detail: "Tick off your first exercise", symbol: "checkmark.circle"),
        Badge(id: "streak3", title: "Three in a Row",
              detail: "Train 3 training days in a row", symbol: "3.circle"),
        Badge(id: "streak7", title: "Week Warrior",
              detail: "A 7-day streak", symbol: "flame"),
        Badge(id: "streak30", title: "Month Strong",
              detail: "A 30-day streak", symbol: "flame.fill"),
        Badge(id: "perfectWeek", title: "Perfect Week",
              detail: "Every training day in one week", symbol: "calendar.badge.checkmark"),
        Badge(id: "workouts10", title: "Ten Down",
              detail: "10 workouts finished", symbol: "10.circle"),
        Badge(id: "workouts50", title: "Fifty Deep",
              detail: "50 workouts finished", symbol: "50.circle"),
        Badge(id: "workouts100", title: "Century",
              detail: "100 workouts finished", symbol: "star.circle.fill"),
        Badge(id: "everySport", title: "All-Rounder",
              detail: "Train every sport you picked in one week", symbol: "figure.mixed.cardio"),
        Badge(id: "firstPR", title: "On the Board",
              detail: "Log your first personal record", symbol: "trophy"),
        Badge(id: "prs10", title: "Record Breaker",
              detail: "Log 10 personal records", symbol: "trophy.fill"),
    ]

    static func named(_ id: String) -> Badge? {
        all.first { $0.id == id }
    }
}
