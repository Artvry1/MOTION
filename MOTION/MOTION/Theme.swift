import SwiftUI

enum MotionTheme {
    static let background = Color(red: 0.018, green: 0.020, blue: 0.035)
    static let panel = Color(red: 0.075, green: 0.080, blue: 0.135)
    static let muted = Color(red: 0.58, green: 0.59, blue: 0.70)
    static let accent = LinearGradient(
        colors: [
            Color(red: 0.30, green: 0.35, blue: 1.0),
            Color(red: 0.67, green: 0.20, blue: 0.95),
            Color(red: 0.95, green: 0.28, blue: 0.78)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct GlassPanel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white.opacity(0.055))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(.white.opacity(0.09), lineWidth: 1)
                    }
            }
    }
}
