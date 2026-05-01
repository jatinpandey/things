import SwiftUI

/// In-app preview of the app icon. The actual icon shipped to iOS lives in
/// `Assets.xcassets/AppIcon.appiconset` (rendered from `scripts/generate_icons.py`).
struct AppIconView: View {
    var size: CGFloat = 120
    var rounded: Bool = true

    var body: some View {
        let r = size * 0.235
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x2A2A2E), Color(hex: 0x1E1E22)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Lines — accent bar + neutral (centered, no binding dots)
            VStack(alignment: .leading, spacing: size * 0.09) {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: size * 0.76 * 0.60, height: size * 0.032)
                    .clipShape(Capsule())
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: size * 0.76 * 0.85, height: size * 0.022)
                    .clipShape(Capsule())
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: size * 0.76 * 0.70, height: size * 0.022)
                    .clipShape(Capsule())
            }
            .frame(width: size * 0.76, alignment: .leading)
            .position(x: size * 0.5, y: size * 0.46)
        }
        .frame(width: size, height: size)
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
