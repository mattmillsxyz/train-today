import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// The web app's CSS custom properties, ported one for one. The app follows the
/// system appearance rather than carrying its own toggle — iOS already has one.
enum Theme {
    /// `--green`. Fixed across both appearances.
    static let green = Color(hex: 0x22D68A)
    /// `--green-dark`. The week strip and section headings.
    static let greenDark = Color(hex: 0x16A869)
    /// The near-black the green header and timer draw their text in.
    static let ink = Color(hex: 0x0D0D0D)
    /// The timer overlay's flat green, kept distinct from `--green` as in the web app.
    static let timerGreen = Color(hex: 0x22C55E)
    /// The timer's button green.
    static let timerButton = Color(hex: 0x1AAD52)

    /// `--bg`
    static let bg = dynamic(dark: 0x0D0D0D, light: 0xF0F0F0)
    /// `--card`
    static let card = dynamic(dark: 0x161616, light: 0xFFFFFF)
    /// `--text`
    static let text = dynamic(dark: 0xF0F0F0, light: 0x1A1A1A)
    /// `--text-secondary`
    static let textSecondary = dynamic(dark: 0x888888, light: 0x777777)
    /// `--border`
    static let border = dynamic(dark: 0x2A2A2A, light: 0xE0E0E0)
    /// `--green-light`, the tint behind numbered step circles.
    static let greenLight = dynamic(dark: 0x0D2E1F, light: 0xD4F5E9)

    /// `#app`'s `max-width: 600px`.
    static let maxContentWidth: CGFloat = 600
    /// The card stack's `border-radius: 20px`.
    static let cardRadius: CGFloat = 20

    private static func dynamic(dark: UInt32, light: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
}

extension View {
    /// Constrains content to the web app's 600pt column and keeps it centered.
    func appColumn() -> some View {
        frame(maxWidth: Theme.maxContentWidth)
            .frame(maxWidth: .infinity)
    }
}
