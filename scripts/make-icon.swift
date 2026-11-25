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
                .overlay(RoundedRectangle(cornerRadius: 186, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 3))
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.28), radius: 24, y: 14)
            switch world {
            case "Board": board
            case "Studio": studio
            default: console
            }
        }
        .frame(width: 1024, height: 1024)
    }

    var ground: Color {
        switch world {
        case "Board": return hex("#0E0F10")
        case "Studio": return hex("#181715")
        default: return hex("#121214")
        }
    }

    /// Console: the sign set into a search field, coral dots on graphite.
    var console: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 120, style: .continuous)
                .fill(hex("#1C1C1F"))
                .frame(width: 600, height: 600)
            RoundedRectangle(cornerRadius: 120, style: .continuous)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 4)
                .frame(width: 600, height: 600)
            sign(ink: hex("#EDEDEF"), dot: hex("#FF6A45"), scale: 0.8, radius: 12)
        }
    }

    /// Board: the bars become tiles on three faint columns; mint dots.
    var board: some View {
        ZStack {
            HStack(spacing: 34) {
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 4)
                        .frame(width: 176, height: 560)
                }
            }
            sign(ink: hex("#F2F3F3"), dot: hex("#5EE0A8"), scale: 0.86, radius: 26)
        }
    }

    /// Studio: bone ink on iron inside the page's ruled frame, vermilion dots.
    var studio: some View {
        ZStack {
            Rectangle().strokeBorder(hex("#ECE9E1").opacity(0.18), lineWidth: 4).frame(width: 620, height: 620)
            sign(ink: hex("#ECE9E1"), dot: hex("#EF6A52"), scale: 1, radius: 0)
        }
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
    let r = ImageRenderer(content: Icon(world: CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Console"))
    r.scale = 1
    guard let cg = r.cgImage else { fatalError("render failed") }
    let rep = NSBitmapImageRep(cgImage: cg)
    try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("icon-1024.png"))
    print("wrote \(out.path)/icon-1024.png")
}
