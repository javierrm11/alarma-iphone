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

/// Estilo "Compañeros" con la gama "Caramelo".
enum Theme {
    static let bg = Color(hex: 0xFFF4EC)
    static let surface = Color.white
    static let surface2 = Color(hex: 0xFFE4D3)
    static let primary = Color(hex: 0xFF7A59)
    static let primaryText = Color(hex: 0xC2410C)
    static let onPrimary = Color(hex: 0x2A1206)
    static let deep = Color(hex: 0xD9573A)
    static let accent = Color(hex: 0x7C5CFF)
    static let text = Color(hex: 0x2A1F3D)
    static let muted = Color(hex: 0x6A5E7C)
    static let line = Color(hex: 0xF3D9C8)
    static let mascot = Color(hex: 0xFF8F6B)
    static let ink = Color(hex: 0x2A1F3D)
    static let gold = Color(hex: 0xFFC531)

    static let radius: CGFloat = 26
    static let smallRadius: CGFloat = 16

    /// Títulos redondeados (sustituto nativo de Fredoka).
    static func display(_ style: Font.TextStyle, _ weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }

    /// Números grandes de la hora.
    static func clock(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
    }

    static func body(_ style: Font.TextStyle = .body, _ weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}
