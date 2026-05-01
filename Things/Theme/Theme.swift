import SwiftUI

enum Theme {
    static let bg            = Color(hex: 0x0E0E10)
    static let bgDeep        = Color(hex: 0x08080A)
    static let surface       = Color(hex: 0x161618)
    static let surface2      = Color(hex: 0x1E1E22)
    static let hairline      = Color(hex: 0x26262B)
    static let hairlineSoft  = Color(hex: 0x1F1F23)
    static let text          = Color(hex: 0xF2F2F4)
    static let textDim       = Color(hex: 0x9A9AA2)
    static let textFaint     = Color(hex: 0x5E5E67)
    static let danger        = Color(hex: 0xE85B4D)

    // Violet accent (replacing amber)
    static let accent        = Color(hex: 0xA284F4)
    static let accentDim     = Color(red: 162/255, green: 132/255, blue: 244/255, opacity: 0.14)
    static let accentBorder  = Color(red: 162/255, green: 132/255, blue: 244/255, opacity: 0.30)
    static let accentBorderStrong = Color(red: 162/255, green: 132/255, blue: 244/255, opacity: 0.35)
    static let accentTintTop = Color(red: 162/255, green: 132/255, blue: 244/255, opacity: 0.06)
    static let accentTintBot = Color(red: 162/255, green: 132/255, blue: 244/255, opacity: 0.02)
}

enum Fonts {
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >>  8) & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension View {
    @ViewBuilder
    func hairlineBorder(_ color: Color, radius: CGFloat) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(color, lineWidth: 0.5)
        )
    }
}
