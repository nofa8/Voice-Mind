import SwiftUI

struct Theme {
    static let background = Color(hex: "F2F2F7")
    static let cardBackground = Color.white
    static let primary = Color.blue
    static let secondary = Color.gray
    static let accent = Color.indigo
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary

    static let cornerRadius: CGFloat = 12
    static let padding: CGFloat = 12
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
