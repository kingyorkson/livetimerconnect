import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.035, green: 0.043, blue: 0.075)
    static let backgroundTop = Color(red: 0.085, green: 0.075, blue: 0.135)
    static let card = Color.white.opacity(0.065)
    static let cardStrong = Color.white.opacity(0.105)
    static let stroke = Color.white.opacity(0.09)
    static let orange = Color(red: 1.0, green: 0.58, blue: 0.18)
    static let red = Color(red: 1.0, green: 0.34, blue: 0.36)
    static let green = Color(red: 0.30, green: 0.86, blue: 0.55)
    static let blue = Color(red: 0.35, green: 0.66, blue: 1.0)
    static let purple = Color(red: 0.68, green: 0.45, blue: 1.0)
    static let textSecondary = Color.white.opacity(0.60)
    static let textTertiary = Color.white.opacity(0.38)
    static let corner: CGFloat = 24
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.backgroundTop, AppTheme.background, .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(AppTheme.orange.opacity(0.13))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 150, y: -280)

            Circle()
                .fill(AppTheme.purple.opacity(0.11))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: -170, y: 330)
        }
        .ignoresSafeArea()
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
