import SwiftUI

enum PipoMood {
    case sleeping, awake, shout, happy, suspicious

    var description: String {
        switch self {
        case .sleeping: return "durmiendo"
        case .awake: return "despierto"
        case .shout: return "gritando para despertarte"
        case .happy: return "contento"
        case .suspicious: return "desconfiado"
        }
    }
}

/// Pipo, la bolita dormilona. Dibujado en un lienzo de 120 × 120 puntos y escalado.
struct PipoView: View {
    var mood: PipoMood = .awake
    var accessory: Accessory? = nil
    var size: CGFloat = 120
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob = false

    var body: some View {
        Canvas { context, canvasSize in
            draw(in: &context, size: canvasSize)
        }
        .frame(width: size, height: size)
        .offset(y: animated && !reduceMotion ? (bob ? -size * 0.025 : size * 0.025) : 0)
        .rotationEffect(.degrees(animated && !reduceMotion && mood == .shout ? (bob ? -4 : 4) : 0))
        .onAppear {
            guard animated, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: mood == .shout ? 0.18 : 1.6).repeatForever(autoreverses: true)) {
                bob = true
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Pipo, \(mood.description)")
    }

    private func draw(in context: inout GraphicsContext, size canvasSize: CGSize) {
        let k = canvasSize.width / 120
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * k, y: y * k) }
        func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: (cx - rx) * k, y: (cy - ry) * k, width: rx * 2 * k, height: ry * 2 * k))
        }
        func line(_ points: [(CGFloat, CGFloat)]) -> Path {
            var path = Path()
            guard let first = points.first else { return path }
            path.move(to: p(first.0, first.1))
            for point in points.dropFirst() { path.addLine(to: p(point.0, point.1)) }
            return path
        }
        let ink = Theme.ink
        let thick = StrokeStyle(lineWidth: 4 * k, lineCap: .round, lineJoin: .round)
        let medium = StrokeStyle(lineWidth: 3.5 * k, lineCap: .round, lineJoin: .round)

        // Brote con hoja (se esconde bajo el gorro o la corona).
        if accessory != .hat && accessory != .crown {
            var stem = Path()
            stem.move(to: p(60, 28))
            stem.addCurve(to: p(66, 10), control1: p(58, 20), control2: p(60, 14))
            context.stroke(stem, with: .color(Theme.mascot), style: thick)
            var leaf = Path()
            leaf.move(to: p(65, 11))
            leaf.addQuadCurve(to: p(81, 6), control: p(71, -1))
            leaf.addQuadCurve(to: p(65, 11), control: p(77, 15))
            context.fill(leaf, with: .color(Theme.accent))
        }

        // Cuerpo y barriga.
        context.fill(ellipse(60, 68, 44, 42), with: .color(Theme.mascot))
        context.fill(ellipse(60, 86, 24, 16), with: .color(.white.opacity(0.28)))

        // Mofletes.
        context.fill(ellipse(31, 76, 6, 6), with: .color(Theme.accent.opacity(0.45)))
        context.fill(ellipse(89, 76, 6, 6), with: .color(Theme.accent.opacity(0.45)))

        // Ojos y boca según el humor.
        switch mood {
        case .sleeping:
            for x in [37.0, 67.0] as [CGFloat] {
                var eye = Path()
                eye.move(to: p(x, 61))
                eye.addQuadCurve(to: p(x + 16, 61), control: p(x + 8, 67))
                context.stroke(eye, with: .color(ink), style: thick)
            }
            context.fill(ellipse(60, 82, 3.5, 3.5), with: .color(ink))
            context.draw(Text("z").font(.system(size: 18 * k, weight: .bold, design: .rounded)).foregroundColor(ink), at: p(97, 28))
            context.draw(Text("z").font(.system(size: 13 * k, weight: .bold, design: .rounded)).foregroundColor(ink), at: p(108, 15))

        case .awake:
            for x in [45.0, 75.0] as [CGFloat] {
                context.fill(ellipse(x, 60, 6, 6), with: .color(ink))
                context.fill(ellipse(x + 2, 58, 2, 2), with: .color(.white))
            }
            var smile = Path()
            smile.move(to: p(53, 80))
            smile.addQuadCurve(to: p(67, 80), control: p(60, 86))
            context.stroke(smile, with: .color(ink), style: medium)

        case .shout:
            for x in [45.0, 75.0] as [CGFloat] {
                context.fill(ellipse(x, 58, 8.5, 8.5), with: .color(ink))
                context.fill(ellipse(x + 3, 55, 3, 3), with: .color(.white))
            }
            context.stroke(line([(36, 44), (52, 49)]), with: .color(ink), style: thick)
            context.stroke(line([(84, 44), (68, 49)]), with: .color(ink), style: thick)
            context.fill(ellipse(60, 85, 9, 11), with: .color(ink))
            context.fill(ellipse(60, 90, 5, 4), with: .color(Theme.accent))
            let shoutStyle = StrokeStyle(lineWidth: 3 * k, lineCap: .round)
            for segment in [[(8.0, 30.0), (18.0, 36.0)], [(4.0, 46.0), (16.0, 48.0)],
                            [(112.0, 30.0), (102.0, 36.0)], [(116.0, 46.0), (104.0, 48.0)]] as [[(CGFloat, CGFloat)]] {
                context.stroke(line(segment), with: .color(ink), style: shoutStyle)
            }

        case .happy:
            for x in [37.0, 67.0] as [CGFloat] {
                var eye = Path()
                eye.move(to: p(x, 63))
                eye.addQuadCurve(to: p(x + 16, 63), control: p(x + 8, 53))
                context.stroke(eye, with: .color(ink), style: thick)
            }
            var mouth = Path()
            mouth.move(to: p(48, 78))
            mouth.addQuadCurve(to: p(72, 78), control: p(60, 94))
            mouth.closeSubpath()
            context.fill(mouth, with: .color(ink))

        case .suspicious:
            context.stroke(line([(36, 58), (54, 58)]), with: .color(ink), style: thick)
            context.stroke(line([(66, 58), (84, 58)]), with: .color(ink), style: thick)
            context.fill(ellipse(47, 63, 4, 4), with: .color(ink))
            context.fill(ellipse(77, 63, 4, 4), with: .color(ink))
            context.stroke(line([(54, 84), (66, 82)]), with: .color(ink), style: medium)
        }

        // Accesorios.
        switch accessory {
        case .hat:
            var hat = Path()
            hat.move(to: p(28, 36))
            hat.addCurve(to: p(98, 24), control1: p(34, 8), control2: p(72, 0))
            hat.addLine(to: p(94, 34))
            hat.addCurve(to: p(28, 36), control1: p(78, 26), control2: p(52, 26))
            hat.closeSubpath()
            context.fill(hat, with: .color(Theme.accent))
            var brim = Path()
            brim.move(to: p(26, 34))
            brim.addCurve(to: p(96, 32), control1: p(50, 24), control2: p(76, 24))
            brim.addLine(to: p(96, 40))
            brim.addCurve(to: p(26, 42), control1: p(76, 32), control2: p(50, 32))
            brim.closeSubpath()
            context.fill(brim, with: .color(.white))
            context.fill(ellipse(100, 22, 7, 7), with: .color(.white))

        case .crown:
            let crown = line([(36, 32), (40, 12), (50, 22), (60, 6), (70, 22), (80, 12), (84, 32)])
            var closed = crown
            closed.closeSubpath()
            context.fill(closed, with: .color(Theme.gold))
            context.fill(ellipse(60, 22, 4, 4), with: .color(Theme.accent))

        case .scarf:
            var band = Path()
            band.move(to: p(22, 92))
            band.addQuadCurve(to: p(98, 92), control: p(60, 106))
            band.addLine(to: p(97, 101))
            band.addQuadCurve(to: p(23, 101), control: p(60, 116))
            band.closeSubpath()
            context.fill(band, with: .color(Theme.accent))
            context.fill(Path(roundedRect: CGRect(x: 70 * k, y: 100 * k, width: 12 * k, height: 20 * k), cornerRadius: 3 * k),
                         with: .color(Theme.accent))

        case .glasses:
            let lens = Theme.ink.opacity(0.88)
            context.fill(Path(roundedRect: CGRect(x: 31 * k, y: 51 * k, width: 27 * k, height: 18 * k), cornerRadius: 7 * k), with: .color(lens))
            context.fill(Path(roundedRect: CGRect(x: 62 * k, y: 51 * k, width: 27 * k, height: 18 * k), cornerRadius: 7 * k), with: .color(lens))
            context.stroke(line([(58, 58), (62, 58)]), with: .color(ink), style: StrokeStyle(lineWidth: 3 * k, lineCap: .round))
            context.stroke(line([(36, 55), (42, 55)]), with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 2 * k, lineCap: .round))
            context.stroke(line([(67, 55), (73, 55)]), with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 2 * k, lineCap: .round))

        case .none:
            break
        }
    }
}
