import SwiftUI
import AppKit
import RepriseCore

// MARK: Worlds

/// A complete design. Reprise ships three, and they differ in structure, not just in color:
/// Console is launcher-first, Board is spatial, Studio is editor-first.
/// Each release build picks its design from Info.plist (`RepriseWorld`); Settings can switch live.
enum World: String, CaseIterable, Identifiable {
    /// Launcher-first: one search field, results, a run panel, an action bar. No sidebar.
    case console = "Console"
    /// Spatial: spaces as tabs, projects as columns, prompts as tiles. Run and edit in focused overlays.
    case board = "Board"
    /// Editor-first: prompts open in tabs, the library is a palette, a run inspector on the right.
    case studio = "Studio"

    var id: String { rawValue }

    private(set) static var current: World = {
        if let raw = UserDefaults.standard.string(forKey: "world"), let w = World(rawValue: raw) { return w }
        if let raw = Bundle.main.object(forInfoDictionaryKey: "RepriseWorld") as? String, let w = World(rawValue: raw) { return w }
        return .console
    }()

    static func set(_ w: World) {
        current = w
        UserDefaults.standard.set(w.rawValue, forKey: "world")
        NotificationCenter.default.post(name: .worldDidChange, object: nil)
    }

    var style: Style {
        switch self {
        case .console: return .console
        case .board: return .board
        case .studio: return .studio
        }
    }

    var blurb: String {
        switch self {
        case .console: return "Launcher-first. Search, fill, copy. No sidebar."
        case .board: return "Spatial. Projects as columns, prompts as tiles."
        case .studio: return "Editor-first. Prompts in tabs, a run inspector beside the page."
        }
    }
}

extension Notification.Name {
    static let worldDidChange = Notification.Name("reprise.worldDidChange")
}

/// Everything a design decides about surface. Views never hard-code a color, face or radius.
struct Style {
    struct Pair { var light: String; var dark: String }

    var paper, paperDeep, raised, ink, slate, ash, accent: Pair
    /// The primary button: its fill and its label.
    var fill, onFill: Pair
    var ruleAlpha: (light: CGFloat, dark: CGFloat)
    var washAlpha: (light: CGFloat, dark: CGFloat)

    var textDesign: Font.Design
    var titleSize: CGFloat
    var titleWeight: Font.Weight
    var titleTracking: CGFloat
    var entryWeight: Font.Weight

    enum Labels { case smallCaps, uppercase, plain }
    var labels: Labels
    var labelTracking: CGFloat
    var labelWeight: Font.Weight

    var radius: CGFloat
    enum Keys { case letters, numberCaps, roman }
    var keys: Keys
    enum Selection { case bracket, fill, accentTitle }
    var selection: Selection
    var detent: Bool
    var primaryFilled: Bool

    var editorFont: EditorFont
    var editorSize: Double
    var lineHeight: CGFloat

    /// Console: cool graphite, one coral signal, Raycast-grade density.
    static let console = Style(
        paper: .init(light: "#F7F7F8", dark: "#111113"),
        paperDeep: .init(light: "#EEEEF0", dark: "#0B0B0C"),
        raised: .init(light: "#FFFFFF", dark: "#18181B"),
        ink: .init(light: "#18181B", dark: "#EDEDEF"),
        slate: .init(light: "#5E5E66", dark: "#9A9AA3"),
        ash: .init(light: "#A1A1AA", dark: "#5C5C63"),
        accent: .init(light: "#E5532F", dark: "#FF7452"),
        fill: .init(light: "#E5532F", dark: "#FF6A45"),
        onFill: .init(light: "#FFFFFF", dark: "#160B07"),
        ruleAlpha: (0.1, 0.09), washAlpha: (0.04, 0.05),
        textDesign: .default, titleSize: 22, titleWeight: .semibold, titleTracking: -0.3, entryWeight: .regular,
        labels: .plain, labelTracking: 0, labelWeight: .medium,
        radius: 8, keys: .numberCaps, selection: .fill, detent: false, primaryFilled: true,
        editorFont: .sans, editorSize: 14, lineHeight: 1.5)

    /// Board: monochrome near-black, white primary, one mint for blanks.
    static let board = Style(
        paper: .init(light: "#FBFBFA", dark: "#0E0F10"),
        paperDeep: .init(light: "#F2F2F0", dark: "#08090A"),
        raised: .init(light: "#FFFFFF", dark: "#161719"),
        ink: .init(light: "#141516", dark: "#F2F3F3"),
        slate: .init(light: "#62666D", dark: "#8B9097"),
        ash: .init(light: "#A3A7AD", dark: "#565A60"),
        accent: .init(light: "#0F8F5F", dark: "#5EE0A8"),
        fill: .init(light: "#141516", dark: "#F2F3F3"),
        onFill: .init(light: "#FFFFFF", dark: "#0E0F10"),
        ruleAlpha: (0.09, 0.08), washAlpha: (0.035, 0.045),
        textDesign: .default, titleSize: 24, titleWeight: .semibold, titleTracking: -0.5, entryWeight: .medium,
        labels: .uppercase, labelTracking: 0.8, labelWeight: .semibold,
        radius: 10, keys: .letters, selection: .fill, detent: false, primaryFilled: true,
        editorFont: .sans, editorSize: 14.5, lineHeight: 1.55)

    /// Studio: warm iron and bone, New York titles, one vermilion. The Edition's heir.
    static let studio = Style(
        paper: .init(light: "#F3F1EB", dark: "#161514"),
        paperDeep: .init(light: "#EAE7DF", dark: "#0F0E0D"),
        raised: .init(light: "#FBFAF6", dark: "#1D1C1A"),
        ink: .init(light: "#1B1A18", dark: "#ECE9E1"),
        slate: .init(light: "#5F5D57", dark: "#A6A39B"),
        ash: .init(light: "#98958C", dark: "#6F6C65"),
        accent: .init(light: "#B8321F", dark: "#EF6A52"),
        fill: .init(light: "#B8321F", dark: "#E85A40"),
        onFill: .init(light: "#FFFFFF", dark: "#FFFFFF"),
        ruleAlpha: (0.16, 0.12), washAlpha: (0.045, 0.05),
        textDesign: .serif, titleSize: 28, titleWeight: .regular, titleTracking: 0, entryWeight: .regular,
        labels: .smallCaps, labelTracking: 0.8, labelWeight: .medium,
        radius: 4, keys: .letters, selection: .bracket, detent: true, primaryFilled: true,
        editorFont: .serif, editorSize: 15, lineHeight: 1.45)
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

/// Design tokens, resolved against the current world and the view's appearance at draw time.
enum Folio {
    private static func dyn(_ pick: @escaping (Style) -> Style.Pair, alpha: ((Style) -> (CGFloat, CGFloat))? = nil) -> NSColor {
        NSColor(name: nil) { ap in
            let s = World.current.style
            let dark = ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let p = pick(s)
            let a = alpha?(s)
            return NSColor(hex: dark ? p.dark : p.light).withAlphaComponent(a.map { dark ? $0.1 : $0.0 } ?? 1)
        }
    }

    static let nsPaper = dyn { $0.paper }
    static let nsPaperDeep = dyn { $0.paperDeep }
    static let nsRaised = dyn { $0.raised }
    static let nsFill = dyn { $0.fill }
    static let nsOnFill = dyn { $0.onFill }
    static let nsInk = dyn { $0.ink }
    static let nsSlate = dyn { $0.slate }
    static let nsAsh = dyn { $0.ash }
    static let nsRule = dyn({ $0.ink }, alpha: { ($0.ruleAlpha.light, $0.ruleAlpha.dark) })
    static let nsRubric = dyn { $0.accent }
    static let nsWash = dyn({ $0.ink }, alpha: { ($0.washAlpha.light, $0.washAlpha.dark) })
    static let nsSelection = dyn({ $0.accent }, alpha: { _ in (0.16, 0.28) })
    static let nsAccentSoft = dyn({ $0.accent }, alpha: { _ in (0.35, 0.4) })
    static let nsOnAccent = NSColor(name: nil) { ap in
        ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: "#141416") : .white
    }

    static let paper = Color(nsColor: nsPaper)
    static let paperDeep = Color(nsColor: nsPaperDeep)
    /// Surfaces that sit above the ground: fields, tiles, cards, the run panel.
    static let raised = Color(nsColor: nsRaised)
    static let fill = Color(nsColor: nsFill)
    static let onFill = Color(nsColor: nsOnFill)
    static let ink = Color(nsColor: nsInk)
    static let slate = Color(nsColor: nsSlate)
    static let ash = Color(nsColor: nsAsh)
    static let rule = Color(nsColor: nsRule)
    /// The world's one accent (rubric, signal orange, ink blue). Only for blanks and playing.
    static let rubric = Color(nsColor: nsRubric)
    static let wash = Color(nsColor: nsWash)
    static let onAccent = Color(nsColor: nsOnAccent)

    static var style: Style { World.current.style }
    static var radius: CGFloat { style.radius }

    /// Blank keys in the world's numbering: A B C, 1 2 3, or i ii iii.
    static func key(_ i: Int) -> String {
        switch style.keys {
        case .letters:
            let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
            return i < 26 ? String(letters[i]) : String(letters[i / 26 - 1]) + String(letters[i % 26])
        case .numberCaps:
            return String(i + 1)
        case .roman:
            return roman(i + 1).lowercased()
        }
    }

    private static func roman(_ n: Int) -> String {
        let table: [(Int, String)] = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"),
                                      (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var n = n, out = ""
        for (v, s) in table { while n >= v { out += s; n -= v } }
        return out
    }
}

extension Font {
    /// The caption voice: small caps (Edition) or tracked capitals (Machined, Quiet).
    static func apparatus(_ size: CGFloat = 10.5, weight: Font.Weight? = nil) -> Font {
        let s = Folio.style
        let f = Font.system(size: s.labels == .uppercase ? size * 0.9 : size + (s.labels == .plain ? 1 : 0), weight: weight ?? s.labelWeight)
        return s.labels == .smallCaps ? f.lowercaseSmallCaps() : f
    }
    /// The text voice: New York in Edition, SF Pro elsewhere.
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
        let s = Folio.style
        Text(s.labels == .smallCaps ? text.lowercased() : s.labels == .uppercase ? text.uppercased() : text)
            .font(.apparatus(size))
            .tracking(s.labelTracking)
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

/// Edition's section mark: a rule with a small rubric detent. Other worlds draw a plain rule.
struct DetentRule: View {
    var body: some View {
        if Folio.style.detent {
            HStack(spacing: 6) {
                Hairline()
                Rectangle().fill(Folio.rubric).frame(width: 4, height: 4)
                Hairline()
            }
        } else {
            Hairline()
        }
    }
}

/// The key beside each blank, matching the accent placeholders in the text.
struct BlankKey: View {
    var index: Int
    var body: some View {
        switch Folio.style.keys {
        case .letters:
            Text(Folio.key(index))
                .font(.text(12, weight: .semibold))
                .foregroundStyle(Folio.rubric)
                .frame(width: 16, alignment: .leading)
        case .numberCaps:
            Text(Folio.key(index))
                .font(.system(size: 10, weight: .bold).monospacedDigit())
                .foregroundStyle(Folio.onFill)
                .frame(width: 16, height: 16)
                .background(Folio.fill, in: RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 4 }
        case .roman:
            Text(Folio.key(index))
                .font(.system(size: 12, weight: .regular, design: .serif).italic())
                .foregroundStyle(Folio.rubric)
                .frame(width: 22, alignment: .leading)
        }
    }
}

/// Selection treatment for index rows: Edition brackets, Machined fills, Quiet colors the title.
struct SelectionBackground: View {
    var selected: Bool
    var active: Bool
    var hovering: Bool
    var body: some View {
        let s = Folio.style
        let shape = RoundedRectangle(cornerRadius: s.radius, style: .continuous)
        Group {
            if selected {
                switch s.selection {
                case .bracket:
                    shape.fill(Folio.wash).overlay(shape.strokeBorder(active ? Folio.rubric : Folio.rule, lineWidth: 1))
                case .fill:
                    shape.fill(Folio.ink.opacity(active ? 0.09 : 0.06))
                case .accentTitle:
                    shape.fill(Folio.wash)
                }
            } else if hovering {
                shape.fill(Folio.wash.opacity(0.6))
            }
        }
        .padding(.horizontal, 6)
    }
}

/// The world's primary-action treatment outside the toolbar.
struct PrimaryLabel: View {
    var title: String
    var shortcut: String
    var body: some View {
        let s = Folio.style
        let shape = RoundedRectangle(cornerRadius: s.radius, style: .continuous)
        HStack {
            Text(title)
            Spacer()
            Text(shortcut).font(.system(size: 11).monospacedDigit()).opacity(0.8)
        }
        .font(.system(size: 12.5, weight: .medium))
        .foregroundStyle(s.primaryFilled ? Folio.onFill : Folio.rubric)
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background { if s.primaryFilled { shape.fill(Folio.fill) } }
        .overlay { if !s.primaryFilled { shape.strokeBorder(Folio.rubric, lineWidth: 1) } }
        .contentShape(shape)
    }
}

/// Project and prompt identity: a small square key. Never a gradient, never a glow.
struct ColorKey: View {
    var hex: String
    var size: CGFloat = 7
    var body: some View {
        RoundedRectangle(cornerRadius: Folio.radius > 0 ? size * 0.28 : 0, style: .continuous)
            .fill(Color(hex: hex))
            .frame(width: size, height: size)
    }
}

/// The window ground. Dynamic colors follow the theme; there is no tinted glass.
struct Ground: View {
    var look: Look = .dark
    var deep = false
    var body: some View { deep ? Folio.paperDeep : Folio.paper }
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

/// A bordered key cap for shortcut hints.
struct KeyCap: View {
    var key: String
    var body: some View {
        Text(key)
            .font(.system(size: 10.5, weight: .medium).monospacedDigit())
            .foregroundStyle(Folio.ink)
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 17)
            .overlay(RoundedRectangle(cornerRadius: min(Folio.radius, 4), style: .continuous).strokeBorder(Folio.rule, lineWidth: 1))
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

    /// "Auto" (empty) follows the world's typeface.
    static func resolve(_ raw: String) -> EditorFont { EditorFont(rawValue: raw) ?? World.current.style.editorFont }
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
