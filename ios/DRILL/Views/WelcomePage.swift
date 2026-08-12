import SwiftUI

/// The first thing anyone sees. It gets the brand's full-bleed treatment —
/// near-black ground, the green runner mark, the wordmark at display size —
/// rather than the same padded white page as the rest of onboarding.
///
/// It animates in on appear because a static wall of text is exactly what this
/// screen was before, and an 8-12 year old decides whether an app is worth their
/// time in about two seconds.
struct WelcomePage: View {
    let onContinue: () -> Void

    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                background

                VStack(spacing: 0) {
                    Spacer(minLength: geo.size.height * 0.06)

                    mark
                        .scaleEffect(appeared ? 1 : 0.7)
                        .opacity(appeared ? 1 : 0)

                    wordmark
                        .padding(.top, 22)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)

                    Text("Multi-sport training for young athletes")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                        .padding(.horizontal, 32)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)

                    Spacer(minLength: 20)

                    features
                        .padding(.horizontal, 20)

                    Spacer(minLength: 16)

                    startButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 20) + 8)
                        .opacity(appeared ? 1 : 0)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            guard !appeared else { return }
            withAnimation(.spring(response: 0.65, dampingFraction: 0.7)) { appeared = true }
        }
    }

    // MARK: - Pieces

    /// A green glow behind the mark, fading into the app's near-black.
    private var background: some View {
        ZStack {
            Theme.ink
            RadialGradient(
                colors: [Theme.green.opacity(0.35), Theme.green.opacity(0.06), .clear],
                center: UnitPoint(x: 0.5, y: 0.28),
                startRadius: 10,
                endRadius: 460
            )
        }
    }

    private var mark: some View {
        Image(systemName: "figure.run")
            .font(.system(size: 76, weight: .black))
            .foregroundStyle(Theme.green)
            .frame(width: 132, height: 132)
            .background(.white.opacity(0.06), in: .circle)
            .overlay(Circle().strokeBorder(Theme.green.opacity(0.35), lineWidth: 2))
            .shadow(color: Theme.green.opacity(0.45), radius: 30)
    }

    private var wordmark: some View {
        Text("DRILL")
            .font(.system(size: 68, weight: .black, design: .rounded))
            .kerning(6)
            .foregroundStyle(
                LinearGradient(
                    colors: [.white, Theme.green],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var features: some View {
        VStack(spacing: 10) {
            ForEach(Array(Self.points.enumerated()), id: \.offset) { index, point in
                HStack(spacing: 14) {
                    Image(systemName: point.symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.green)
                        .frame(width: 30)
                    Text(point.text)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(.white.opacity(0.07), in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.08)))
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.8).delay(0.18 + Double(index) * 0.07),
                    value: appeared
                )
            }
        }
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

    private static let points: [(symbol: String, text: String)] = [
        ("calendar.badge.clock", "A fresh session every training day"),
        ("waveform", "Timers that talk you through every step"),
        ("flame.fill", "Streaks, badges and records to beat"),
        ("lock.shield.fill", "Everything stays on this phone. No account."),
    ]
}

#Preview {
    WelcomePage(onContinue: {})
}
