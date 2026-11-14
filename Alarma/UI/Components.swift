import SwiftUI

// MARK: - Botones

/// Botón principal: píldora coral con "sombra" sólida debajo que se hunde al pulsar.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(Theme.display(.title3, .bold))
            .foregroundStyle(Theme.onPrimary)
            .frame(maxWidth: .infinity, minHeight: 58)
            .padding(.horizontal, 20)
            .background(Capsule().fill(Theme.primary))
            .background(Capsule().fill(Theme.deep).offset(y: pressed ? 1 : 5))
            .offset(y: pressed ? 4 : 0)
            .opacity(isEnabled ? 1 : 0.5)
            .animation(.spring(duration: 0.15), value: pressed)
    }
}

/// Botón secundario: contorno suave.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.body(.body, .bold))
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, 14)
            .background(Capsule().fill(configuration.isPressed ? Theme.surface2 : Color.clear))
            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 2))
    }
}

// MARK: - Tarjetas

struct CardBackground: ViewModifier {
    var radius: CGFloat = Theme.radius
    var fill: Color = Theme.surface

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.line, lineWidth: 2))
            .shadow(color: Color(hex: 0x2A1F3D, opacity: 0.08), radius: 12, y: 8)
    }
}

extension View {
    func pipoCard(radius: CGFloat = Theme.radius, fill: Color = Theme.surface) -> some View {
        modifier(CardBackground(radius: radius, fill: fill))
    }

    func screenBackground() -> some View {
        background(Theme.bg.ignoresSafeArea())
    }
}

// MARK: - Textos

struct SectionLabel: View {
    let text: String
    var color: Color = Theme.muted

    init(_ text: String, color: Color = Theme.muted) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(Theme.body(.caption, .bold))
            .tracking(0.8)
            .foregroundStyle(color)
    }
}

struct ScreenTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Theme.display(.largeTitle, .semibold))
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Bocadillo de cómic para lo que dice Pipo.
struct SpeechBubble: View {
    let text: String
    var centered = false

    var body: some View {
        Text(text)
            .font(Theme.body(.body, centered ? .bold : .regular))
            .foregroundStyle(Theme.text)
            .multilineTextAlignment(centered ? .center : .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: centered ? 300 : .infinity, alignment: centered ? .center : .leading)
            .background(bubbleShape.fill(Theme.surface))
            .overlay(bubbleShape.stroke(Theme.line, lineWidth: 2))
            .shadow(color: Color(hex: 0x2A1F3D, opacity: 0.08), radius: 12, y: 8)
    }

    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 20,
            bottomLeadingRadius: centered ? 20 : 6,
            bottomTrailingRadius: 20,
            topTrailingRadius: 20,
            style: .continuous
        )
    }
}

struct Chip: View {
    let text: String
    var fill: Color = Theme.surface2
    var color: Color = Theme.text

    var body: some View {
        Text(text)
            .font(Theme.body(.footnote, .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .background(Capsule().fill(fill))
    }
}

/// Fila "título — valor" para tarjetas de ajustes.
struct InfoRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.body(.body, .semibold))
                    .foregroundStyle(Theme.text)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.body(.caption))
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
    }
}

struct CardDivider: View {
    var body: some View {
        Rectangle().fill(Theme.line).frame(height: 2)
    }
}

// MARK: - Anillo de progreso

struct RingView<Center: View>: View {
    var progress: Double
    var lineWidth: CGFloat = 20
    var color: Color = Theme.primary
    @ViewBuilder var center: Center

    var body: some View {
        ZStack {
            Circle().stroke(Theme.surface2, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: progress)
            center
        }
        .padding(lineWidth / 2)
    }
}

// MARK: - Confeti

struct ConfettiDots: View {
    var body: some View {
        Canvas { context, size in
            let dots: [(CGFloat, CGFloat, CGFloat, Bool, Bool)] = [
                (0.08, 0.18, 6, true, false), (0.92, 0.26, 6, false, true), (0.86, 0.68, 5, true, false),
                (0.12, 0.72, 5, false, true), (0.22, 0.06, 4, true, true), (0.76, 0.05, 4, false, false),
                (0.95, 0.48, 3, true, true), (0.04, 0.45, 3, false, false)
            ]
            for (x, y, r, accent, square) in dots {
                let rect = CGRect(x: x * size.width - r, y: y * size.height - r, width: r * 2, height: r * 2)
                let path = square ? Path(roundedRect: rect, cornerRadius: 2) : Path(ellipseIn: rect)
                context.fill(path, with: .color(accent ? Theme.accent : Theme.primary))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
