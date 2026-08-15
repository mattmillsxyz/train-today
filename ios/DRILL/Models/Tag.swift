import SwiftUI

/// The eleven content categories used by `exercises.json`.
///
/// Nine of them are pickable sports in onboarding; `warmup` and `stretch` are
/// structural — the generator always bookends a session with them, so they are
/// never offered as a choice.
enum Tag: String, Codable, CaseIterable, Identifiable, Hashable, Comparable {
    case warmup
    case soccer
    case football
    case basketball
    case baseball
    case cardio
    case plyo
    case strength
    case balance
    case track
    case stretch

    var id: String { rawValue }

    /// The tags a user can choose in onboarding.
    static let selectable: [Tag] = [
        .soccer, .football, .basketball, .baseball, .track, .cardio, .strength, .plyo, .balance,
    ]

    /// Tags whose exercises can close out a session.
    static let finishers: [Tag] = [.strength, .plyo]

    var displayName: String {
        switch self {
        case .warmup: "Warmup"
        case .soccer: "Soccer"
        case .football: "Football"
        case .basketball: "Basketball"
        case .baseball: "Baseball"
        case .cardio: "Cardio"
        case .plyo: "Plyo"
        case .strength: "Strength"
        case .balance: "Balance"
        case .track: "Track"
        case .stretch: "Stretch"
        }
    }

    /// The web app's sport-pill emoji, with one change: it used 🏃 for both track
    /// and cardio, which is fine in a small pill and confusing on two adjacent
    /// picker cards.
    var emoji: String {
        switch self {
        case .warmup: "🔥"
        case .soccer: "⚽"
        case .football: "🏈"
        case .basketball: "🏀"
        case .baseball: "⚾"
        case .cardio: "🏃"
        case .plyo: "🤸"
        case .strength: "💪"
        case .balance: "⚖️"
        case .track: "🏁"
        case .stretch: "🧘"
        }
    }

    var pillLabel: String { "\(emoji) \(displayName)" }

    /// Every word a search box should accept for this tag. `displayName` is
    /// what the section headers show, but people type the longer or the
    /// alternative name just as often.
    var searchAliases: [String] {
        switch self {
        case .plyo: ["Plyo", "Plyometrics", "Jumping"]
        case .stretch: ["Stretch", "Cooldown", "Cool down", "Flexibility"]
        case .warmup: ["Warmup", "Warm up"]
        case .cardio: ["Cardio", "Conditioning", "Endurance"]
        case .strength: ["Strength", "Bodyweight"]
        default: [displayName]
        }
    }

    func matchesSearch(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return searchAliases.contains { $0.localizedCaseInsensitiveContains(trimmed) }
    }

    /// The `.tag-*` colors from the web app's stylesheet.
    var color: Color {
        switch self {
        case .warmup: Color(hex: 0x38BDF8)
        case .soccer: Color(hex: 0x16A869)
        case .football: Color(hex: 0xC87941)
        case .basketball: Color(hex: 0xE8752C)
        case .baseball: Color(hex: 0xC23B3B)
        case .cardio: Color(hex: 0x185FA5)
        case .plyo: Color(hex: 0xA89BFF)
        case .strength: Color(hex: 0xF0A500)
        case .balance: Color(hex: 0x14B8A6)
        case .track: Color(hex: 0x185FA5)
        case .stretch: Color(hex: 0xFF7BAC)
        }
    }

    private var order: Int { Tag.allCases.firstIndex(of: self) ?? 0 }

    static func < (lhs: Tag, rhs: Tag) -> Bool { lhs.order < rhs.order }
}
