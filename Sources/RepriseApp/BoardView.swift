import SwiftUI
import RepriseCore

/// Board: spatial. Spaces are tabs, projects are columns, prompts are tiles you can drag between them.
/// Clicking a tile opens a run card over the board; Edit opens a focused writing surface.
struct BoardView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("boardSpace") private var spaceRaw: Int = 0

    private var spaceID: ID? {
        let id = ID(spaceRaw)
        return model.spaces.contains { $0.id == id } ? id : model.spaces.first?.id
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topBar
                Hairline()
                columns
            }
            .background(Folio.paperDeep.ignoresSafeArea())

            if model.current != nil && (model.showRun || model.editing) {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)
                if let p = model.current {
                    Group {
                        if model.editing { BoardEditCard(prompt: p, close: close) }
                        else { BoardRunCard(prompt: p, close: close) }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
                }
            }
        }
        .animation(.easeOut(duration: 0.16), value: model.showRun)
        .animation(.easeOut(duration: 0.16), value: model.editing)
        .onAppear { syncScope() }
        .onChange(of: spaceRaw) { syncScope() }
        .onChange(of: model.spaces.map(\.id)) { syncScope() }
    }

    private func close() {
        model.flushSave()
        model.editing = false
        model.showRun = false
    }

    private func syncScope() {
        if let s = spaceID, model.scope != .space(s) { model.scope = .space(s) }
    }

    // MARK: Top bar

    private var topBar: some View {
        @Bindable var model = model
        return HStack(spacing: 4) {
            ForEach(model.spaces) { s in
                SpaceTab(name: s.name, count: model.projects.filter { $0.spaceID == s.id }.reduce(0) { $0 + (model.counts["p\($1.id)"] ?? 0) }, selected: s.id == spaceID) {
                    spaceRaw = Int(s.id)
                }
                .contextMenu {
                    Button("Rename Space…") { model.namingRequest = .init(kind: .editSpace(s)) }
                    Button("New Project…") { model.namingRequest = .init(kind: .newProject(spaceID: s.id)) }
                    Divider()
                    Button("Delete Space", role: .destructive) { model.deleteSpace(s) }
                }
            }
            Button { model.namingRequest = .init(kind: .newSpace) } label: { Image(systemName: "plus") }
                .buttonStyle(IconButtonStyle())
                .help("New space (⌥⌘N)")
            Spacer(minLength: 16)
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(Folio.slate)
                TextField("Filter this space", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 10)
            .frame(width: 220, height: 30)
            .background(Folio.raised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Folio.rule, lineWidth: 1))
            NewPromptButton()
                .padding(.leading, 8)
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .background(Folio.paper)
    }

    // MARK: Columns

    private var columns: some View {
        let projects = model.projects.filter { $0.spaceID == spaceID }
        let byProject = Dictionary(grouping: model.items, by: \.projectID)
        return ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(projects) { p in
                    BoardColumn(project: p, items: byProject[p.id] ?? [])
                }
                Button {
                    if let s = spaceID { model.namingRequest = .init(kind: .newProject(spaceID: s)) }
                } label: {
                    HStack(spacing: 6) { Image(systemName: "plus"); Text("New Project") }
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Folio.slate)
                        .frame(width: 200, height: 44)
                        .overlay(RoundedRectangle(cornerRadius: Folio.radius, style: .continuous)
                            .strokeBorder(Folio.rule, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .scrollIndicators(.visible)
    }
}

struct SpaceTab: View {
    let name: String
    let count: Int?
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(name).font(.system(size: 13, weight: selected ? .semibold : .medium))
                if let count, count > 0 {
                    Text(count.formatted()).font(.system(size: 11.5).monospacedDigit()).foregroundStyle(Folio.ash)
                }
            }
            .foregroundStyle(selected || hovering ? Folio.ink : Folio.slate)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? Folio.ink.opacity(0.08) : hovering ? Folio.wash : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct BoardColumn: View {
    @Environment(AppModel.self) private var model
    let project: Project
    let items: [PromptSummary]
    @State private var hovering = false
    @State private var targeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ColorKey(hex: project.color, size: 8)
                Text(project.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Folio.ink).lineLimit(1)
                Text(items.count.formatted()).font(.system(size: 12).monospacedDigit()).foregroundStyle(Folio.ash)
                Spacer()
                Button {
                    model.scopeForNew(project.id); model.newPrompt()
                } label: { Image(systemName: "plus") }
                    .buttonStyle(IconButtonStyle(size: 24))
                    .help("New prompt in \(project.name)")
                Menu {
                    Button("Rename Project…") { model.namingRequest = .init(kind: .editProject(project)) }
                    Divider()
                    Button("Delete Project", role: .destructive) { model.deleteProject(project) }
                } label: { Image(systemName: "ellipsis") }
                    .menuStyle(.button).menuIndicator(.hidden)
                    .buttonStyle(IconButtonStyle(size: 24)).fixedSize()
            }
            .padding(.horizontal, 4)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in
                        BoardTile(item: item, selected: item.id == model.selectedID && model.showRun)
                            .onTapGesture {
                                model.editing = false
                                model.selectedID = item.id
                                model.showRun = true
                            }
                            .draggable(String(item.id))
                            .contextMenu {
                                Button("Copy") { model.use(item.id) }
                                Button("Edit") { model.selectedID = item.id; model.editing = true }
                                Divider()
                                Button(item.pinned ? "Unpin" : "Pin") { model.togglePin(item.id) }
                                Button("Duplicate") { model.duplicate(item.id) }
                                Button("Move to Trash", role: .destructive) { model.trash(item.id) }
                            }
                    }
                    if items.isEmpty {
                        Text(model.query.isEmpty ? "Drop prompts here, or press +." : "No matches.")
                            .font(.system(size: 12))
                            .foregroundStyle(Folio.ash)
                            .frame(maxWidth: .infinity, minHeight: 60)
                    }
                }
                .padding(.bottom, 12)
            }
            .scrollIndicators(.never)
        }
        .padding(10)
        .frame(width: 296)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: Folio.radius + 2, style: .continuous)
            .fill(targeted ? Folio.ink.opacity(0.06) : Folio.paper))
        .overlay(RoundedRectangle(cornerRadius: Folio.radius + 2, style: .continuous).strokeBorder(Folio.rule, lineWidth: 1))
        .dropDestination(for: String.self) { ids, _ in
            for s in ids { if let id = ID(s) { model.move(id, to: project.id) } }
            return true
        } isTargeted: { targeted = $0 }
    }
}

struct BoardTile: View {
    let item: PromptSummary
    let selected: Bool
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Folio.radius, style: .continuous)
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Folio.ink)
                    .lineLimit(2)
                Spacer(minLength: 4)
                if item.pinned {
                    Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(Folio.ash)
                }
            }
            Text(excerpt)
                .font(.system(size: 12))
                .foregroundStyle(Folio.slate)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                if item.isTemplate {
                    Text("Template")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Folio.rubric)
                }
                if item.useCount > 0 {
                    Text("used \(item.useCount)×").font(.system(size: 11)).foregroundStyle(Folio.ash)
                }
                Spacer()
                Text("\(Template.estimateTokens(length: item.length).formatted()) tok")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(Folio.ash)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Folio.raised, in: shape)
        .overlay(shape.strokeBorder(selected ? Folio.ink.opacity(0.5) : hovering ? Folio.ink.opacity(0.22) : Folio.rule, lineWidth: 1))
        .contentShape(shape)
        .onHover { hovering = $0 }
    }

    /// The first lines of the prompt, without markdown, includes, or template syntax.
    /// Blanks read as their names in brackets: "Implement [feature]".
    private var excerpt: String {
        var t = item.snippet
        t = t.replacingOccurrences(of: #"\{\{>[^}]*\}\}"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\{\{\s*@?([^}=:|]+?)\s*(?:[=:][^}]*)?\}\}"#, with: "[$1]", options: .regularExpression)
        t = t.replacingOccurrences(of: #"</?[A-Za-z_]+>"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"[#*`]"#, with: "", options: .regularExpression)
        return t.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

/// The run card: fill the blanks on the left, read the result on the right, copy.
struct BoardRunCard: View {
    @Environment(AppModel.self) private var model
    let prompt: Prompt
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(prompt.title)
                        .font(.title)
                        .tracking(Folio.style.titleTracking)
                        .foregroundStyle(Folio.ink)
                        .lineLimit(2)
                    PlaceText(projectID: prompt.projectID)
                }
                Spacer()
                Button { model.editing = true } label: {
                    HStack(spacing: 5) { Image(systemName: "pencil"); Text("Edit") }
                }
                .buttonStyle(GhostButtonStyle())
                .help("Edit the prompt (⌘E)")
                ActionsButton(prompt: prompt)
                Button(action: close) { Image(systemName: "xmark") }
                    .buttonStyle(IconButtonStyle())
                    .keyboardShortcut(.escape, modifiers: [])
                    .help("Close (esc)")
            }
            .padding(.horizontal, 26)
            .padding(.top, 22)
            .padding(.bottom, 18)
            Hairline()
            RunPanel(split: true)
                .padding(26)
        }
        .frame(width: 820, height: 520)
        .background(Folio.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Folio.rule, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 40, y: 20)
    }
}

/// The writing surface: the page, with the prompt's details beside it.
struct BoardEditCard: View {
    @Environment(AppModel.self) private var model
    let prompt: Prompt
    let close: () -> Void

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    PlaceText(projectID: prompt.projectID)
                    Spacer()
                    ActionsButton(prompt: prompt)
                    Button { model.flushSave(); model.editing = false; model.showRun = true } label: {
                        HStack(spacing: 5) { Image(systemName: "play.fill").font(.system(size: 9)); Text("Fill & Copy") }
                    }
                    .buttonStyle(GhostButtonStyle())
                    Button("Done", action: close)
                        .buttonStyle(FilledButtonStyle())
                        .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.horizontal, 20)
                .frame(height: 52)
                Hairline()
                HStack(spacing: 0) {
                    PageEditor(prompt: prompt, inset: 40, topPadding: 20)
                    Hairline(vertical: true)
                    ScrollView { DetailsView(prompt: prompt).padding(20) }
                        .frame(width: 270)
                        .scrollIndicators(.never)
                }
            }
            .frame(width: min(geo.size.width - 60, 1180), height: geo.size.height - 50)
            .background(Folio.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Folio.rule, lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 40, y: 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
