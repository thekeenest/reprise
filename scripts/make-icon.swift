// Renders the Reprise app icon (and README hero mark) with SwiftUI.
// Usage: swift scripts/make-icon.swift <out-dir>
import SwiftUI
import AppKit

struct Icon: View {
    var body: some View {
        ZStack {
            // macOS 26 icon grid: 824pt rounded rect inside a 1024 canvas.
            RoundedRectangle(cornerRadius: 186, style: .continuous)
                .fill(
                    MeshGradient(width: 3, height: 3, points: [
                        [0, 0], [0.5, 0], [1, 0],
                        [0, 0.5], [0.55, 0.45], [1, 0.5],
                        [0, 1], [0.5, 1], [1, 1],
                    ], colors: [
                        Color(red: 0.29, green: 0.20, blue: 0.86), Color(red: 0.45, green: 0.30, blue: 0.98), Color(red: 0.83, green: 0.32, blue: 0.86),
                        Color(red: 0.22, green: 0.26, blue: 0.90), Color(red: 0.62, green: 0.30, blue: 0.95), Color(red: 0.96, green: 0.38, blue: 0.70),
                        Color(red: 0.16, green: 0.45, blue: 0.96), Color(red: 0.86, green: 0.36, blue: 0.80), Color(red: 1.00, green: 0.56, blue: 0.30),
                    ])
                )
                .frame(width: 824, height: 824)
                .overlay(
                    // Specular rim, the "liquid" edge.
                    RoundedRectangle(cornerRadius: 186, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.65), .white.opacity(0.05), .white.opacity(0.3)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 6)
                )
                .shadow(color: .black.opacity(0.35), radius: 28, y: 18)

            // Glass lens.
            RoundedRectangle(cornerRadius: 120, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.34), .white.opacity(0.08)], startPoint: .top, endPoint: .bottom))
                .frame(width: 560, height: 560)
                .overlay(
                    RoundedRectangle(cornerRadius: 120, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom), lineWidth: 3)
                )
                .shadow(color: Color(red: 0.2, green: 0.05, blue: 0.4).opacity(0.35), radius: 30, y: 16)

            // The repeat sign 𝄇 : two dots, thin bar, thick bar.
            HStack(spacing: 34) {
                VStack(spacing: 76) {
                    Circle().frame(width: 62, height: 62)
                    Circle().frame(width: 62, height: 62)
                }
                Capsule().frame(width: 30, height: 300)
                Capsule().frame(width: 74, height: 300)
            }
            .foregroundStyle(.white)
            .shadow(color: Color(red: 0.25, green: 0.08, blue: 0.5).opacity(0.45), radius: 10, y: 6)
            .offset(x: 6)
        }
        .frame(width: 1024, height: 1024)
    }
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

MainActor.assumeIsolated {
    let r = ImageRenderer(content: Icon())
    r.scale = 1
    guard let cg = r.cgImage else { fatalError("render failed") }
    let rep = NSBitmapImageRep(cgImage: cg)
    try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("icon-1024.png"))
    print("wrote \(out.path)/icon-1024.png")
}
