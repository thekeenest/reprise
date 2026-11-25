import SwiftUI
import AppKit
import RepriseCore

/// Three looks, one app. Each is a complete visual direction, switchable live (⌘⇧L).
enum Look: String, CaseIterable, Identifiable {
    case liquid = "Liquid"   // clear glass over a soft aura — the macOS 26 native feel
    case tinted = "Tinted"   // glass tinted by the current project's color
    case ink = "Ink"         // dense, dark, terminal-adjacent — for the Ghostty crowd
    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .liquid: return "Clear glass over a soft aura"
        case .tinted: return "Glass takes on each project's color"
        case .ink: return "Dark, dense, terminal-native"
        }
    }
}

enum EditorFont: String, CaseIterable, Identifiable {
    case mono = "Mono", sans = "Sans", serif = "Serif"
    var id: String { rawValue }

    func nsFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        switch self {
        case .mono: return .monospacedSystemFont(ofSize: size, weight: weight)
        case .sans: return .systemFont(ofSize: size, weight: weight)
        case .serif:
            let base = NSFont.systemFont(ofSize: size, weight: weight)
            if let d = base.fontDescriptor.withDesign(.serif), let f = NSFont(descriptor: d, size: size) { return f }
            return base
        }
    }
}

extension Color {
    init(hex: String) {
        let c = Palette.rgb(hex)
        self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: 1)
    }

    var hexString: String {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return "#888888" }
        return Palette.hex(.init(r: Double(c.redComponent), g: Double(c.greenComponent), b: Double(c.blueComponent)))
    }
}

extension NSColor {
    convenience init(hex: String) {
        let c = Palette.rgb(hex)
        self.init(srgbRed: c.r, green: c.g, blue: c.b, alpha: 1)
    }
}

/// The soft, slowly breathing color field that sits behind the glass.
/// Glass needs something to refract — this is what makes Liquid Glass look alive.
struct Aura: View {
    var color: Color
    var look: Look
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        switch look {
        case .ink:
            LinearGradient(colors: [Color(white: 0.07), Color(white: 0.035)], startPoint: .top, endPoint: .bottom)
                .overlay(alignment: .topTrailing) {
                    RadialGradient(colors: [color.opacity(0.18), .clear], center: .topTrailing, startRadius: 0, endRadius: 520)
                }
        case .liquid, .tinted:
            let strength = look == .tinted ? 0.55 : 0.32
            let base: Color = scheme == .dark ? Color(white: 0.09) : Color(white: 0.965)
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.62, 0.42], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ], colors: [
                color.opacity(strength), base, color.opacity(strength * 0.6),
                base, color.opacity(strength * 0.35), base,
                color.opacity(strength * 0.5), base, color.opacity(strength * 0.8),
            ])
            .background(base)
        }
    }
}

struct ColorDot: View {
    var hex: String
    var size: CGFloat = 10
    var body: some View {
        Circle()
            .fill(Color(hex: hex).gradient)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
            .shadow(color: Color(hex: hex).opacity(0.5), radius: size * 0.3)
    }
}

extension View {
    /// Glass for the Liquid/Tinted looks, a quiet solid surface for Ink.
    @ViewBuilder
    func surface(_ look: Look, tint: Color? = nil, radius: CGFloat = 16, interactive: Bool = false) -> some View {
        switch look {
        case .ink:
            self.background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color.white.opacity(0.045)))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
        case .liquid:
            self.glassEffect(interactive ? .regular.interactive() : .regular, in: .rect(cornerRadius: radius))
        case .tinted:
            self.glassEffect((interactive ? Glass.regular.interactive() : .regular).tint(tint?.opacity(0.22)), in: .rect(cornerRadius: radius))
        }
    }
}

extension Date {
    var relative: String {
        let s = -timeIntervalSinceNow
        if s < 60 { return "now" }
        if s < 3600 { return "\(Int(s / 60))m" }
        if s < 86400 { return "\(Int(s / 3600))h" }
        if s < 86400 * 7 { return "\(Int(s / 86400))d" }
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: self)
    }
}
