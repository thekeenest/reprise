import SwiftUI
import AppKit
import RepriseCore

// MARK: Variants

/// Reprise has one structure and a few finishes. Each release build picks its defaults from
/// Info.plist (`RepriseFinish`, `RepriseAccent`, `RepriseLibrary`); Settings switches them live.
enum Finish: String, CaseIterable, Identifiable {
    /// Opaque warm-iron surfaces separated by hairlines.
    case solid = "Solid"
    /// Floating Liquid Glass panes over the desktop, with gradient fills and lit edges.
    case glass = "Glass"
    var id: String { rawValue }
    var blurb: String {
        self == .solid ? "Opaque surfaces, hairline dividers." : "Floating translucent panes over your desktop."
    }
}

enum Accent: String, CaseIterable, Identifiable {
    case coral = "Coral"
    case wine = "Wine"
    var id: String { rawValue }
    /// (light, dark) for text-level accent, and for filled buttons.
    var text: Style.Pair { self == .coral ? .init(light: "#B8321F", dark: "#EF6A52") : .init(light: "#8E1F38", dark: "#D0566B") }
    var fill: Style.Pair { self == .coral ? .init(light: "#C2381F", dark: "#E85A40") : .init(light: "#7D1A2E", dark: "#8E2236") }
}

enum LibraryLayout: String, CaseIterable, Identifiable {
    /// Sidebar of spaces and projects, then a list of prompts. Notes-style.
    case columns = "Columns"
    /// One outline: spaces, projects and their prompts in a single tree. More room for the page.
    case outline = "Outline"
    var id: String { rawValue }
    var name: String { self == .columns ? "Two columns" : "One column" }
}

enum Variant {
    private static func read<T: RawRepresentable>(_ key: String, _ plist: String, _ fallback: T) -> T where T.RawValue == String {
        if let raw = UserDefaults.standard.string(forKey: key), let v = T(rawValue: raw) { return v }
        if let raw = Bundle.main.object(forInfoDictionaryKey: plist) as? String, let v = T(rawValue: raw) { return v }
        return fallback
    }

    private(set) static var finish: Finish = read("finish", "RepriseFinish", Finish.solid)
    private(set) static var accent: Accent = read("accent", "RepriseAccent", Accent.coral)
    private(set) static var library: LibraryLayout = read("libraryLayout", "RepriseLibrary", LibraryLayout.columns)

    static var glass: Bool { finish == .glass }

    static func set(finish f: Finish) { finish = f; UserDefaults.standard.set(f.rawValue, forKey: "finish"); changed() }
    static func set(accent a: Accent) { accent = a; UserDefaults.standard.set(a.rawValue, forKey: "accent"); changed() }
    static func set(library l: LibraryLayout) { library = l; UserDefaults.standard.set(l.rawValue, forKey: "libraryLayout"); changed() }

    /// Changes whenever any variant changes; views key their identity on it.
    static var signature: String { "\(finish.rawValue)-\(accent.rawValue)-\(library.rawValue)" }

    private static func changed() { NotificationCenter.default.post(name: .variantDidChange, object: nil) }
}

extension Notification.Name {
    static let variantDidChange = Notification.Name("reprise.variantDidChange")
}

/// Everything about surface. Views never hard-code a color, face or radius.
struct Style {
    struct Pair { var light: String; var dark: String }

    var paper, paperMid, paperDeep, raised, ink, slate, ash: Pair
    var onFill: Pair
    var ruleAlpha: (light: CGFloat, dark: CGFloat)
    var washAlpha: (light: CGFloat, dark: CGFloat)

    var textDesign: Font.Design = .serif
    var titleSize: CGFloat = 28
    var titleWeight: Font.Weight = .regular
    var titleTracking: CGFloat = 0
    var entryWeight: Font.Weight = .regular
    var labelTracking: CGFloat = 0.8
    var labelWeight: Font.Weight = .medium
    var radius: CGFloat = 8
    var detent = true
    var editorFont: EditorFont = .serif
    var editorSize: Double = 15
    var lineHeight: CGFloat = 1.45

    /// Warm iron and bone, New York for the page and titles, SF for controls.
    static let base = Style(
        paper: .init(light: "#F7F5F0", dark: "#161514"),
        paperMid: .init(light: "#F1EEE8", dark: "#131211"),
        paperDeep: .init(light: "#EAE7E0", dark: "#0F0E0D"),
        raised: .init(light: "#FFFFFF", dark: "#1F1E1C"),
        ink: .init(light: "#1B1A18", dark: "#ECE9E1"),
        slate: .init(light: "#5F5D57", dark: "#A6A39B"),
        ash: .init(light: "#98958C", dark: "#6F6C65"),
        onFill: .init(light: "#FFFFFF", dark: "#FFFFFF"),
        ruleAlpha: (0.12, 0.10), washAlpha: (0.045, 0.055))
}

/// The theme setting. Dark is the default in every design.
enum Look: String, CaseIterable, Identifiable {
    case dark = "Dark"
    case light = "Light"
    case system = "System"
    var id: String { rawValue }

    var name: String { self == .system ? "Match System" : rawValue }

    var scheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }

    static func stored(_ raw: String?) -> Look { raw.flatMap(Look.init(rawValue:)) ?? .dark }
}

// MARK: Tokens

/// Design tokens, resolved against the current variant and the view's appearance at draw time.
enum Folio {
    private static func dyn(_ pick: @escaping () -> Style.Pair, alpha: (CGFloat, CGFloat)? = nil) -> NSColor {
        NSColor(name: nil) { ap in
            let dark = ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let p = pick()
            return NSColor(hex: dark ? p.dark : p.light).withAlphaComponent(alpha.map { dark ? $0.1 : $0.0 } ?? 1)
        }
    }
    private static var s: Style { .base }

    static let nsPaper = dyn { s.paper }
    static let nsPaperMid = dyn { s.paperMid }
    static let nsPaperDeep = dyn { s.paperDeep }
    static let nsRaised = dyn { s.raised }
    static let nsFill = dyn { Variant.accent.fill }
    static let nsOnFill = dyn { s.onFill }
    static let nsInk = dyn { s.ink }
    static let nsSlate = dyn { s.slate }
    static let nsAsh = dyn { s.ash }
    static let nsRule = dyn({ s.ink }, alpha: (s.ruleAlpha.light, s.ruleAlpha.dark))
    static let nsRubric = dyn { Variant.accent.text }
    static let nsWash = dyn({ s.ink }, alpha: (s.washAlpha.light, s.washAlpha.dark))
    static let nsSelection = dyn({ Variant.accent.text }, alpha: (0.16, 0.28))
    static let nsAccentSoft = dyn({ Variant.accent.text }, alpha: (0.35, 0.4))

    static let paper = Color(nsColor: nsPaper)
    static let paperMid = Color(nsColor: nsPaperMid)
    static let paperDeep = Color(nsColor: nsPaperDeep)
    /// Surfaces that sit above the ground: fields, menus, cards.
    static let raised = Color(nsColor: nsRaised)
    static let fill = Color(nsColor: nsFill)
    static let onFill = Color(nsColor: nsOnFill)
    static let ink = Color(nsColor: nsInk)
    static let slate = Color(nsColor: nsSlate)
    static let ash = Color(nsColor: nsAsh)
    static let rule = Color(nsColor: nsRule)
    /// The one accent. Only for blanks, the caret, the primary buttons and the current selection.
    static let rubric = Color(nsColor: nsRubric)
    static let wash = Color(nsColor: nsWash)

    static var style: Style { .base }
    static var radius: CGFloat { Variant.glass ? 10 : style.radius }
}

extension Font {
    /// The caption voice: SF small caps, tracked.
    static func apparatus(_ size: CGFloat = 10.5, weight: Font.Weight? = nil) -> Font {
        Font.system(size: size, weight: weight ?? Folio.style.labelWeight).lowercaseSmallCaps()
    }
    /// The text voice: New York.
    static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: Folio.style.textDesign)
    }
    static var title: Font {
        let s = Folio.style
        return .system(size: s.titleSize, weight: s.titleWeight, design: s.textDesign)
    }
}

// MARK: Components

/// A caption for the margin and headers.
struct Caps: View {
    var text: String
    var color: Color = Folio.slate
    var size: CGFloat = 10.5
    init(_ text: String, color: Color = Folio.slate, size: CGFloat = 10.5) {
        self.text = text; self.color = color; self.size = size
    }
    var body: some View {
        Text(text.lowercased())
            .font(.apparatus(size))
            .tracking(Folio.style.labelTracking)
            .foregroundStyle(color)
    }
}

/// A one-pixel rule, the only divider in the system.
struct Hairline: View {
    /// One device pixel.
    static var px: CGFloat { 1 / (NSScreen.main?.backingScaleFactor ?? 2) }
    var vertical = false
    var color: Color = Folio.rule
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: vertical ? Hairline.px : nil, height: vertical ? nil : Hairline.px)
    }
}

/// The section mark under the title: a rule with a small accent detent.
struct DetentRule: View {
    var body: some View {
        if Folio.style.detent {
            HStack(spacing: 6) {
                Hairline()
                Circle().fill(Folio.rubric).frame(width: 4, height: 4)
                Hairline()
            }
        } else {
            Hairline()
        }
    }
}

/// Selection for list rows: a soft rounded fill, accent-tinted while the list has focus.
struct SelectionBackground: View {
    var selected: Bool
    var active: Bool
    var hovering: Bool
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Folio.radius, style: .continuous)
        Group {
            if selected {
                shape.fill(Folio.ink.opacity(active ? 0.1 : 0.07))
            } else if hovering {
                shape.fill(Folio.wash)
            }
        }
        .padding(.horizontal, 6)
    }
}

/// Project and prompt identity: a small square key. Never a gradient, never a glow.
struct ColorKey: View {
    var hex: String
    var size: CGFloat = 7
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(Color(hex: hex))
            .frame(width: size, height: size)
    }
}

struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .followsWindowActiveState
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) { v.material = material }
}

/// A surface region of the window. Solid: a flat ground. Glass: a floating pane with a
/// top-lit gradient fill, a lit edge and a soft shadow, over the blurred desktop.
struct PaneBackground: View {
    enum Tone { case deep, mid, page }
    var tone: Tone
    var body: some View {
        if Variant.glass {
            GlassPane(strong: tone == .page)
        } else {
            switch tone {
            case .deep: Folio.paperDeep
            case .mid: Folio.paperMid
            case .page: Folio.paper
            }
        }
    }
}

struct GlassPane: View {
    var strong = false
    var radius: CGFloat = 18
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let dark = scheme == .dark
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape
            .fill(LinearGradient(colors: dark
                                 ? [.white.opacity(strong ? 0.085 : 0.065), .white.opacity(strong ? 0.035 : 0.022)]
                                 : [.white.opacity(strong ? 0.62 : 0.48), .white.opacity(strong ? 0.42 : 0.3)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(shape.strokeBorder(LinearGradient(colors: dark
                                                       ? [.white.opacity(0.22), .white.opacity(0.04)]
                                                       : [.white.opacity(0.9), .white.opacity(0.35)],
                                                       startPoint: .top, endPoint: .bottom), lineWidth: 1))
            .shadow(color: .black.opacity(dark ? 0.28 : 0.08), radius: 18, y: 8)
    }
}

/// The window ground. Solid: the deepest paper. Glass: the desktop, blurred and toned down.
struct WindowGround: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        if Variant.glass {
            ZStack {
                VisualEffect(material: scheme == .dark ? .hudWindow : .underWindowBackground)
                LinearGradient(colors: scheme == .dark
                               ? [Color.black.opacity(0.42), Color.black.opacity(0.62)]
                               : [Color.white.opacity(0.10), Color.white.opacity(0.28)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                // A breath of the accent from one corner, as in the reference.
                RadialGradient(colors: [Folio.fill.opacity(scheme == .dark ? 0.22 : 0.10), .clear],
                               center: .bottomLeading, startRadius: 0, endRadius: 760)
                RadialGradient(colors: [Color.white.opacity(scheme == .dark ? 0.05 : 0.12), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 640)
            }
        } else {
            Folio.paperDeep
        }
    }
}

/// A bordered key cap for shortcut hints.
struct KeyCap: View {
    var key: String
    var body: some View {
        Text(key)
            .font(.system(size: 10.5, weight: .medium).monospacedDigit())
            .foregroundStyle(Folio.ink)
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 17)
            .overlay(RoundedRectangle(cornerRadius: 4.5, style: .continuous).strokeBorder(Folio.rule, lineWidth: 1))
    }
}

enum EditorFont: String, CaseIterable, Identifiable {
    case serif = "Serif", sans = "Sans", mono = "Mono"
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

    /// "Auto" (empty) is New York.
    static func resolve(_ raw: String) -> EditorFont { EditorFont(rawValue: raw) ?? Folio.style.editorFont }
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

extension Date {
    var relative: String {
        let s = -timeIntervalSinceNow
        if s < 60 { return "now" }
        if s < 3600 { return "\(Int(s / 60)) min" }
        if s < 86400 { return "\(Int(s / 3600)) h" }
        if s < 86400 * 7 { return "\(Int(s / 86400)) d" }
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: self)
    }
}

/// `@AppStorage("theme")`. Dark unless the person chose otherwise.
@propertyWrapper
struct LookSetting: DynamicProperty {
    @AppStorage("theme") private var raw: String = Look.dark.rawValue
    var wrappedValue: Look {
        get { Look.stored(raw) }
        nonmutating set { raw = newValue.rawValue }
    }
    var projectedValue: Binding<Look> {
        Binding(get: { Look.stored(raw) }, set: { raw = $0.rawValue })
    }
}
