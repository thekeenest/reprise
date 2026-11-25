import SwiftUI
import AppKit
import RepriseCore

// MARK: Worlds

/// A complete visual world. Reprise ships three, each with a light, a dark and a glass look.
/// One codebase; each release build picks its default world from Info.plist (`RepriseWorld`),
/// and Settings → Appearance can switch worlds live.
enum World: String, CaseIterable, Identifiable {
    /// A reference edition: New York on bone paper, hairline rules, one rubric red.
    case edition = "Edition"
    /// A precision instrument: aluminum and graphite, SF Pro, signal orange, numbered key caps.
    case machined = "Machined"
    /// A record sleeve: warm gray, light large type, wide-tracked captions, one ink blue.
    case quiet = "Quiet"

    var id: String { rawValue }

    /// The world in force. Read once at launch, then changed only through `set(_:)`.
    private(set) static var current: World = {
        if let raw = UserDefaults.standard.string(forKey: "world"), let w = World(rawValue: raw) { return w }
        if let raw = Bundle.main.object(forInfoDictionaryKey: "RepriseWorld") as? String, let w = World(rawValue: raw) { return w }
        return .edition
    }()

    static func set(_ w: World) {
        current = w
        UserDefaults.standard.set(w.rawValue, forKey: "world")
        NotificationCenter.default.post(name: .worldDidChange, object: nil)
    }

    var style: Style {
        switch self {
        case .edition: return .edition
        case .machined: return .machined
        case .quiet: return .quiet
        }
    }

    var blurb: String {
        switch self {
        case .edition: return "A reference edition. Serif text, hairline rules, one rubric red."
        case .machined: return "A precision instrument. Aluminum, graphite, signal orange."
        case .quiet: return "A record sleeve. Warm gray, light type, one ink blue."
        }
    }
}

extension Notification.Name {
    static let worldDidChange = Notification.Name("reprise.worldDidChange")
}

/// Everything a world decides. Views never hard-code a color, face or radius; they ask the style.
struct Style {
    struct Pair { var light: String; var dark: String }

    var paper, paperDeep, ink, slate, ash, accent: Pair
    var ruleAlpha: (light: CGFloat, dark: CGFloat)
    var washAlpha: (light: CGFloat, dark: CGFloat)

    var textDesign: Font.Design          // titles and index entries
    var titleSize: CGFloat
    var titleWeight: Font.Weight
    var titleTracking: CGFloat
    var entryWeight: Font.Weight

    enum Labels { case smallCaps, uppercase }
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
    var lookNames: [Look: String]
    var lookSubtitles: [Look: String]

    static let edition = Style(
        paper: .init(light: "#F3F1EB", dark: "#151514"),
        paperDeep: .init(light: "#EAE7DF", dark: "#1C1C1A"),
        ink: .init(light: "#1B1A18", dark: "#ECE9E1"),
        slate: .init(light: "#5F5D57", dark: "#A6A39B"),
        ash: .init(light: "#98958C", dark: "#6F6C65"),
        accent: .init(light: "#B8321F", dark: "#EF6A52"),
        ruleAlpha: (0.24, 0.2), washAlpha: (0.045, 0.055),
        textDesign: .serif, titleSize: 30, titleWeight: .regular, titleTracking: 0, entryWeight: .regular,
        labels: .smallCaps, labelTracking: 0.9, labelWeight: .medium,
        radius: 0, keys: .letters, selection: .bracket, detent: true, primaryFilled: false,
        editorFont: .serif, editorSize: 15, lineHeight: 1.42,
        lookNames: [.bone: "Bone", .iron: "Iron", .vellum: "Vellum"],
        lookSubtitles: [.bone: "Ink on unbleached paper", .iron: "Bone ink on iron", .vellum: "Translucent; follows the system"])

    static let machined = Style(
        paper: .init(light: "#EBEBE8", dark: "#18181A"),
        paperDeep: .init(light: "#E0E0DC", dark: "#111113"),
        ink: .init(light: "#141416", dark: "#EEEEEB"),
        slate: .init(light: "#5A5A5F", dark: "#A0A0A5"),
        ash: .init(light: "#9B9BA0", dark: "#66666B"),
        accent: .init(light: "#E5470E", dark: "#FF6A2B"),
        ruleAlpha: (0.13, 0.13), washAlpha: (0.06, 0.07),
        textDesign: .default, titleSize: 27, titleWeight: .semibold, titleTracking: -0.5, entryWeight: .medium,
        labels: .uppercase, labelTracking: 1.1, labelWeight: .semibold,
        radius: 6, keys: .numberCaps, selection: .fill, detent: false, primaryFilled: true,
        editorFont: .sans, editorSize: 14, lineHeight: 1.4,
        lookNames: [.bone: "Aluminum", .iron: "Graphite", .vellum: "Glass"],
        lookSubtitles: [.bone: "Bead-blasted aluminum", .iron: "Graphite, for late sessions", .vellum: "Translucent; follows the system"])

    static let quiet = Style(
        paper: .init(light: "#ECEAE5", dark: "#1A1A19"),
        paperDeep: .init(light: "#E3E0DA", dark: "#141413"),
        ink: .init(light: "#232321", dark: "#E6E4DF"),
        slate: .init(light: "#6B6862", dark: "#9D9A93"),
        ash: .init(light: "#A3A098", dark: "#64625D"),
        accent: .init(light: "#2D5A8A", dark: "#86AEDB"),
        ruleAlpha: (0.14, 0.14), washAlpha: (0.04, 0.05),
        textDesign: .default, titleSize: 34, titleWeight: .light, titleTracking: -0.3, entryWeight: .regular,
        labels: .uppercase, labelTracking: 1.7, labelWeight: .regular,
        radius: 2, keys: .roman, selection: .accentTitle, detent: false, primaryFilled: false,
        editorFont: .sans, editorSize: 14.5, lineHeight: 1.55,
        lookNames: [.bone: "Day", .iron: "Night", .vellum: "Haze"],
        lookSubtitles: [.bone: "Warm gray board", .iron: "Charcoal sleeve", .vellum: "Translucent; follows the system"])
}

/// Light, dark, and glass. Names come from the world ("Bone", "Aluminum", "Day"…).
enum Look: String, CaseIterable, Identifiable {
    case bone = "Bone"
    case iron = "Iron"
    case vellum = "Vellum"
    var id: String { rawValue }

    var name: String { World.current.style.lookNames[self] ?? rawValue }
    var subtitle: String { World.current.style.lookSubtitles[self] ?? "" }

    var scheme: ColorScheme? {
        switch self {
        case .bone: return .light
        case .iron: return .dark
        case .vellum: return nil
        }
    }

    /// Accepts values stored by 0.1 ("Liquid", "Tinted", "Ink").
    static func stored(_ raw: String?) -> Look {
        switch raw {
        case "Ink": return .iron
        case "Liquid", "Tinted": return .bone
        default: return raw.flatMap(Look.init(rawValue:)) ?? .bone
        }
    }
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
    static let ink = Color(nsColor: nsInk)
    static let slate = Color(nsColor: nsSlate)
    static let ash = Color(nsColor: nsAsh)
    static let rule = Color(nsColor: nsRule)
    /// The world's one accent (rubric, signal orange, ink blue). Only for blanks and playing.
    static let rubric = Color(nsColor: nsRubric)
    static let wash = Color(nsColor: nsWash)
    static let onAccent = Color(nsColor: nsOnAccent)

    static var style: Style { World.current.style }
    /// Filled controls use the deep accent in both appearances, so white labels keep their contrast.
    static var fill: Color { Color(hex: style.accent.light) }
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
        let f = Font.system(size: s.labels == .smallCaps ? size : size * 0.9, weight: weight ?? s.labelWeight)
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
        Text(s.labels == .smallCaps ? text.lowercased() : text.uppercased())
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
                .foregroundStyle(Color.white)
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
        .foregroundStyle(s.primaryFilled ? Color.white : Folio.rubric)
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

/// The window ground for each look. Glass lets the desktop through.
struct Ground: View {
    var look: Look
    var deep = false
    var body: some View {
        switch look {
        case .vellum:
            VisualEffect(material: deep ? .sidebar : .underWindowBackground)
                .overlay((deep ? Folio.paperDeep : Folio.paper).opacity(0.42))
        default:
            deep ? Folio.paperDeep : Folio.paper
        }
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

/// `@AppStorage("look")` with migration from 0.1 values.
@propertyWrapper
struct LookSetting: DynamicProperty {
    @AppStorage("look") private var raw: String = Look.bone.rawValue
    var wrappedValue: Look {
        get { Look.stored(raw) }
        nonmutating set { raw = newValue.rawValue }
    }
    var projectedValue: Binding<Look> {
        Binding(get: { Look.stored(raw) }, set: { raw = $0.rawValue })
    }
}
