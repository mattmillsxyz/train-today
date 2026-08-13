import SwiftUI

/// The first thing anyone sees. Full-bleed near-black, the wordmark at display
/// size, and the sport emojis from the picker drifting behind it.
///
/// It moves on purpose. A static list of bullet points is exactly what this
/// screen was before, and an 8-12 year old decides whether an app is worth
/// their time in about two seconds. Everything here is decorative, so it all
/// stands still when the system asks for reduced motion.
struct WelcomePage: View {
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var glowing = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                background
                EmojiDrift()

                VStack(spacing: 0) {
                    Spacer(minLength: geo.size.height * 0.13)

                    wordmark
                        .scaleEffect(appeared ? 1 : 0.84)
                        .opacity(appeared ? 1 : 0)

                    tagline
                        .padding(.top, 16)
                        .padding(.horizontal, 28)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 18)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.12), value: appeared)

                    blurb
                        .padding(.top, 14)
                        .padding(.horizontal, 36)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 18)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.22), value: appeared)

                    Spacer(minLength: 24)

                    startButton
                        .padding(.horizontal, 24)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.82).delay(0.34), value: appeared)

                    footnote
                        .padding(.top, 14)
                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 20) + 8)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.46), value: appeared)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            guard !appeared else { return }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) { appeared = true }
            glowing = true
        }
    }

    // MARK: - Pieces

    /// A green glow behind the wordmark, breathing slowly, fading into the
    /// app's near-black.
    private var background: some View {
        ZStack {
            Theme.ink
            RadialGradient(
                colors: [Theme.green.opacity(0.34), Theme.green.opacity(0.07), .clear],
                center: UnitPoint(x: 0.5, y: 0.24),
                startRadius: 10,
                endRadius: 470
            )
            .scaleEffect(glowing ? 1.07 : 0.94)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 4.5).repeatForever(autoreverses: true),
                value: glowing
            )
        }
    }

    /// The real wordmark rather than a system face standing in for it. The
    /// artwork is a white-on-transparent mask, so the colour is painted
    /// through its alpha.
    private var wordmark: some View {
        Theme.green
            .mask {
                Image("Wordmark")
                    .resizable()
                    .scaledToFit()
            }
            .frame(width: Self.wordmarkWidth, height: Self.wordmarkWidth / Self.wordmarkAspect)
            .shadow(color: Theme.green.opacity(0.5), radius: 28)
            .accessibilityLabel("DRILL")
    }

    private static let wordmarkWidth: CGFloat = 268
    /// 3164 × 846, the artwork's own proportions.
    private static let wordmarkAspect: CGFloat = 3164.0 / 846.0

    private var tagline: some View {
        Text("Multi-sport training for young athletes")
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(.white.opacity(0.92))
            .multilineTextAlignment(.center)
    }

    private var blurb: some View {
        Text("A fresh session every training day: timed, talked through, and built around the sports you actually play.")
            .font(.system(size: 15))
            .foregroundStyle(.white.opacity(0.55))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
    }

    private var startButton: some View {
        Button(action: onContinue) {
            Text("Let's go")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Theme.green, in: .capsule)
                .shadow(color: Theme.green.opacity(0.35), radius: 18, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var footnote: some View {
        Text("No account · Nothing leaves this phone")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.4))
    }
}

// MARK: - Drifting emoji

/// One emoji, bobbing.
private struct Mote: Identifiable {
    let id = UUID()
    let emoji: String
    /// Position in unit space, so the field scales from an SE to a Pro Max.
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
    /// Half the vertical travel: the mote runs from `+drift` to `-drift`.
    let drift: CGFloat
    let tilt: Double
    let duration: Double
    let delay: Double
}

/// The sport emojis from the picker, drifting behind the wordmark.
///
/// Purely decorative — hidden from VoiceOver, untappable, and still when
/// reduced motion is on.
private struct EmojiDrift: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Hand-placed rather than randomised: random placement clumps, and the
    /// text has to stay clear.
    ///
    /// The copy occupies two bands — wordmark through blurb at roughly
    /// y 0.33–0.62, and the button and footnote from y 0.83 down — and both run
    /// nearly the full width. So the motes live above, between and beside them,
    /// never inside.
    private static let motes: [Mote] = [
        Mote(emoji: "⚽", x: 0.12, y: 0.085, size: 54, opacity: 0.32, drift: 16, tilt: 9, duration: 4.2, delay: 0.0),
        Mote(emoji: "🏈", x: 0.88, y: 0.135, size: 44, opacity: 0.28, drift: 13, tilt: -7, duration: 5.1, delay: 0.5),
        Mote(emoji: "🏁", x: 0.22, y: 0.215, size: 32, opacity: 0.22, drift: 11, tilt: 6, duration: 4.7, delay: 1.1),
        Mote(emoji: "💪", x: 0.82, y: 0.255, size: 40, opacity: 0.26, drift: 14, tilt: -8, duration: 5.6, delay: 0.3),
        Mote(emoji: "🤸", x: 0.15, y: 0.66, size: 48, opacity: 0.30, drift: 17, tilt: 10, duration: 4.4, delay: 0.8),
        Mote(emoji: "⚖️", x: 0.87, y: 0.70, size: 34, opacity: 0.24, drift: 12, tilt: -6, duration: 5.3, delay: 1.4),
        Mote(emoji: "🏃", x: 0.50, y: 0.785, size: 44, opacity: 0.26, drift: 15, tilt: 8, duration: 4.9, delay: 0.6),
        // Small and faint, for depth.
        Mote(emoji: "⚽", x: 0.74, y: 0.625, size: 24, opacity: 0.14, drift: 9, tilt: -5, duration: 6.0, delay: 1.7),
        Mote(emoji: "💪", x: 0.28, y: 0.79, size: 22, opacity: 0.13, drift: 8, tilt: 5, duration: 5.8, delay: 2.1),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(Self.motes) { mote in
                DriftingMote(mote: mote, still: reduceMotion)
                    .position(x: mote.x * geo.size.width, y: mote.y * geo.size.height)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct DriftingMote: View {
    let mote: Mote
    let still: Bool

    @State private var shown = false
    @State private var up = false

    var body: some View {
        Text(mote.emoji)
            .font(.system(size: mote.size))
            .opacity(shown ? mote.opacity : 0)
            .scaleEffect(shown ? 1 : 0.6)
            .rotationEffect(.degrees(up ? mote.tilt : -mote.tilt))
            .offset(y: up ? -mote.drift : mote.drift)
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(mote.delay * 0.2)) {
                    shown = true
                }
                guard !still else { return }
                withAnimation(
                    .easeInOut(duration: mote.duration).repeatForever(autoreverses: true).delay(mote.delay)
                ) {
                    up = true
                }
            }
    }
}

#Preview {
    WelcomePage(onContinue: {})
}
