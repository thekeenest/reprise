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
        .frame(width: 560, height: 560)
        .tint(Folio.rubric)
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
            Section("Theme") {
                Picker("Theme", selection: $look) {
                    ForEach(Look.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("Dark is the default. ⇧⌘L switches themes.").font(.system(size: 11)).foregroundStyle(Folio.slate)
            }
            Section("Design") {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(World.allCases) { w in
                        DesignCard(world: w, selected: World.current == w) { World.set(w) }
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

struct DesignCard: View {
    let world: World
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                DesignSchematic(world: world)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(selected ? Folio.rubric : Folio.rule, lineWidth: selected ? 2 : 1))
                Text(world.rawValue).font(.system(size: 12.5, weight: .semibold))
                Text(world.blurb).font(.system(size: 11)).foregroundStyle(Folio.slate)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 150, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A miniature of each design's layout, drawn from its dark tokens, so the choice is about structure.
struct DesignSchematic: View {
    let world: World
    private var s: Style { world.style }
    private func c(_ p: Style.Pair, _ o: Double = 1) -> Color { Color(hex: p.dark).opacity(o) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            c(s.paperDeep)
            switch world {
            case .console:
                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(c(s.ink, 0.25)).frame(height: 8)
                        RoundedRectangle(cornerRadius: 2).fill(c(s.fill)).frame(width: 18, height: 8)
                    }.padding(6).background(c(s.paper))
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(0..<6) { i in RoundedRectangle(cornerRadius: 1.5).fill(c(s.ink, i == 1 ? 0.5 : 0.18)).frame(height: 4) }
                        }.padding(6).frame(width: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 1.5).fill(c(s.ink, 0.6)).frame(width: 46, height: 5)
                            RoundedRectangle(cornerRadius: 2).fill(c(s.ink, 0.1)).frame(height: 22)
                            RoundedRectangle(cornerRadius: 2).fill(c(s.fill)).frame(height: 7)
                        }.padding(6).frame(maxWidth: .infinity).background(c(s.paper))
                    }
                }
            case .board:
                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { i in RoundedRectangle(cornerRadius: 1.5).fill(c(s.ink, i == 0 ? 0.5 : 0.2)).frame(width: 16, height: 5) }
                        Spacer()
                        RoundedRectangle(cornerRadius: 2).fill(c(s.fill)).frame(width: 18, height: 7)
                    }.padding(6).background(c(s.paper))
                    HStack(alignment: .top, spacing: 5) {
                        ForEach(0..<3) { col in
                            VStack(spacing: 4) {
                                ForEach(Array(0..<(3 - col % 2)), id: \.self) { _ in RoundedRectangle(cornerRadius: 2).fill(c(s.raised)).overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(c(s.ink, 0.12), lineWidth: 0.5)).frame(height: 12) }
                            }.padding(3).background(RoundedRectangle(cornerRadius: 3).fill(c(s.paper)))
                        }
                    }.padding(6)
                }
            case .studio:
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(0..<3) { i in Rectangle().fill(i == 0 ? c(s.paper) : .clear).frame(width: 26, height: 10)
                            .overlay(alignment: .top) { if i == 0 { Rectangle().fill(c(s.accent)).frame(height: 1.5) } } }
                        Spacer()
                    }.background(c(s.paperDeep))
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Aa").font(.system(size: 11, design: .serif)).foregroundStyle(c(s.ink))
                            ForEach(0..<4) { _ in RoundedRectangle(cornerRadius: 1).fill(c(s.ink, 0.2)).frame(height: 3) }
                        }.padding(7).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(c(s.paper))
                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 1).fill(c(s.ink, 0.15)).frame(height: 6)
                            RoundedRectangle(cornerRadius: 1).fill(c(s.ink, 0.15)).frame(height: 6)
                            RoundedRectangle(cornerRadius: 1.5).fill(c(s.fill)).frame(height: 6)
                        }.padding(5).frame(width: 44)
                    }
                }
            }
        }
        .frame(width: 150, height: 86)
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
