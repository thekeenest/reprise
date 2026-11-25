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
    @AppStorage("look") private var look: Look = .liquid
    @AppStorage("editorFont") private var editorFont: EditorFont = .mono
    @AppStorage("editorSize") private var editorSize: Double = 14

    var body: some View {
        Form {
            Section("Look") {
                HStack(spacing: 14) {
                    ForEach(Look.allCases) { l in
                        Button { look = l } label: {
                            VStack(spacing: 8) {
                                LookSwatch(look: l)
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor, lineWidth: look == l ? 2.5 : 0))
                                Text(l.rawValue).font(.callout.weight(.semibold))
                                Text(l.subtitle).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            }
                            .frame(width: 150)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Section("Editor") {
                Picker("Font", selection: $editorFont) { ForEach(EditorFont.allCases) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented)
                Slider(value: $editorSize, in: 11...22, step: 1) { Text("Size  \(Int(editorSize)) pt") }
            }
        }
        .formStyle(.grouped)
    }
}

struct LookSwatch: View {
    let look: Look
    var body: some View {
        ZStack {
            Aura(color: Color(hex: "#7A5CFA"), look: look)
            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 3).frame(width: 60, height: 7).opacity(0.7)
                RoundedRectangle(cornerRadius: 3).frame(width: 90, height: 5).opacity(0.35)
                RoundedRectangle(cornerRadius: 3).frame(width: 74, height: 5).opacity(0.35)
            }
            .padding(10)
            .surface(look, tint: Color(hex: "#7A5CFA"), radius: 10)
        }
        .frame(width: 140, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .environment(\.colorScheme, look == .ink ? .dark : .light)
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
                            .foregroundStyle(.orange).font(.callout)
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
