import SwiftUI
import AppKit

// Single source of truth for colors and font sizes, mirroring the Windows Theme class.
enum Theme {
    static let background = Color(hex: 0xF3F4F6)
    static let border = Color(hex: 0xE5E7EB)
    static let textPrimary = Color(hex: 0x111827)
    static let textSecondary = Color(hex: 0x6B7280)
    static let textMuted = Color(hex: 0x9CA3AF)
    static let textBody = Color(hex: 0x374151)
    static let accent = Color(hex: 0x2563EB)
    static let accentHover = Color(hex: 0xEFF6FF)
    static let hover = Color(hex: 0xE5E7EB)
    static let cardBackground = Color.white

    static let titleFont = Font.system(size: 18, weight: .bold)
    static let subtitleFont = Font.system(size: 12)
    static let cardHeaderFont = Font.system(size: 14, weight: .semibold)
    static let counterFont = Font.system(size: 12)
    static let linkFont = Font.system(size: 13)
    static let bodyFont = Font.system(size: 15)
    static let controlFont = Font.system(size: 13)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
