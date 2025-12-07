// ToastModifier.swift
// Non-intrusive toast notifications

import SwiftUI

// MARK: - Toast Type
enum ToastType {
    case success
    case error
    case info
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        }
    }
}

// MARK: - Toast View
struct ToastView: View {
    let message: String
    let type: ToastType
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: type.icon)
                .foregroundStyle(type.color)
            
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
}

// MARK: - Toast Modifier
struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let type: ToastType
    let duration: Double
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            VStack {
                Spacer()
                
                if isPresented {
                    ToastView(message: message, type: type)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    isPresented = false
                                }
                            }
                        }
                        .padding(.bottom, 40)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented)
        }
    }
}

// MARK: - View Extension
extension View {
    func toast(isPresented: Binding<Bool>, message: String, type: ToastType = .success, duration: Double = 2.0) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, type: type, duration: duration))
    }
}
