import SwiftUI

enum Theme {
    static let bg = Color(hex: "#050509")
    static let cyan = Color(hex: "#19E3FF")
    static let blue = Color(hex: "#4B5BFF")
    static let violet = Color(hex: "#9B3CFF")
    static let magenta = Color(hex: "#FF3DCB")
    /// Переливающийся градиент в духе референса: циан → синий → фиолетовый → маджента.
    static var iris: LinearGradient {
        LinearGradient(colors: [cyan, blue, violet, magenta], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if h.count == 6 { h += "FF" }
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(.sRGB,
                  red: Double((v >> 24) & 255) / 255,
                  green: Double((v >> 16) & 255) / 255,
                  blue: Double((v >> 8) & 255) / 255,
                  opacity: Double(v & 255) / 255)
    }
    var hex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
    }
}

struct Glass: ViewModifier {
    var radius: CGFloat
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(.white.opacity(0.10), lineWidth: 1))
    }
}
extension View {
    func glass(_ radius: CGFloat = 22) -> some View { modifier(Glass(radius: radius)) }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            Theme.bg
            Circle().fill(Theme.violet.opacity(0.35)).frame(width: 320).blur(radius: 90).offset(x: -130, y: -280)
            Circle().fill(Theme.cyan.opacity(0.22)).frame(width: 300).blur(radius: 100).offset(x: 160, y: 320)
        }
        .ignoresSafeArea()
    }
}
