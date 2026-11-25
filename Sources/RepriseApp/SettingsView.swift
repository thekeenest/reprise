import SwiftUI
import RepriseCore

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("Appearance", systemImage: "paintpalette") { AppearanceSettings() }
            Tab("Behavior", systemImage: "keyboard") { BehaviorSettings() }
            Tab("Agents", systemImage: "terminal") { AgentSettings() }
            Tab("Library", systemImage: "externaldrive") { LibrarySettings() }
        }
        .frame(width: 560, height: 440)
    }
}

struct AppearanceSettings: View {
    @LookSetting private var look
    @AppStorage("world") private var worldRaw = ""
    @AppStorage("editorFontChoice") private var fontChoice = ""
    @AppStorage("editorSizeChoice") private var sizeChoice: Double = 0

    var body: some View {
        let _ = worldRaw
        Form {
            Section("Design") {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(World.allCases) { w in
                        Button { World.set(w) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                WorldSwatch(style: w.style, dark: look == .iron)
                                    .overlay(Rectangle().strokeBorder(World.current == w ? Folio.ink : Folio.rule,
                                                                      lineWidth: World.current == w ? 1.5 : 1))
                                Text(w.rawValue).font(.system(size: 12.5, weight: .medium))
                                Text(w.blurb).font(.system(size: 11)).foregroundStyle(Folio.slate)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(width: 148, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Section("Look") {
                Picker("Look", selection: $look) {
                    ForEach(Look.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("\(look.subtitle). ⇧⌘L cycles looks.").font(.system(size: 11)).foregroundStyle(Folio.slate)
            }
            Section("Text") {
                Picker("Typeface", selection: $fontChoice) {
                    Text("Auto").tag("")
                    ForEach(EditorFont.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                Slider(value: Binding(get: { sizeChoice > 0 ? sizeChoice : Folio.style.editorSize }, set: { sizeChoice = $0 }),
                       in: 12...22, step: 0.5) {
                    Text("Size  \(String(format: "%g", sizeChoice > 0 ? sizeChoice : Folio.style.editorSize)) pt")
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// A miniature page drawn straight from a world's tokens, so all three can be compared side by side.
struct WorldSwatch: View {
    let style: Style
    var dark = false
    private func c(_ p: Style.Pair) -> Color { Color(hex: dark ? p.dark : p.light) }

    var body: some View {
        let r = style.radius
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Aa")
                    .font(.system(size: 15, weight: style.titleWeight, design: style.textDesign))
                    .foregroundStyle(c(style.ink))
                Rectangle().fill(c(style.ink).opacity(0.2)).frame(height: 1)
                Rectangle().fill(c(style.slate).opacity(0.6)).frame(width: 70, height: 3)
                HStack(spacing: 3) {
                    Rectangle().fill(c(style.slate).opacity(0.6)).frame(width: 26, height: 3)
                    Rectangle().fill(c(style.accent)).frame(width: 18, height: 3)
                    Rectangle().fill(c(style.slate).opacity(0.6)).frame(width: 18, height: 3)
                }
            }
            .padding(10)
            Spacer(minLength: 0)
            Rectangle().fill(c(style.ink).opacity(0.15)).frame(width: 1)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: min(r, 2)).fill(c(style.accent)).frame(width: 7, height: 7)
                RoundedRectangle(cornerRadius: min(r, 3))
                    .fill(style.primaryFilled ? c(style.accent) : .clear)
                    .overlay(RoundedRectangle(cornerRadius: min(r, 3)).strokeBorder(c(style.accent), lineWidth: 1))
                    .frame(width: 28, height: 9)
            }
            .padding(8)
        }
        .frame(width: 148, height: 80)
        .background(c(style.paper))
    }
}

struct BehaviorSettings: View {
    @AppStorage("hotkey") private var hotkey = HotKey.Combo.optCmdP.label
    @AppStorage("autoPaste") private var autoPaste = true
    @AppStorage("includeAttachmentPaths") private var includePaths = true
    @State private var trusted = Paster.canAutoPaste

    var body: some View {
        Form {
            Section("Quick Panel") {
                Picker("Global shortcut", selection: $hotkey) {
                    ForEach(HotKey.Combo.all) { Text($0.label).tag($0.label) }
                }
                .onChange(of: hotkey) { QuickPanelController.shared.registerHotKey() }
                Toggle("Paste into the frontmost app after choosing a prompt", isOn: $autoPaste)
                if autoPaste && !trusted {
                    HStack {
                        Label("Needs Accessibility permission to press ⌘V for you.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Folio.rubric).font(.callout)
                        Spacer()
                        Button("Grant…") { Paster.requestAccessibility() }
                    }
                }
            }
            Section {
                Toggle("Append attachment paths & links to the copied prompt", isOn: $includePaths)
            } header: { Text("Attachments") } footer: {
                Text("Claude Code, Codex and most agents read images and files from absolute paths pasted into the prompt. Off: images go on the clipboard as files instead.")
            }
        }
        .formStyle(.grouped)
        .onAppear { trusted = Paster.canAutoPaste }
    }
}

struct AgentSettings: View {
    @Environment(AppModel.self) private var model
    @AppStorage("sync.Claude Code") private var claude = true
    @AppStorage("sync.Codex") private var codex = true
    @State private var cliStatus = ""

    var cliPath: String { Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/reprise").path }

    var body: some View {
        Form {
            Section {
                Toggle("Claude Code  →  ~/.claude/commands", isOn: $claude)
                Toggle("Codex  →  ~/.codex/prompts", isOn: $codex)
                Button("Sync Now") { model.syncAgents(silent: false) }
            } header: { Text("Slash commands") } footer: {
                Text("Prompts marked as Agent Command (⇧⌘T) become /commands. Variables become arguments. Reprise never touches files it didn't create.")
            }
            Section {
                CopyRow(label: "Claude Code", command: "claude mcp add reprise -- reprise mcp")
                CopyRow(label: "Codex", command: "codex mcp add reprise -- reprise mcp")
            } header: { Text("MCP server") } footer: {
                Text("Agents can search, render and save prompts in your library. Pinned prompts show up as /mcp__reprise__… commands.")
            }
            Section("Command line") {
                HStack {
                    Text("reprise").font(.body.monospaced())
                    Spacer()
                    Button("Install to ~/.local/bin") { installCLI() }
                }
                if !cliStatus.isEmpty { Text(cliStatus).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
            }
        }
        .formStyle(.grouped)
    }

    private func installCLI() {
        let bin = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin")
        try? FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let link = bin.appendingPathComponent("reprise")
        try? FileManager.default.removeItem(at: link)
        do {
            try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: cliPath)
            cliStatus = "Linked \(link.path). Make sure ~/.local/bin is on your PATH."
        } catch {
            cliStatus = "Couldn't link: \(error.localizedDescription). Run: ln -sf \"\(cliPath)\" /usr/local/bin/reprise"
        }
    }
}

struct CopyRow: View {
    let label: String
    let command: String
    @State private var copied = false
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.callout.weight(.medium))
                Text(command).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Spacer()
            Button(copied ? "Copied" : "Copy") {
                Paster.copy(command); copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            }
        }
    }
}

struct LibrarySettings: View {
    @Environment(AppModel.self) private var model
    @State private var stats: (prompts: Int, characters: Int, templates: Int) = (0, 0, 0)

    var body: some View {
        Form {
            Section("Your library") {
                LabeledContent("Prompts", value: stats.prompts.formatted())
                LabeledContent("Templates", value: stats.templates.formatted())
                LabeledContent("Characters", value: stats.characters.formatted())
                LabeledContent("Location") {
                    Button(model.store.root.path) { NSWorkspace.shared.open(model.store.root) }
                        .buttonStyle(.link).lineLimit(1).truncationMode(.middle)
                }
            }
            Section {
                Text("One SQLite file with full-text search (FTS5), WAL journaling and automatic version history. Back it up like any file, or export everything to Markdown from the File menu.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { stats = (try? model.store.stats()) ?? (0, 0, 0) }
    }
}
