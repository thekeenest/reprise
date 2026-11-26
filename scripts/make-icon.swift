// Renders the Reprise app icon (and README hero mark) with SwiftUI.
// Usage: swift scripts/make-icon.swift <out-dir>
import SwiftUI
import AppKit

func hex(_ h: String) -> Color {
    var v: UInt64 = 0; Scanner(string: String(h.dropFirst())).scanHexInt64(&v)
    return Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
}

/// The repeat sign (two dots, a thin and a thick bar). Variants: "Coral", "Wine", "Glass", "Glass Wine".
struct Icon: View {
    var variant: String
    var glass: Bool { variant.hasPrefix("Glass") }
    var dot: Color { variant.hasSuffix("Wine") ? hex("#C8485E") : hex("#EF6A52") }

    var body: some View {
        ZStack {
            // macOS 26 icon grid: 824pt rounded rect inside a 1024 canvas.
            let tile = RoundedRectangle(cornerRadius: 186, style: .continuous)
            Group {
                if glass {
                    tile.fill(LinearGradient(colors: [hex("#4A4E57"), hex("#23252B"), hex("#1A1B1F")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(tile.fill(RadialGradient(colors: [dot.opacity(0.35), .clear], center: .bottomLeading, startRadius: 0, endRadius: 700)))
                } else {
                    tile.fill(hex("#161514"))
                }
            }
            .overlay(tile.strokeBorder(LinearGradient(colors: [Color.white.opacity(glass ? 0.35 : 0.1), Color.white.opacity(0.03)],
                                                      startPoint: .top, endPoint: .bottom), lineWidth: glass ? 5 : 3))
            .frame(width: 824, height: 824)
            .shadow(color: .black.opacity(0.28), radius: 24, y: 14)

            // An inner pane: frosted glass, or a quiet raised page.
            let pane = RoundedRectangle(cornerRadius: 120, style: .continuous)
            Group {
                if glass {
                    pane.fill(LinearGradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.06)], startPoint: .top, endPoint: .bottom))
                        .overlay(pane.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.08)],
                                                                  startPoint: .top, endPoint: .bottom), lineWidth: 4))
                } else {
                    pane.fill(hex("#1F1E1C")).overlay(pane.strokeBorder(Color.white.opacity(0.08), lineWidth: 4))
                }
            }
            .frame(width: 600, height: 600)
            sign(ink: hex("#F1EEE7"), dot: dot, scale: 0.8, radius: 14)
        }
        .frame(width: 1024, height: 1024)
    }

    func sign(ink: Color, dot: Color, scale: CGFloat, radius: CGFloat, light: Bool = false) -> some View {
        HStack(spacing: 40 * scale) {
            VStack(spacing: 96 * scale) {
                Circle().fill(dot).frame(width: (light ? 52 : 70) * scale, height: (light ? 52 : 70) * scale)
                Circle().fill(dot).frame(width: (light ? 52 : 70) * scale, height: (light ? 52 : 70) * scale)
            }
            RoundedRectangle(cornerRadius: radius * 0.4).fill(ink).frame(width: (light ? 14 : 26) * scale, height: 400 * scale)
            RoundedRectangle(cornerRadius: radius).fill(ink).frame(width: (light ? 52 : 84) * scale, height: 400 * scale)
        }
        .offset(x: 8 * scale)
    }
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

MainActor.assumeIsolated {
    let r = ImageRenderer(content: Icon(variant: CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Coral"))
    r.scale = 1
    guard let cg = r.cgImage else { fatalError("render failed") }
    let rep = NSBitmapImageRep(cgImage: cg)
    try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("icon-1024.png"))
    print("wrote \(out.path)/icon-1024.png")
}
