import SwiftUI

/// In-app preview of the app icon. The actual icon shipped to iOS lives in
/// `Assets.xcassets/AppIcon.appiconset` (rendered from `scripts/generate_icons.py`).
struct AppIconView: View {
    var size: CGFloat = 120
    var rounded: Bool = true

    var body: some View {
        let r = size * 0.235
        ZStack {
            // Outer dark shell
            LinearGradient(
                colors: [Color(hex: 0x1F1F23), Color(hex: 0x0E0E10)],
                startPoint: UnitPoint(x: 0.18, y: 0),
                endPoint:   UnitPoint(x: 0.82, y: 1)
            )

            // Notepad surface
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: size * 0.05, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x2A2A2E), Color(hex: 0x1E1E22)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.05, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)

                // Binding dots
                HStack {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color(hex: 0x0E0E10))
                            .frame(width: size * 0.04, height: size * 0.04)
                            .shadow(color: .black.opacity(0.5), radius: 0.5, x: 0, y: 0.5)
                        if true { Spacer().frame(maxWidth: .infinity) }
                    }
                }
                .padding(.horizontal, size * 0.10)
                .padding(.top, size * 0.04)
                .frame(width: size * 0.56)

                // Lines — accent bar + neutral
                VStack(alignment: .leading, spacing: size * 0.05) {
                    Rectangle()
                        .fill(Theme.accent)
                        .frame(width: size * 0.56 * 0.60, height: 1.5)
                        .clipShape(Capsule())
                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: size * 0.56 * 0.85, height: 1)
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: size * 0.56 * 0.70, height: 1)
                }
                .padding(.top, size * 0.18)
                .frame(width: size * 0.56 - size * 0.14, alignment: .leading)
            }
            .frame(width: size * 0.56, height: size * 0.64)
            .position(x: size * 0.5, y: size * 0.5)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: rounded ? r : 0, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: rounded ? r : 0, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 8)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        AppIconView(size: 220)
    }
}
