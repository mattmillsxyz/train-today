import Foundation

/// What a step is *for*. Only `action` steps advance the walkthrough — this is
/// the field that takes the 25 stepped exercises from 129 screens to 64.
enum StepRole: String, Codable, Hashable, Sendable {
    /// Something to arrange before starting: cones, a wall, a stretch of grass.
    case setup
    /// How the movement should look. Shown on the get-ready screen.
    case form
    /// A reminder that runs alongside the work and never gates it.
    case cue
    /// The work itself.
    case action
}

/// A logical name for a demo asset. Never a filename or a URL, so that changing
/// how media is delivered never means touching content.
struct MediaRef: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case loop
        case clip
    }

    let asset: String
    let kind: Kind
}

struct Step: Codable, Hashable, Sendable {
    let text: String
    let role: StepRole
    let media: MediaRef?
    let timing: Timing?
}

/// A number worth beating. The exercise content already asks for these in
/// prose ("Count your best streak!"); this turns the prompt into a logged value.
struct PRMetric: Codable, Hashable, Sendable {
    enum Unit: String, Codable, Sendable {
        case count
        case seconds
        case inches
        case feet

        /// Short suffix for a logged value.
        var suffix: String {
            switch self {
            case .count: ""
            case .seconds: "s"
            case .inches: "\""
            case .feet: "ft"
            }
        }

        var fieldLabel: String {
            switch self {
            case .count: "How many?"
            case .seconds: "How many seconds?"
            case .inches: "How many inches?"
            case .feet: "How many feet?"
            }
        }
    }

    let label: String
    let unit: Unit
    let higherIsBetter: Bool
}

struct Exercise: Codable, Identifiable, Hashable, Sendable {
    /// How the walkthrough runs this exercise.
    enum Mode: String, Codable, Sendable {
        /// Walk the action steps one at a time, timing the ones that carry a clock.
        case stepped
        /// Open practice against a single whole-exercise clock, all steps listed.
        case openBlock
    }

    let id: String
    let name: String
    let tag: Tag
    /// The human string the web app showed, e.g. "6 min · 3×10". Kept verbatim.
    let displayDuration: String
    let estimatedMinutes: Int
    let mode: Mode
    let prMetric: PRMetric?
    let steps: [Step]
    let media: MediaRef?

    var setupSteps: [Step] { steps.filter { $0.role == .setup } }
    var formSteps: [Step] { steps.filter { $0.role == .form } }
    var actionSteps: [Step] { steps.filter { $0.role == .action } }
}
