import SwiftUI

/// The web app's `.detail-steps` list: a numbered green circle, the step text,
/// and a hairline between rows.
struct NumberedSteps: View {
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, text in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.greenDark)
                        .frame(width: 20, height: 20)
                        .background(Theme.greenLight, in: .circle)
                    Text(text)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) {
                    if index < steps.count - 1 {
                        Rectangle().fill(Theme.border).frame(height: 1)
                    }
                }
            }
        }
    }
}

/// `.sport-pill` — a translucent capsule on the green header.
struct SportPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.white.opacity(0.2), in: .capsule)
    }
}

/// `.tag` — the small uppercase colored label under an exercise name.
struct TagLabel: View {
    let tag: Tag

    var body: some View {
        Text(tag.rawValue.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .kerning(0.3)
            .foregroundStyle(tag.color)
    }
}

/// `.progress-track` / `.progress-fill`.
struct ThinProgressBar: View {
    let fraction: Double
    var tint: Color = Theme.green
    /// The unfilled portion. On the green walkthrough `--border` is almost white
    /// and reads as a full bar, so callers on green pass their own.
    var track: Color = Theme.border

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * max(0, min(1, fraction)))
            }
        }
        .frame(height: 4)
        .animation(.easeOut(duration: 0.4), value: fraction)
    }
}

/// A section heading in the same voice as the web app's `.detail-title`.
struct SectionHeading: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .bold))
            .kerning(0.5)
            .foregroundStyle(Theme.greenDark)
    }
}

/// The rounded card the app stacks everything in.
struct CardPanel<Content: View>: View {
    var corners: RectangleCornerRadii = RectangleCornerRadii(
        topLeading: 0, bottomLeading: 0, bottomTrailing: 0, topTrailing: 0
    )
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(Theme.card)
            .clipShape(UnevenRoundedRectangle(cornerRadii: corners))
    }
}

extension RectangleCornerRadii {
    static func bottom(_ radius: CGFloat) -> RectangleCornerRadii {
        RectangleCornerRadii(topLeading: 0, bottomLeading: radius, bottomTrailing: radius, topTrailing: 0)
    }

    static func top(_ radius: CGFloat) -> RectangleCornerRadii {
        RectangleCornerRadii(topLeading: radius, bottomLeading: 0, bottomTrailing: 0, topTrailing: radius)
    }
}
