import Foundation

/// Colors are generated in OKLCH, a perceptual color space, so every random hue
/// has the same perceived lightness/vibrancy. That gives an effectively unlimited
/// pool of shades that all look good together, instead of a 12-swatch palette.
public enum Palette {
    public struct RGB: Equatable {
        public var r, g, b: Double
        public init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
    }

    /// Curated anchors shown first in the picker. Random generation is unlimited.
    public static let curated: [String] = [
        "#FF6B6B", "#FF8E3C", "#FFC145", "#B8E04A", "#3DDC97", "#2EC4B6",
        "#3AB7F0", "#4D7CFE", "#7A5CFA", "#B45CF0", "#F05CC8", "#F0607F",
        "#C9A27E", "#8E9AAF", "#5E6472", "#E8E3D9",
    ]

    /// A random, harmonious color. Optionally keep a hue family (0–360) with some jitter.
    public static func random(near hue: Double? = nil) -> String {
        var g = SystemRandomNumberGenerator()
        let h = hue.map { $0 + Double.random(in: -28...28, using: &g) } ?? Double.random(in: 0..<360, using: &g)
        let l = Double.random(in: 0.66...0.80, using: &g)
        let c = Double.random(in: 0.11...0.19, using: &g)
        return hex(oklch(l: l, c: c, h: h))
    }

    /// Generates `count` evenly spaced but randomly rotated hues — useful for seeding.
    public static func spread(_ count: Int) -> [String] {
        let start = Double.random(in: 0..<360)
        return (0..<count).map { i in
            hex(oklch(l: 0.72, c: 0.15, h: start + Double(i) * 360 / Double(max(count, 1))))
        }
    }

    public static func oklch(l: Double, c: Double, h: Double) -> RGB {
        let hr = h * .pi / 180
        let a = c * cos(hr), b = c * sin(hr)
        let l_ = l + 0.3963377774 * a + 0.2158037573 * b
        let m_ = l - 0.1055613458 * a - 0.0638541728 * b
        let s_ = l - 0.0894841775 * a - 1.2914855480 * b
        let L = l_ * l_ * l_, M = m_ * m_ * m_, S = s_ * s_ * s_
        func gamma(_ x: Double) -> Double {
            let v = x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055
            return min(max(v, 0), 1)
        }
        return RGB(
            r: gamma(4.0767416621 * L - 3.3077115913 * M + 0.2309699292 * S),
            g: gamma(-1.2684380046 * L + 2.6097574011 * M - 0.3413193965 * S),
            b: gamma(-0.0041960863 * L - 0.7034186147 * M + 1.7076147010 * S)
        )
    }

    public static func hex(_ c: RGB) -> String {
        String(format: "#%02X%02X%02X", Int((c.r * 255).rounded()), Int((c.g * 255).rounded()), Int((c.b * 255).rounded()))
    }

    public static func rgb(_ hex: String) -> RGB {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return RGB(r: 0.5, g: 0.5, b: 0.5) }
        return RGB(r: Double((v >> 16) & 0xFF) / 255, g: Double((v >> 8) & 0xFF) / 255, b: Double(v & 0xFF) / 255)
    }

    /// Approximate hue (degrees) of a hex color — used to generate "sibling" shades.
    public static func hue(_ hex: String) -> Double {
        let c = rgb(hex)
        let mx = max(c.r, c.g, c.b), mn = min(c.r, c.g, c.b), d = mx - mn
        guard d > 0.0001 else { return 0 }
        var h: Double
        if mx == c.r { h = (c.g - c.b) / d }
        else if mx == c.g { h = (c.b - c.r) / d + 2 }
        else { h = (c.r - c.g) / d + 4 }
        h *= 60
        return h < 0 ? h + 360 : h
    }
}
