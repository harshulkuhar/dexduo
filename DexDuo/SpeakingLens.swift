import SwiftUI

struct SpeakingLensGlow: ViewModifier {
    let speaking: Bool
    let outputLevel: Float
    let reduceMotion: Bool
    let maximumBlur: CGFloat

    func body(content: Content) -> some View {
        let level = speaking ? CGFloat(outputLevel) : 0
        let opacity = speaking && reduceMotion ? 0.15 : Double(level) * 0.35
        let blur = speaking && reduceMotion ? maximumBlur : maximumBlur * level
        content.background {
            Circle().fill(.cyan.opacity(opacity)).blur(radius: blur)
                .allowsHitTesting(false).accessibilityHidden(true)
                .transaction { $0.animation = nil }
        }
    }
}
