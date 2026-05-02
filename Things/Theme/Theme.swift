import SwiftUI
import UIKit

enum Theme {
    static let bg            = Color(lightHex: 0xF7F7F5, darkHex: 0x0E0E10)
    static let bgDeep        = Color(lightHex: 0xEFEFEB, darkHex: 0x08080A)
    static let surface       = Color(lightHex: 0xFFFFFF, darkHex: 0x161618)
    static let surface2      = Color(lightHex: 0xECECEA, darkHex: 0x1E1E22)
    static let hairline      = Color(lightHex: 0xDDDDD8, darkHex: 0x26262B)
    static let hairlineSoft  = Color(lightHex: 0xE7E7E2, darkHex: 0x1F1F23)
    static let text          = Color(lightHex: 0x151517, darkHex: 0xF2F2F4)
    static let textDim       = Color(lightHex: 0x69696F, darkHex: 0x9A9AA2)
    static let textFaint     = Color(lightHex: 0x9A9A9E, darkHex: 0x5E5E67)
    static let danger        = Color(lightHex: 0xD64538, darkHex: 0xE85B4D)

    // Violet accent (replacing amber)
    static let accent        = Color(lightHex: 0x6F55D8, darkHex: 0xA284F4)
    static let accentDim     = Color(lightHex: 0x6F55D8, darkHex: 0xA284F4, opacity: 0.14)
    static let accentBorder  = Color(lightHex: 0x6F55D8, darkHex: 0xA284F4, opacity: 0.30)
    static let accentBorderStrong = Color(lightHex: 0x6F55D8, darkHex: 0xA284F4, opacity: 0.35)
    static let accentTintTop = Color(lightHex: 0x6F55D8, darkHex: 0xA284F4, opacity: 0.06)
    static let accentTintBot = Color(lightHex: 0x6F55D8, darkHex: 0xA284F4, opacity: 0.02)
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

    init(lightHex: UInt32, darkHex: UInt32, opacity: Double = 1) {
        self.init(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? darkHex : lightHex
            return UIColor(
                red: Double((hex >> 16) & 0xFF) / 255,
                green: Double((hex >> 8) & 0xFF) / 255,
                blue: Double(hex & 0xFF) / 255,
                alpha: opacity
            )
        })
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
