import Foundation
import SwiftUI

// MARK: - Haptic Feedback

enum HapticManager {
    static var enabled: Bool = true

    static func selection() {
        guard enabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard enabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard enabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

// MARK: - View Extensions

extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.4),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (phase * geometry.size.width * 2))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Color Extensions

extension Color {
    static let tacoOrange = Color(red: 0.9, green: 0.5, blue: 0.1)
    static let tacoYellow = Color(red: 1.0, green: 0.85, blue: 0.3)
    static let tacoGreen = Color(red: 0.15, green: 0.65, blue: 0.3)
    static let tacoPriceTeal = Color(red: 0.1, green: 0.55, blue: 0.55)
    static let tacoRed = Color(red: 0.9, green: 0.3, blue: 0.3)
    static let iconGrey = Color(red: 0.2, green: 0.2, blue: 0.2, opacity: 0.7)
}

// MARK: - Layout Tokens

enum Layout {
    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 12
    static let radiusLarge: CGFloat = 16

    static let paddingContent: CGFloat = 16
    static let paddingOuter: CGFloat = 24
    static let topControlsHeight: CGFloat = 56
}

// MARK: - Animation Extensions

extension Animation {
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
    static let smooth = Animation.easeInOut(duration: 0.3)
}
