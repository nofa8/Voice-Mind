// FirstApp/Theme.swift
import SwiftUI

struct Theme {
    // MARK: - Semantic Colors
    // Adapts automatically to Light/Dark mode
    static let background = Color(uiColor: .systemGroupedBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    
    static let primary = Color.blue
    static let secondary = Color.gray
    static let accent = Color.indigo
    static let destructive = Color.red
    static let success = Color.green
    
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(uiColor: .tertiaryLabel)

    // MARK: - Layout Constants
    static let cornerRadius: CGFloat = 16
    static let padding: CGFloat = 16
    static let spacing: CGFloat = 12
    
    // MARK: - Gradients
    static let recordingGradient = LinearGradient(
        colors: [Color.red, Color.orange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let primaryGradient = LinearGradient(
        colors: [Color.blue, Color.purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - View Modifiers
struct AdaptiveCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadius)
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.05),
                radius: 10,
                x: 0,
                y: 4
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.clear, lineWidth: 1)
            )
    }
}

extension View {
    func adaptiveCardStyle() -> some View {
        modifier(AdaptiveCardModifier())
    }
}