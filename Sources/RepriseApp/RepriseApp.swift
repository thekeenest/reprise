import SwiftUI
import AppKit
import RepriseCore

@main
struct RepriseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel.shared
    @LookSetting private var look

    var body: some Scene {
        WindowGroup("Reprise", id: "main") {
            ContentView()
                .environment(model)
                .preferredColorScheme(look.scheme)
                .frame(minWidth: 980, minHeight: 580)
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1440, height: 880)
        .commands { RepriseCommands(model: model) }

        Settings {
            SettingsView()
                .environment(model)
                .preferredColorScheme(look.scheme)
        }

        MenuBarExtra {
            MenuBarContent().environment(model)
        } label: {
            Image(systemName: "repeat")
        }
        .menuBarExtraStyle(.menu)
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
    @LookSetting private var look

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
            Button("Use (Copy Filled)") { if let id = model.selectedID { model.use(id) } }.keyboardShortcut(.return, modifiers: .command)
            Button("Copy Source") { if let id = model.selectedID { model.copyRaw(id) } }.keyboardShortcut("c", modifiers: [.command, .shift])
            Button("Pin / Unpin") { if let id = model.selectedID { model.togglePin(id) } }.keyboardShortcut("p", modifiers: [.command, .shift])
            Button("Duplicate") { if let id = model.selectedID { model.duplicate(id) } }.keyboardShortcut("d")
            Button("Shuffle Color") { model.update { $0.color = Palette.random() } }.keyboardShortcut("k", modifiers: [.command, .shift])
            Button("Toggle Agent Command") { if let id = model.selectedID { model.toggleAgentCommand(id) } }.keyboardShortcut("t", modifiers: [.command, .shift])
            Button("Show or Hide Margin") { model.showMargin.toggle() }.keyboardShortcut("0", modifiers: [.command, .option])
            Divider()
            Button("Sync Agent Commands Now") { model.syncAgents(silent: false) }
            Divider()
            Button("Move to Trash") { if let id = model.selectedID { model.trash(id) } }.keyboardShortcut(.delete)
        }
        CommandGroup(after: .toolbar) {
            Picker("Look", selection: $look) {
                ForEach(Look.allCases) { Text($0.name).tag($0) }
            }
            Picker("Design", selection: Binding(get: { World.current }, set: { World.set($0) })) {
                ForEach(World.allCases) { Text($0.rawValue).tag($0) }
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
        model.show("Imported \(n) prompts")
    }

    @MainActor private func exportLibrary() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let n = (try? MarkdownIO.export(store: model.store, to: url.appendingPathComponent("Reprise Library"))) ?? 0
        model.show("Exported \(n) prompts as Markdown")
        NSWorkspace.shared.activateFileViewerSelecting([url.appendingPathComponent("Reprise Library")])
    }
}

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @LookSetting private var look
    @AppStorage("world") private var worldRaw = ""

    var body: some View {
        @Bindable var model = model
        let _ = worldRaw
        NavigationSplitView {
            SidebarView()
        } content: {
            PromptListView()
        } detail: {
            EditorView()
        }
        .searchable(text: $model.query, placement: .sidebar, prompt: "Search")
        .overlay(alignment: .bottom) {
            if let t = model.toast {
                ToastView(toast: t)
                    .padding(.bottom, 22)
                    .transition(.opacity.combined(with: .offset(y: 6)))
            }
        }
        .sheet(item: $model.fillTarget) { FillSheet(prompt: $0) }
        .sheet(item: $model.historyTarget) { HistorySheet(prompt: $0) }
        .sheet(item: $model.namingRequest) { NamingSheet(request: $0) }
        .sheet(isPresented: $model.showHarvest) { HarvestView() }
        .id(worldRaw)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .tint(Folio.ink)
    }
}

/// A printed slip: paper, hairline border, small text. No color unless something went wrong.
struct ToastView: View {
    let toast: AppModel.Toast
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.isError ? "exclamationmark.triangle" : "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(toast.isError ? Folio.rubric : Folio.slate)
            Text(toast.text)
                .font(.system(size: 12.5))
                .foregroundStyle(Folio.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Folio.paper, in: RoundedRectangle(cornerRadius: Folio.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Folio.radius, style: .continuous).strokeBorder(Folio.rule, lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
}

/// The brand mark: the musical repeat sign. A thin and a thick bar in ink, two dots in rubric.
struct RepriseMark: View {
    var size: CGFloat = 32
    var body: some View {
        HStack(spacing: size * 0.09) {
            VStack(spacing: size * 0.2) {
                Circle().fill(Folio.rubric).frame(width: size * 0.15, height: size * 0.15)
                Circle().fill(Folio.rubric).frame(width: size * 0.15, height: size * 0.15)
            }
            Rectangle().fill(Folio.ink).frame(width: size * 0.06, height: size * 0.8)
            Rectangle().fill(Folio.ink).frame(width: size * 0.17, height: size * 0.8)
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
