// Renders the Reprise app icon (and README hero mark) with SwiftUI.
// Usage: swift scripts/make-icon.swift <out-dir>
import SwiftUI
import AppKit

func hex(_ h: String) -> Color {
    var v: UInt64 = 0; Scanner(string: String(h.dropFirst())).scanHexInt64(&v)
    return Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
}

/// The repeat sign (two dots, a thin and a thick bar) in each world's materials.
struct Icon: View {
    var world: String

    var body: some View {
        ZStack {
            // macOS 26 icon grid: 824pt rounded rect inside a 1024 canvas.
            RoundedRectangle(cornerRadius: 186, style: .continuous)
                .fill(ground)
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.28), radius: 24, y: 14)
            switch world {
            case "Machined": machined
            case "Quiet": quiet
            default: edition
            }
        }
        .frame(width: 1024, height: 1024)
    }

    var ground: Color {
        switch world {
        case "Machined": return hex("#E4E4E1")
        case "Quiet": return hex("#E9E7E2")
        default: return hex("#F3F1EB")
        }
    }

    /// Bone paper, iron ink, rubric dots, inside the page's ruled frame.
    var edition: some View {
        ZStack {
            Rectangle().strokeBorder(hex("#1B1A18").opacity(0.22), lineWidth: 4).frame(width: 620, height: 620)
            sign(ink: hex("#1B1A18"), dot: hex("#B8321F"), scale: 1, radius: 0)
        }
    }

    /// Aluminum body with a graphite key cap set into it; signal-orange dots.
    var machined: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 96, style: .continuous)
                .fill(hex("#1E1E20"))
                .frame(width: 560, height: 560)
                .shadow(color: .black.opacity(0.35), radius: 14, y: 10)
            RoundedRectangle(cornerRadius: 96, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 3)
                .frame(width: 560, height: 560)
            sign(ink: hex("#EEEEEB"), dot: hex("#FF5A1F"), scale: 0.78, radius: 10)
        }
    }

    /// A record sleeve: a small light mark low on a warm gray board, one ink-blue pair of dots.
    var quiet: some View {
        sign(ink: hex("#2A2A28"), dot: hex("#2D5A8A"), scale: 0.62, radius: 0, light: true)
            .offset(x: -96, y: 110)
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
    let r = ImageRenderer(content: Icon(world: CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Edition"))
    r.scale = 1
    guard let cg = r.cgImage else { fatalError("render failed") }
    let rep = NSBitmapImageRep(cgImage: cg)
    try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("icon-1024.png"))
    print("wrote \(out.path)/icon-1024.png")
}
