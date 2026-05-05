import SwiftUI

enum AppTheme {
    static let deepBlue = Color(red: 0.114, green: 0.204, blue: 0.482)
    static let electricBlue = Color(red: 0.114, green: 0.204, blue: 0.482)
    static let bimboRed = Color(red: 0.890, green: 0.114, blue: 0.176)
    static let brandWhite = Color.white
    static let softGray = Color(red: 0.94, green: 0.95, blue: 0.97)
    static let success = Color(red: 0.08, green: 0.55, blue: 0.32)
    static let warning = Color(red: 0.91, green: 0.58, blue: 0.10)

    static var systemBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    static var secondarySystemBackground: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [deepBlue, deepBlue.opacity(0.92), bimboRed.opacity(0.86)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var subtleGradient: LinearGradient {
        LinearGradient(
            colors: [deepBlue.opacity(0.12), bimboRed.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension ShapeStyle where Self == Color {
    static var rutaBlue: Color { AppTheme.deepBlue }
    static var rutaRed: Color { AppTheme.bimboRed }
}
