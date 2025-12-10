import SwiftUI

struct Theme {
    // MARK: - Backgrounds
    static let background = Color(uiColor: .systemGroupedBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let tertiaryBackground = Color(uiColor: .tertiarySystemGroupedBackground)
    
    // MARK: - Text Colors
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(uiColor: .tertiaryLabel)
    
    // MARK: - Accent Colors (Adaptive)
    static let primary = Color.blue
    static let secondary = Color.gray
    static let accent = Color.indigo
    
    // MARK: - Semantic Colors (Adaptive)
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.blue
    
    // MARK: - Note Type Colors (Adaptive)
    static let noteOrange = Color.orange
    static let taskGreen = Color.green
    static let eventBlue = Color.blue
    
    // MARK: - Priority Colors
    static let priorityHigh = Color.red
    static let priorityMedium = Color.orange
    static let priorityLow = Color.green
    
    // MARK: - Shadow Colors (Adaptive)
    static var shadowColor: Color {
        Color(uiColor: .label).opacity(0.1)
    }
    
    static var shadowColorStrong: Color {
        Color(uiColor: .label).opacity(0.15)
    }
    
    // MARK: - Divider
    static let divider = Color(uiColor: .separator)
    
    // MARK: - Spacing & Sizing
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusLarge: CGFloat = 16
    static let padding: CGFloat = 12
    static let paddingSmall: CGFloat = 8
    static let paddingLarge: CGFloat = 16
    
    // MARK: - Gradient Helpers
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primary, primary.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    // Add this inside the 'Gradient Helpers' section
    static var recordingGradient: LinearGradient {
        LinearGradient(
            colors: [Color.red, Color.orange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Adaptive Card Background Modifier
extension View {
    func adaptiveCardBackground() -> some View {
        self.modifier(AdaptiveCardModifier())
    }
}

struct AdaptiveCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadius)
            .shadow(
                color: colorScheme == .dark ? .clear : Theme.shadowColor,
                radius: 5,
                x: 0,
                y: 2
            )
    }
}

// MARK: - Enhanced Shadow Modifier
extension View {
    func cardShadow(strength: ShadowStrength = .normal) -> some View {
        self.modifier(CardShadowModifier(strength: strength))
    }
    
    func adaptiveBorder() -> some View {
        self.modifier(AdaptiveBorderModifier())
    }
}

enum ShadowStrength {
    case light, normal, strong
    
    var radius: CGFloat {
        switch self {
        case .light: return 3
        case .normal: return 5
        case .strong: return 8
        }
    }
    
    var yOffset: CGFloat {
        switch self {
        case .light: return 1
        case .normal: return 2
        case .strong: return 4
        }
    }
}

struct CardShadowModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let strength: ShadowStrength
    
    func body(content: Content) -> some View {
        content.shadow(
            color: colorScheme == .dark ? .clear : Theme.shadowColor,
            radius: strength.radius,
            x: 0,
            y: strength.yOffset
        )
    }
}

// MARK: - Adaptive Border for Light Mode
struct AdaptiveBorderModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(
                    colorScheme == .dark ? Color.clear : Color.gray.opacity(0.2),
                    lineWidth: 0.5
                )
        )
    }
}