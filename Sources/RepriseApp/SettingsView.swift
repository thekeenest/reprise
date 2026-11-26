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
        .frame(width: 580, height: 640)
        .tint(Folio.rubric)
    }
}

struct AppearanceSettings: View {
    @LookSetting private var look
    @AppStorage("finish") private var finishRaw = ""
    @AppStorage("accent") private var accentRaw = ""
    @AppStorage("libraryLayout") private var libraryRaw = ""
    @AppStorage("editorFontChoice") private var fontChoice = ""
    @AppStorage("editorSizeChoice") private var sizeChoice: Double = 0

    var body: some View {
        let _ = finishRaw + accentRaw + libraryRaw
        Form {
            Section("Theme") {
                Picker("Theme", selection: $look) {
                    ForEach(Look.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("Dark is the default. ⇧⌘L switches themes.").font(.system(size: 11)).foregroundStyle(Folio.slate)
            }
            Section("Finish") {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(Finish.allCases) { f in
                        ChoiceCard(title: f.rawValue, blurb: f.blurb, selected: Variant.finish == f) {
                            Schematic(glass: f == .glass, outline: Variant.library == .outline)
                        } action: { Variant.set(finish: f) }
                    }
                }
            }
            Section("Accent") {
                HStack(spacing: 18) {
                    ForEach(Accent.allCases) { a in
                        AccentSwatch(accent: a, selected: Variant.accent == a) { Variant.set(accent: a) }
                    }
                    Spacer()
                }
            }
            Section("Library") {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(LibraryLayout.allCases) { l in
                        ChoiceCard(title: l.name,
                                   blurb: l == .columns ? "Spaces and projects, then a list of prompts." : "One outline of spaces, projects and prompts. More room for the page.",
                                   selected: Variant.library == l) {
                            Schematic(glass: Variant.glass, outline: l == .outline)
                        } action: { Variant.set(library: l) }
                    }
                }
            }
            Section("Editor text") {
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

struct ChoiceCard<Preview: View>: View {
    let title: String
    let blurb: String
    let selected: Bool
    @ViewBuilder var preview: Preview
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                preview
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(selected ? Folio.rubric : Folio.rule, lineWidth: selected ? 2 : 1))
                Text(title).font(.system(size: 12.5, weight: .semibold))
                Text(blurb).font(.system(size: 11)).foregroundStyle(Folio.slate)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 220, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct AccentSwatch: View {
    let accent: Accent
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: accent.fill.dark))
                    .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                    .frame(width: 22, height: 22)
                    .padding(3)
                    .overlay(Circle().strokeBorder(selected ? Color(hex: accent.text.dark) : .clear, lineWidth: 2))
                Text(accent.rawValue).font(.system(size: 12.5, weight: selected ? .semibold : .regular))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A miniature of the window: sidebar, list (or outline), page, inspector.
struct Schematic: View {
    let glass: Bool
    let outline: Bool
    var body: some View {
        let ink = Color(hex: "#ECE9E1")
        let accent = Color(hex: Variant.accent.fill.dark)
        let gap: CGFloat = glass ? 3 : 0
        ZStack {
            if glass {
                LinearGradient(colors: [Color(hex: "#3B3F46"), Color(hex: "#1D2025"), Color(hex: "#4A3A33")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                Color(hex: "#0F0E0D")
            }
            HStack(spacing: gap) {
                pane(.white.opacity(glass ? 0.08 : 0), solid: "#0F0E0D") {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(0..<(outline ? 7 : 5), id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1).fill(ink.opacity(i == 2 ? 0.55 : 0.18))
                                .frame(width: outline && i > 1 ? 22 : 28, height: 3)
                                .padding(.leading, outline && i > 1 ? 6 : 0)
                        }
                    }
                }
                .frame(width: outline ? 44 : 34)
                if !outline {
                    pane(.white.opacity(glass ? 0.08 : 0), solid: "#131211") {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(0..<4, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1).fill(ink.opacity(i == 1 ? 0.5 : 0.2)).frame(height: 3)
                            }
                        }
                    }
                    .frame(width: 40)
                }
                pane(.white.opacity(glass ? 0.12 : 0), solid: "#161514") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack { Spacer(); Capsule().fill(accent).frame(width: 16, height: 5) }
                        Text("Aa").font(.system(size: 10, design: .serif)).foregroundStyle(ink)
                        ForEach(0..<4, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1).fill(i == 1 ? accent.opacity(0.8) : ink.opacity(0.22)).frame(width: i == 1 ? 30 : 56, height: 2.5)
                        }
                    }
                }
                pane(.white.opacity(glass ? 0.08 : 0), solid: "#0F0E0D") {
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(ink.opacity(0.14)).frame(height: 6)
                        RoundedRectangle(cornerRadius: 2).fill(ink.opacity(0.14)).frame(height: 6)
                        Capsule().fill(accent).frame(width: 18, height: 5)
                    }
                }
                .frame(width: 32)
            }
            .padding(gap)
        }
        .frame(width: 220, height: 100)
    }

    private func pane<C: View>(_ glassFill: Color, solid: String, @ViewBuilder _ c: () -> C) -> some View {
        c()
            .padding(5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                if glass {
                    RoundedRectangle(cornerRadius: 4, style: .continuous).fill(glassFill)
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
                } else {
                    Color(hex: solid).overlay(alignment: .trailing) { Rectangle().fill(.white.opacity(0.06)).frame(width: 0.5) }
                }
            }
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
