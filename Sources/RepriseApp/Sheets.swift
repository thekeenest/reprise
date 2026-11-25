import SwiftUI
import RepriseCore

/// The shade pool: curated anchors + an endless, harmonious random generator (OKLCH).
struct ShadePicker: View {
    let hex: String
    var onPick: (String) -> Void
    @State private var pool: [String] = []
    @State private var custom: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Color").font(.headline)
                Spacer()
                Button {
                    let h = Palette.random(); onPick(h); regenerate()
                } label: { Label("Surprise me", systemImage: "dice.fill") }
                .buttonStyle(.glass)
            }
            grid(Palette.curated)
            Divider()
            HStack {
                Text("Shades near this one").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { regenerate() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain)
            }
            grid(pool)
            HStack {
                ColorPicker("Custom", selection: $custom, supportsOpacity: false)
                    .onChange(of: custom) { _, c in onPick(c.hexString) }
                Spacer()
                Text(hex).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
        .padding(16)
        .frame(width: 300)
        .onAppear { custom = Color(hex: hex); regenerate() }
    }

    private func regenerate() {
        let h = Palette.hue(hex)
        pool = (0..<16).map { i in i < 8 ? Palette.random(near: h) : Palette.random() }
    }

    private func grid(_ colors: [String]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(26), spacing: 8), count: 8), spacing: 8) {
            ForEach(colors, id: \.self) { c in
                Button { onPick(c) } label: {
                    Circle().fill(Color(hex: c).gradient)
                        .frame(width: 24, height: 24)
                        .overlay(Circle().strokeBorder(.primary.opacity(c == hex ? 0.9 : 0), lineWidth: 2).padding(-3))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Names are required for spaces and projects. Colors default to a fresh random shade.
struct NamingSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let request: AppModel.NamingRequest
    @State private var name = ""
    @State private var color = Palette.random()
    @State private var icon = "square.stack.3d.up.fill"
    @State private var showColors = false

    static let icons = ["square.stack.3d.up.fill", "hammer.fill", "briefcase.fill", "sparkle.magnifyingglass", "brain.head.profile",
                        "chevron.left.forwardslash.chevron.right", "paintbrush.pointed.fill", "megaphone.fill", "chart.line.uptrend.xyaxis",
                        "graduationcap.fill", "person.crop.circle.fill", "shippingbox.fill", "bolt.fill", "leaf.fill", "globe", "lock.shield.fill"]

    var isSpace: Bool {
        switch request.kind { case .newSpace, .editSpace: return true; default: return false }
    }

    var heading: String {
        switch request.kind {
        case .newSpace: return "New Space"
        case .newProject: return "New Project"
        case .editSpace: return "Edit Space"
        case .editProject: return "Edit Project"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Button { showColors.toggle() } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(hex: color).gradient).frame(width: 44, height: 44)
                        if isSpace { Image(systemName: icon).foregroundStyle(.white).font(.title3) }
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showColors) { ShadePicker(hex: color) { color = $0 } }
                VStack(alignment: .leading, spacing: 2) {
                    Text(heading).font(.title2.bold())
                    Text(isSpace ? "An area of your work — clients, research, open source…" : "A named home for related prompts")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }

            TextField(isSpace ? "Space name" : "Project name", text: $name)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .onSubmit(save)

            HStack {
                Text("Color").foregroundStyle(.secondary)
                ForEach(Palette.curated.prefix(10), id: \.self) { c in
                    Button { color = c } label: { ColorDot(hex: c, size: 16) }.buttonStyle(.plain)
                }
                Button { color = Palette.random() } label: { Image(systemName: "dice.fill") }
                    .buttonStyle(.plain)
                    .help("Random shade")
            }

            if isSpace {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(30)), count: 8), spacing: 8) {
                    ForEach(Self.icons, id: \.self) { i in
                        Button { icon = i } label: {
                            Image(systemName: i).frame(width: 28, height: 28)
                                .background(icon == i ? Color(hex: color).opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(isNew ? "Create" : "Save", action: save)
                    .buttonStyle(.glassProminent)
                    .tint(Color(hex: color))
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            switch request.kind {
            case .editSpace(let s): name = s.name; color = s.color; icon = s.icon
            case .editProject(let p): name = p.name; color = p.color
            case .newProject(let sid): color = Palette.random(near: model.space(sid).map { Palette.hue($0.color) })
            case .newSpace: break
            }
        }
    }

    var isNew: Bool {
        switch request.kind { case .newSpace, .newProject: return true; default: return false }
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        switch request.kind {
        case .newSpace: model.createSpace(name: n, color: color, icon: icon)
        case .newProject(let sid): model.createProject(spaceID: sid, name: n, color: color)
        case .editSpace(var s): s.name = n; s.color = color; s.icon = icon; model.save(s)
        case .editProject(var p): p.name = n; p.color = color; model.save(p)
        }
        dismiss()
    }
}

/// Fill a template: one field per variable, live preview, remembers your last values.
struct FillSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let prompt: Prompt
    @State private var values: [String: String] = [:]
    @FocusState private var focused: String?

    var body: some View {
        let vars = model.store.variables(prompt)
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    ColorDot(hex: prompt.color, size: 14)
                    Text(prompt.title).font(.title3.bold()).lineLimit(1)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(vars) { v in VariableField(variable: v, value: binding(v), focused: $focused) }
                    }
                    .padding(.vertical, 4)
                }
                Spacer(minLength: 0)
                HStack {
                    Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button {
                        model.copy(prompt, values: values); dismiss()
                    } label: { Label("Copy", systemImage: "doc.on.doc.fill") }
                    .buttonStyle(.glassProminent)
                    .tint(Color(hex: prompt.color))
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding(22)
            .frame(width: 340)
            .clipped()

            Divider()

            ScrollView {
                Text(preview)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
                    .padding(.top, 26)
            }
            .background(Color(hex: prompt.color).opacity(0.05))
            .overlay(alignment: .topTrailing) {
                Text("~\(Template.estimateTokens(preview).formatted()) tokens")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .padding(8).glassEffect(.regular, in: .capsule).padding(10)
            }
        }
        .frame(width: 860, height: 540)
        .onAppear {
            values = Prefs.lastValues(for: prompt.id)
            focused = vars.first?.name
        }
    }

    var preview: String {
        model.store.payload(prompt, values: values, includeAttachments: Prefs.includeAttachmentPaths, clipboard: Paster.clipboardString)
    }

    func binding(_ v: Template.Variable) -> Binding<String> {
        Binding(get: { values[v.name] ?? "" }, set: { values[v.name] = $0 })
    }
}

struct VariableField: View {
    let variable: Template.Variable
    @Binding var value: String
    var focused: FocusState<String?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(variable.name).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if variable.isChoice {
                let picker = Picker("", selection: Binding(get: { value.isEmpty ? variable.defaultValue : value }, set: { value = $0 })) {
                    ForEach(variable.options, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                if variable.fitsSegmented { picker.pickerStyle(.segmented) } else { picker.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading) }
            } else {
                TextField(variable.defaultValue.isEmpty ? variable.name : variable.defaultValue, text: $value, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...8)
                    .focused(focused, equals: variable.name)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HistorySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let prompt: Prompt
    @State private var versions: [PromptVersion] = []
    @State private var selected: PromptVersion.ID?

    var body: some View {
        NavigationSplitView {
            List(versions, selection: $selected) { v in
                VStack(alignment: .leading) {
                    Text(v.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.body.weight(.medium))
                    Text("\(v.body.count.formatted()) chars").font(.caption).foregroundStyle(.secondary)
                }
            }
            .overlay { if versions.isEmpty { Text("No earlier versions yet").foregroundStyle(.secondary) } }
            .navigationSplitViewColumnWidth(220)
        } detail: {
            if let v = versions.first(where: { $0.id == selected }) {
                ScrollView {
                    Text(v.body).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(20)
                }
                .toolbar {
                    Button("Restore This Version") { model.restore(v) }.buttonStyle(.glassProminent).tint(Color(hex: prompt.color))
                }
            } else {
                Text("Select a version").foregroundStyle(.secondary)
            }
        }
        .toolbar { Button("Done") { dismiss() } }
        .frame(width: 820, height: 520)
        .onAppear { versions = (try? model.store.versions(prompt.id)) ?? []; selected = versions.first?.id }
    }
}

struct HarvestView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [Harvest.Candidate] = []
    @State private var picked: Set<String> = []
    @State private var focus: String?
    @State private var loading = true
    @State private var projectID: ID = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Harvest", systemImage: "leaf.fill").font(.title2.bold()).foregroundStyle(.green)
                    Text("Prompts you keep retyping in Claude Code and Codex, ranked by how much retyping they cost you. Read locally, never uploaded.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)

            HSplitView {
                List(candidates, selection: $focus) { c in
                    HStack(alignment: .top, spacing: 10) {
                        Toggle("", isOn: Binding(get: { picked.contains(c.key) }, set: { if $0 { picked.insert(c.key) } else { picked.remove(c.key) } }))
                            .labelsHidden()
                            .toggleStyle(.checkbox)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(c.suggestedTitle).font(.body.weight(.semibold)).lineLimit(1)
                            HStack(spacing: 6) {
                                Badge(text: "×\(c.count)", icon: "arrow.trianglehead.2.clockwise", color: c.count > 2 ? .orange : .secondary)
                                Text("\(c.text.count.formatted()) chars · \(c.sources.sorted().joined(separator: ", "))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tag(c.key)
                }
                .frame(minWidth: 340)

                ScrollView {
                    Text(candidates.first(where: { $0.key == focus })?.text ?? "Select a prompt to preview it")
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                }
                .frame(minWidth: 360)
            }
            .overlay { if loading { ProgressView("Reading your agent history…") } else if candidates.isEmpty { Text("No history found in ~/.claude or ~/.codex").foregroundStyle(.secondary) } }

            HStack {
                Picker("Save into", selection: $projectID) {
                    ForEach(model.spaces) { s in
                        Section(s.name) { ForEach(model.projects.filter { $0.spaceID == s.id }) { Text($0.name).tag($0.id) } }
                    }
                }
                .frame(width: 280)
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save \(picked.count) as Prompts") {
                    model.importHarvest(candidates.filter { picked.contains($0.key) }, projectID: projectID)
                    dismiss()
                }
                .buttonStyle(.glassProminent)
                .tint(.green)
                .disabled(picked.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 920, height: 620)
        .task {
            projectID = model.targetProjectID
            let found = await Task.detached(priority: .userInitiated) { Harvest.scan() }.value
            candidates = found
            picked = Set(found.prefix(5).filter { $0.count > 1 }.map(\.key))
            focus = found.first?.key
            loading = false
        }
    }
}

extension Template.Variable {
    /// Segmented controls only when the options are short enough to fit a 300pt column.
    var fitsSegmented: Bool { options.count <= 4 && options.joined().count <= 26 }
}
