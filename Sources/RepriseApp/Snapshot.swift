import AppKit
import SwiftUI

/// Developer aid: `REPRISE_SNAPSHOT=/out/dir Reprise.app/Contents/MacOS/Reprise`
/// renders the main window in every Look plus the Quick Panel to PNGs, then quits.
/// Used to produce README screenshots reproducibly, without Screen Recording permission.
@MainActor
enum Snapshot {
    static var outDir: URL? {
        ProcessInfo.processInfo.environment["REPRISE_SNAPSHOT"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// REPRISE_DEMO=panel|fill|harvest|run|edit|palette|tabs opens that surface on launch (for recording demos).
    static func demoIfRequested() {
        if let title = ProcessInfo.processInfo.environment["REPRISE_SELECT"],
           let p = try? AppModel.shared.store.prompt(named: title) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if World.current == .studio { AppModel.shared.open(p.id) } else { AppModel.shared.selectedID = p.id }
            }
        }
        guard let demo = ProcessInfo.processInfo.environment["REPRISE_DEMO"] else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let model = AppModel.shared
            switch demo {
            case "panel":
                NSApp.windows.filter { !($0 is QuickPanel) }.forEach { $0.orderOut(nil) }
                QuickPanelController.shared.show()
            case "fill": if let id = model.selectedID { model.use(id) }
            case "harvest": model.showHarvest = true
            case "run": model.showRun = true
            case "new": model.newPrompt()
            case "settings": model.openSettingsToken += 1
            case "edit": model.editing = true
            case "palette": model.showPalette = true
            case "tabs":
                for t in ["Staff Engineer", "Hunt a bug", "Ship a feature"] {
                    if let p = try? model.store.prompt(named: t) { model.open(p.id) }
                }
                if let p = try? model.store.prompt(named: ProcessInfo.processInfo.environment["REPRISE_SELECT"] ?? "") { model.selectedID = p.id }
            default: break
            }
        }
    }

    static func runIfRequested() {
        demoIfRequested()
        guard let out = outDir else { return }
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let original = UserDefaults.standard.string(forKey: "theme")
        var steps: [(String, () -> Void)] = []
        for look in Look.allCases {
            steps.append(("main-\(look.rawValue.lowercased())", { UserDefaults.standard.set(look.rawValue, forKey: "theme") }))
        }
        steps.append(("quick-panel", {
            UserDefaults.standard.set(Look.dark.rawValue, forKey: "theme")
            QuickPanelController.shared.show()
        }))

        func run(_ i: Int) {
            guard i < steps.count else {
                if let original { UserDefaults.standard.set(original, forKey: "theme") }
                NSApp.terminate(nil)
                return
            }
            steps[i].1()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                let name = steps[i].0
                let window: NSWindow? = name == "quick-panel"
                    ? NSApp.windows.first { $0 is QuickPanel }
                    : NSApp.windows.first { $0.isVisible && !($0 is QuickPanel) && $0.canBecomeMain }
                if let window { capture(window, to: out.appendingPathComponent("\(name).png")) }
                run(i + 1)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { run(0) }
    }

    static func capture(_ window: NSWindow, to url: URL) {
        guard let view = window.contentView?.superview ?? window.contentView else { return }
        let bounds = view.bounds
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { return }
        view.cacheDisplay(in: bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
