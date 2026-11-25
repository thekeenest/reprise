import SwiftUI
import AppKit
import RepriseCore

@main
struct RepriseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel.shared
    @AppStorage("look") private var look: Look = .liquid

    var body: some Scene {
        WindowGroup("Reprise", id: "main") {
            ContentView()
                .environment(model)
                .preferredColorScheme(look == .ink ? .dark : nil)
                .frame(minWidth: 940, minHeight: 560)
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1280, height: 800)
        .commands { RepriseCommands(model: model) }

        Settings {
            SettingsView()
                .environment(model)
                .preferredColorScheme(look == .ink ? .dark : nil)
        }

        MenuBarExtra {
            MenuBarContent().environment(model)
        } label: {
            Image(systemName: "repeat")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        QuickPanelController.shared.registerHotKey()
        NSApp.activate(ignoringOtherApps: true)
        MainActor.assumeIsolated { Snapshot.runIfRequested() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { AppModel.shared.flushSave() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { true }
}

struct RepriseCommands: Commands {
    let model: AppModel
    @AppStorage("look") private var look: Look = .liquid

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Prompt") { model.newPrompt() }.keyboardShortcut("n")
            Button("New Project…") {
                let sid = model.project(model.targetProjectID)?.spaceID ?? model.spaces.first?.id ?? 1
                model.namingRequest = .init(kind: .newProject(spaceID: sid))
            }.keyboardShortcut("n", modifiers: [.command, .shift])
            Button("New Space…") { model.namingRequest = .init(kind: .newSpace) }.keyboardShortcut("n", modifiers: [.command, .option])
            Divider()
            Button("Harvest from Agent History…") { model.showHarvest = true }.keyboardShortcut("h", modifiers: [.command, .shift])
            Button("Import Markdown Files…") { importFiles() }.keyboardShortcut("i", modifiers: [.command, .shift])
            Button("Export Library as Markdown…") { exportLibrary() }.keyboardShortcut("e", modifiers: [.command, .shift])
        }
        CommandMenu("Prompt") {
            Button("Use (Fill & Copy)") { if let id = model.selectedID { model.use(id) } }.keyboardShortcut(.return, modifiers: .command)
            Button("Copy Source") { if let id = model.selectedID { model.copyRaw(id) } }.keyboardShortcut("c", modifiers: [.command, .shift])
            Button("Pin / Unpin") { if let id = model.selectedID { model.togglePin(id) } }.keyboardShortcut("p", modifiers: [.command, .shift])
            Button("Duplicate") { if let id = model.selectedID { model.duplicate(id) } }.keyboardShortcut("d")
            Button("Shuffle Color") { model.update { $0.color = Palette.random() } }.keyboardShortcut("k", modifiers: [.command, .shift])
            Button("Toggle Agent Command") { if let id = model.selectedID { model.toggleAgentCommand(id) } }.keyboardShortcut("t", modifiers: [.command, .shift])
            Divider()
            Button("Sync Agent Commands Now") { model.syncAgents(silent: false) }
            Divider()
            Button("Move to Trash") { if let id = model.selectedID { model.trash(id) } }.keyboardShortcut(.delete)
        }
        CommandGroup(after: .toolbar) {
            Picker("Look", selection: $look) {
                ForEach(Look.allCases) { Text($0.rawValue).tag($0) }
            }
            Button("Next Look") {
                let all = Look.allCases
                look = all[(all.firstIndex(of: look)! + 1) % all.count]
            }.keyboardShortcut("l", modifiers: [.command, .shift])
            Button("Quick Panel") { QuickPanelController.shared.toggle() }
        }
    }

    @MainActor private func importFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [.plainText, .init(filenameExtension: "md")!]
        guard panel.runModal() == .OK else { return }
        let sid = model.project(model.targetProjectID)?.spaceID ?? model.spaces.first?.id ?? 1
        let n = (try? MarkdownIO.importFiles(panel.urls, store: model.store, spaceID: sid)) ?? 0
        model.reloadStructure(); model.reloadList()
        model.show("Imported \(n) prompts", icon: "square.and.arrow.down.fill", color: "#4D7CFE")
    }

    @MainActor private func exportLibrary() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let n = (try? MarkdownIO.export(store: model.store, to: url.appendingPathComponent("Reprise Library"))) ?? 0
        model.show("Exported \(n) prompts as Markdown", icon: "square.and.arrow.up.fill", color: "#4D7CFE")
        NSWorkspace.shared.activateFileViewerSelecting([url.appendingPathComponent("Reprise Library")])
    }
}

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("look") private var look: Look = .liquid

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            SidebarView()
        } content: {
            PromptListView()
                .background {
                    if look == .ink { Color(white: 0.055).ignoresSafeArea() }
                    else { Aura(color: Color(hex: model.accentHex), look: look).opacity(0.45).ignoresSafeArea() }
                }
        } detail: {
            EditorView()
        }
        .searchable(text: $model.query, placement: .toolbar, prompt: "Search every prompt")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { model.newPrompt() } label: { Label("New Prompt", systemImage: "square.and.pencil") }
                    .help("New prompt (⌘N)")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { QuickPanelController.shared.toggle() } label: { Label("Quick Panel", systemImage: "command") }
                    .help("Quick Panel (\(UserDefaults.standard.string(forKey: "hotkey") ?? "⌥⌘P"))")
            }
        }
        .overlay(alignment: .top) {
            if let t = model.toast {
                ToastView(toast: t)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .fontDesign(look == .ink ? .monospaced : .default)
        .sheet(item: $model.fillTarget) { FillSheet(prompt: $0) }
        .sheet(item: $model.historyTarget) { HistorySheet(prompt: $0) }
        .sheet(item: $model.namingRequest) { NamingSheet(request: $0) }
        .sheet(isPresented: $model.showHarvest) { HarvestView() }
        .tint(Color(hex: model.accentHex))
    }
}

struct ToastView: View {
    let toast: AppModel.Toast
    var body: some View {
        Label(toast.text, systemImage: toast.icon)
            .font(.callout.weight(.medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Color(hex: toast.color))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .glassEffect(.regular.tint(Color(hex: toast.color).opacity(0.15)), in: .capsule)
    }
}

/// The brand mark: the musical repeat sign ( 𝄇 ) — two dots and a double bar — on glass.
struct RepriseMark: View {
    var size: CGFloat = 32
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#7A5CFA"), Color(hex: "#F05CC8"), Color(hex: "#FF8E3C")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            HStack(spacing: size * 0.075) {
                VStack(spacing: size * 0.14) {
                    Circle().frame(width: size * 0.12, height: size * 0.12)
                    Circle().frame(width: size * 0.12, height: size * 0.12)
                }
                Capsule().frame(width: size * 0.055, height: size * 0.5)
                Capsule().frame(width: size * 0.13, height: size * 0.5)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.2), radius: size * 0.03, y: size * 0.02)
        }
        .frame(width: size, height: size)
    }
}

struct MenuBarContent: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        Button("Quick Panel") { QuickPanelController.shared.show() }
        Divider()
        let pinned = (try? model.store.summaries(scope: .pinned, sort: .used, limit: 15)) ?? []
        if !pinned.isEmpty {
            Section("Pinned") {
                ForEach(pinned) { p in
                    Button(p.title + (p.isTemplate ? " …" : "")) {
                        if p.isTemplate { QuickPanelController.shared.show() }
                        else if let full = try? model.store.prompt(p.id) { model.copy(full, values: [:]) }
                    }
                }
            }
            Divider()
        }
        Button("Open Reprise") {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
        }
        Button("Harvest…") { NSApp.activate(ignoringOtherApps: true); model.showHarvest = true }
        Divider()
        Button("Quit Reprise") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
