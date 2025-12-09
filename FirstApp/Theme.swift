import SwiftUI


struct Theme {
    // Use System Colors (These automatically flip between Light/Dark)
    static let background = Color(uiColor: .systemGroupedBackground) 
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    
    // Keep these as they are (they are already adaptive)
    static let primary = Color.blue
    static let secondary = Color.gray
    static let accent = Color.indigo
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary

    static let cornerRadius: CGFloat = 12
    static let padding: CGFloat = 12
}

