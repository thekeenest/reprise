import SwiftUI
import RepriseCore

// The library is two levels you own: Spaces (broad areas: Engineering, Research, Clients)
// hold Projects (Daily Agent Work, Deep Dives). Every prompt lives in one project.
// Both levels are created, renamed, recolored, moved and deleted right here in the sidebar.

// MARK: Sidebar (both layouts)

struct LibrarySidebar: View {
    @Environment(AppModel.self) private var model
    /// Outline layout: projects unfold to show their prompts, and there is no separate list.
    var outline: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { withAnimation(.easeOut(duration: 0.2)) { model.showSidebar = false } } label: {
                    Image(systemName: "sidebar.left")
                }
                .buttonStyle(IconButtonStyle(size: 26))
                .help("Hide the sidebar (⌃⌘S)")
            }
            .padding(.horizontal, 10)
            .frame(height: 44)

            SearchField()
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

            if outline { FilterChips().padding(.horizontal, 12).padding(.bottom, 8) }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    if !outline {
                        SectionLabel(title: "Library")
                        ScopeRow(title: "All Prompts", icon: "tray.full", scope: .all, key: "all")
                        ScopeRow(title: "Pinned", icon: "pin", scope: .pinned, key: "pinned")
                        ScopeRow(title: "Templates", icon: "curlybraces", scope: .templates, key: "templates")
                        ScopeRow(title: "Recently Used", icon: "clock", scope: .recent, key: "recent")
                    }
                    SectionLabel(title: "Spaces") {
                        Button { model.namingRequest = .init(kind: .newSpace) } label: {
                            Image(systemName: "plus").font(.system(size: 10.5, weight: .bold))
                        }
                        .buttonStyle(IconButtonStyle(size: 22))
                        .help("New space (⌥⌘N): a broad area such as Engineering, Research or a client")
                    }
                    ForEach(model.spaces) { space in
                        SpaceGroup(space: space, outline: outline)
                    }
                    if model.spaces.isEmpty {
                        Text("Spaces hold your projects. Make one with +.")
                            .font(.system(size: 11.5)).foregroundStyle(Folio.slate)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                    }
                    Color.clear.frame(height: 10)
                    ScopeRow(title: "Trash", icon: "trash", scope: .trash, key: "trash")
                        .contextMenu {
                            if (model.counts["trash"] ?? 0) > 0 {
                                Button("Empty Trash", role: .destructive) { model.emptyTrash() }
                            }
                        }
                    if outline && model.scope == .trash {
                        ForEach(model.items) { OutlinePromptRow(item: $0, indent: 30) }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.never)

            HStack(spacing: 4) {
                Button { model.showHarvest = true } label: {
                    Label("Harvest", systemImage: "arrow.down.to.line").font(.system(size: 12))
                }
                .buttonStyle(GhostButtonStyle(height: 26))
                .help("Find the prompts you keep retyping in Claude Code and Codex (⇧⌘H)")
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 46)
        }
    }
}

struct SearchField: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var model = model
        let shape = ControlShape()
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass").font(.system(size: 11.5, weight: .medium)).foregroundStyle(Folio.slate)
            TextField("Search", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .focused($focused)
                .onSubmit { if let first = model.items.first { model.selectedID = first.id } }
            if model.query.isEmpty {
                Text("⌘K").font(.system(size: 10.5).monospacedDigit()).foregroundStyle(Folio.ash)
            } else {
                Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(Folio.ash)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(shape.fill(Folio.ink.opacity(focused ? 0.08 : 0.055)))
        .overlay(shape.stroke(focused ? Folio.rubric.opacity(0.6) : .clear, lineWidth: 1))
        .animation(.easeOut(duration: 0.15), value: focused)
        .onChange(of: model.focusSearchToken) { focused = true }
    }
}

struct SectionLabel<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack {
            Caps(title, size: 10.5)
            Spacer()
            trailing
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .frame(minHeight: 22)
    }
}

extension SectionLabel where Trailing == EmptyView {
    init(title: String) { self.title = title; self.trailing = EmptyView() }
}

/// A row in the sidebar: rounded, with a soft fill when selected and a wash on hover.
struct SidebarRowChrome: ViewModifier {
    var selected: Bool
    var indent: CGFloat = 0
    @State private var hovering = false
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Variant.glass ? 9 : 7, style: .continuous)
        content
            .padding(.leading, 10 + indent)
            .padding(.trailing, 10)
            .frame(height: 28)
            .background(shape.fill(selected ? Folio.ink.opacity(0.1) : hovering ? Folio.wash : .clear))
            .contentShape(shape)
            .onHover { hovering = $0 }
    }
}

struct ScopeRow: View {
    @Environment(AppModel.self) private var model
    let title: String
    let icon: String
    let scope: PromptScope
    let key: String

    var body: some View {
        let selected = model.scope == scope
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(selected ? Folio.rubric : Folio.slate)
                .frame(width: 16)
            Text(title).font(.system(size: 13)).foregroundStyle(Folio.ink)
            Spacer(minLength: 6)
            if let n = model.counts[key], n > 0 {
                Text(n.formatted()).font(.system(size: 11).monospacedDigit()).foregroundStyle(Folio.slate)
            }
        }
        .modifier(SidebarRowChrome(selected: selected))
        .onTapGesture { model.scope = model.scope == scope && scope == .trash && Variant.library == .outline ? .all : scope }
    }
}

/// A space and its projects. Click the name to see everything in the space; the chevron folds it.
struct SpaceGroup: View {
    @Environment(AppModel.self) private var model
    let space: Space
    let outline: Bool
    @State private var hovering = false

    var body: some View {
        let folded = model.foldedSpaces.contains(space.id)
        let projects = model.projects.filter { $0.spaceID == space.id }
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Button { model.toggleFold(space: space.id) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(Folio.slate)
                        .rotationEffect(.degrees(folded ? 0 : 90))
                        .frame(width: 14, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(folded ? "Show projects" : "Hide projects")

                if model.renaming == .space(space.id) {
                    RenameField(initial: space.name) { name in
                        var s = space; s.name = name; model.save(s)
                    }
                } else {
                    Text(space.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Folio.ink)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if hovering && model.renaming != .space(space.id) {
                    Button { model.namingRequest = .init(kind: .newProject(spaceID: space.id)) } label: {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(IconButtonStyle(size: 20))
                    .help("New project in \(space.name)")
                    Menu { SpaceMenu(space: space) } label: {
                        Image(systemName: "ellipsis").font(.system(size: 11, weight: .bold))
                    }
                    .menuStyle(.button).menuIndicator(.hidden).buttonStyle(IconButtonStyle(size: 20)).fixedSize()
                    .help("Rename, recolor or delete this space")
                } else if !outline {
                    let n = projects.reduce(0) { $0 + (model.counts["p\($1.id)"] ?? 0) }
                    if n > 0 { Text(n.formatted()).font(.system(size: 11).monospacedDigit()).foregroundStyle(Folio.ash) }
                }
            }
            .padding(.leading, -4)
            .modifier(SidebarRowChrome(selected: model.scope == .space(space.id)))
            .onTapGesture { if !outline { model.scope = .space(space.id) } else { model.toggleFold(space: space.id) } }
            .onTapGesture(count: 2) { model.renaming = .space(space.id) }
            .contextMenu { SpaceMenu(space: space) }

            if !folded {
                ForEach(projects) { p in
                    ProjectRow(project: p, outline: outline)
                }
                if hovering && !outline {
                    Button { model.namingRequest = .init(kind: .newProject(spaceID: space.id)) } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "plus").font(.system(size: 9.5, weight: .bold)).frame(width: 10)
                            Text("New Project").font(.system(size: 12))
                        }
                        .foregroundStyle(Folio.slate)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .modifier(SidebarRowChrome(selected: false, indent: 14))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
        }
        .padding(.top, 2)
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
    }
}

struct SpaceMenu: View {
    @Environment(AppModel.self) private var model
    let space: Space
    var body: some View {
        Button("New Project in \(space.name)…") { model.namingRequest = .init(kind: .newProject(spaceID: space.id)) }
        Divider()
        Button("Rename Space") { model.renaming = .space(space.id) }
        Button("Edit Space…") { model.namingRequest = .init(kind: .editSpace(space)) }
        Button("Shuffle Color") { var s = space; s.color = Palette.random(); model.save(s) }
        Divider()
        Button("Delete Space…", role: .destructive) { model.confirmDelete = .space(space) }
    }
}

struct ProjectRow: View {
    @Environment(AppModel.self) private var model
    let project: Project
    let outline: Bool
    @State private var targeted = false

    var body: some View {
        let count = model.counts["p\(project.id)"] ?? 0
        let unfolded = outline && (model.openProjects.contains(project.id) || model.filtering)
        let prompts = outline ? model.items.filter { $0.projectID == project.id } : []
        if outline && model.filtering && prompts.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 9) {
                    if outline {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(Folio.slate)
                            .rotationEffect(.degrees(unfolded ? 90 : 0))
                            .frame(width: 8)
                    }
                    ColorKey(hex: project.color, size: 8)
                        .frame(width: 12)
                    if model.renaming == .project(project.id) {
                        RenameField(initial: project.name) { name in
                            var p = project; p.name = name; model.save(p)
                        }
                    } else {
                        Text(project.name).font(.system(size: 13)).foregroundStyle(Folio.ink).lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    let n = outline ? (model.filtering ? prompts.count : count) : count
                    if n > 0 { Text(n.formatted()).font(.system(size: 11).monospacedDigit()).foregroundStyle(Folio.slate) }
                }
                .modifier(SidebarRowChrome(selected: !outline && model.scope == .project(project.id), indent: 14))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(targeted ? Folio.rubric : .clear, lineWidth: 1.5))
                .onTapGesture {
                    if outline { model.toggleOpen(project: project.id) } else { model.scope = .project(project.id) }
                }
                .onTapGesture(count: 2) { model.renaming = .project(project.id) }
                .dropDestination(for: String.self) { items, _ in
                    for s in items { if let id = ID(s) { model.move(id, to: project.id) } }
                    return true
                } isTargeted: { targeted = $0 }
                .contextMenu { ProjectMenu(project: project) }

                if unfolded {
                    ForEach(prompts) { OutlinePromptRow(item: $0, indent: 44) }
                    if prompts.isEmpty {
                        Text("No prompts yet")
                            .font(.system(size: 11.5)).foregroundStyle(Folio.ash)
                            .padding(.leading, 54).frame(height: 24)
                    }
                }
            }
        }
    }
}

struct ProjectMenu: View {
    @Environment(AppModel.self) private var model
    let project: Project
    var body: some View {
        Button("New Prompt in \(project.name)") { model.scopeForNew(project.id); model.newPrompt() }
        Divider()
        Button("Rename Project") { model.renaming = .project(project.id) }
        Button("Edit Project…") { model.namingRequest = .init(kind: .editProject(project)) }
        Button("Shuffle Color") { var p = project; p.color = Palette.random(); model.save(p) }
        Menu("Move to Space") {
            ForEach(model.spaces) { s in
                Button { var p = project; p.spaceID = s.id; model.save(p) } label: {
                    if s.id == project.spaceID { Label(s.name, systemImage: "checkmark") } else { Text(s.name) }
                }
            }
            Divider()
            Button("New Space…") { model.namingRequest = .init(kind: .newSpace) }
        }
        Divider()
        Button("Delete Project…", role: .destructive) { model.confirmDelete = .project(project) }
    }
}

/// In-place rename. Names are required: an empty name keeps the old one.
struct RenameField: View {
    @Environment(AppModel.self) private var model
    let initial: String
    let commit: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("Name", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .focused($focused)
            .padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Folio.raised))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Folio.rubric, lineWidth: 1))
            .onAppear { text = initial; DispatchQueue.main.async { focused = true } }
            .onSubmit(done)
            .onChange(of: focused) { _, f in if !f { done() } }
            .onExitCommand { model.renaming = nil }
    }

    private func done() {
        guard model.renaming != nil else { return }
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty, t != initial { commit(t) }
        model.renaming = nil
    }
}

// MARK: Outline layout

/// All · Pinned · Templates · Recent, as one quiet segmented row.
struct FilterChips: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        HStack(spacing: 4) {
            chip("All", .all)
            chip("Pinned", .pinned)
            chip("Templates", .templates)
            chip("Recent", .recent)
        }
    }

    private func chip(_ t: String, _ s: PromptScope) -> some View {
        let on = model.scope == s
        return Button { withAnimation(.easeOut(duration: 0.15)) { model.scope = s } } label: {
            Text(t)
                .font(.system(size: 11.5, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? Folio.ink : Folio.slate)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(ControlShape().fill(on ? Folio.ink.opacity(0.1) : .clear))
                .contentShape(ControlShape())
        }
        .buttonStyle(.plain)
    }
}

struct OutlinePromptRow: View {
    @Environment(AppModel.self) private var model
    let item: PromptSummary
    var indent: CGFloat = 44
    @State private var hovering = false

    var body: some View {
        let selected = item.id == model.selectedID
        let shape = RoundedRectangle(cornerRadius: Variant.glass ? 9 : 7, style: .continuous)
        HStack(spacing: 6) {
            Text(item.title)
                .font(.text(13.5, weight: selected ? .medium : .regular))
                .foregroundStyle(selected ? Folio.ink : Folio.ink.opacity(0.86))
                .lineLimit(1)
            if item.pinned { Image(systemName: "pin.fill").font(.system(size: 8)).foregroundStyle(Folio.ash) }
            Spacer(minLength: 6)
            if item.isTemplate {
                Image(systemName: "curlybraces").font(.system(size: 9, weight: .semibold)).foregroundStyle(Folio.ash)
            }
        }
        .padding(.leading, indent)
        .padding(.trailing, 10)
        .frame(height: 27)
        .background(shape.fill(selected ? Folio.rubric.opacity(0.16) : hovering ? Folio.wash : .clear))
        .overlay(alignment: .leading) {
            if selected {
                Capsule().fill(Folio.rubric).frame(width: 3, height: 14).padding(.leading, indent - 10)
            }
        }
        .contentShape(shape)
        .onHover { hovering = $0 }
        .onTapGesture { model.selectedID = item.id }
        .draggable(String(item.id))
        .contextMenu { PromptRowMenu(item: item) }
    }
}

// MARK: Prompt list (columns layout)

struct PromptList: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.scopeTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Folio.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Folio.slate)
                        .lineLimit(1)
                }
                Spacer()
                Menu {
                    Picker("Sort", selection: $model.sort) {
                        ForEach(PromptSort.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "arrow.up.arrow.down").font(.system(size: 12, weight: .medium))
                }
                .menuStyle(.button).menuIndicator(.hidden).buttonStyle(IconButtonStyle()).fixedSize()
                .help("Sort")
            }
            .padding(.leading, model.showSidebar ? 18 : 84)
            .padding(.trailing, 10)
            .frame(height: 52)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.items) { item in
                            IndexRow(item: item,
                                     project: model.project(item.projectID),
                                     selected: item.id == model.selectedID,
                                     active: focused)
                                .id(item.id)
                                .onTapGesture { model.selectedID = item.id; focused = true }
                                .draggable(String(item.id))
                                .contextMenu { PromptRowMenu(item: item) }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.never)
                .focusable()
                .focused($focused)
                .focusEffectDisabled()
                .onMoveCommand { dir in
                    guard !model.items.isEmpty else { return }
                    let i = model.items.firstIndex { $0.id == model.selectedID } ?? -1
                    switch dir {
                    case .down: model.selectedID = model.items[min(i + 1, model.items.count - 1)].id
                    case .up: model.selectedID = model.items[max(i - 1, 0)].id
                    default: break
                    }
                }
                .onKeyPress(.return) {
                    if model.current != nil { model.copyCurrent(); return .handled }
                    return .ignored
                }
                .onChange(of: model.selectedID) { _, id in
                    if let id { withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(id) } }
                }
            }
            .overlay { if model.items.isEmpty { EmptyList() } }
        }
    }

    private var subtitle: String {
        let n = model.items.count
        let count = "\(n.formatted()) prompt\(n == 1 ? "" : "s")"
        if case .project(let id) = model.scope, let p = model.project(id), let s = model.space(p.spaceID) {
            return "\(s.name) · \(count)"
        }
        return count
    }
}

struct IndexRow: View {
    let item: PromptSummary
    let project: Project?
    let selected: Bool
    let active: Bool
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            ColorKey(hex: item.color, size: 7)
                .frame(width: 20, alignment: .leading)
                .alignmentGuide(.firstTextBaseline) { d in d[.bottom] + 1 }
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.title)
                        .font(.text(14.5, weight: selected ? .medium : .regular))
                        .foregroundStyle(Folio.ink)
                        .lineLimit(1)
                    if item.pinned {
                        Image(systemName: "pin.fill").font(.system(size: 8.5)).foregroundStyle(Folio.slate).help("Pinned")
                    }
                    Spacer(minLength: 10)
                    Text(Template.estimateTokens(length: item.length).formatted())
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(Folio.slate)
                        .help("Approximate tokens")
                }
                HStack(spacing: 0) {
                    Caps(apparatus, size: 10).lineLimit(1)
                    Spacer(minLength: 10)
                    Caps(item.updatedAt.relative, size: 10)
                }
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.vertical, 10)
        .background {
            let shape = RoundedRectangle(cornerRadius: Variant.glass ? 12 : 9, style: .continuous)
            Group {
                if selected { shape.fill(Folio.ink.opacity(active ? 0.1 : 0.075)) }
                else if hovering { shape.fill(Folio.wash) }
            }
            .padding(.horizontal, 8)
        }
        .overlay(alignment: .leading) {
            if selected { Capsule().fill(Folio.rubric).frame(width: 3, height: 18).padding(.leading, 3) }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    private var apparatus: String {
        var parts: [String] = []
        if let project { parts.append(project.name) }
        if item.isTemplate { parts.append("template") }
        if item.useCount > 0 { parts.append("played \(item.useCount)×") }
        return parts.joined(separator: " · ")
    }
}

struct EmptyList: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.query.isEmpty ? "Nothing here yet." : "Nothing matches “\(model.query)”.")
                .font(.text(16))
                .foregroundStyle(Folio.ink)
            Text(model.query.isEmpty ? "Press ⌘N to write a prompt here." : "Search covers titles, text and tags.")
                .font(.system(size: 12))
                .foregroundStyle(Folio.slate)
        }
        .frame(maxWidth: 240, alignment: .leading)
        .padding(24)
    }
}

struct PromptRowMenu: View {
    @Environment(AppModel.self) private var model
    let item: PromptSummary
    var body: some View {
        if model.scope == .trash {
            Button("Restore") { model.trash(item.id) }
            Button("Delete Forever", role: .destructive) { model.deleteForever(item.id) }
        } else {
            Button("Copy Prompt") { model.use(item.id) }
            Button("Copy Template Source") { model.copyRaw(item.id) }
            Divider()
            Button(item.pinned ? "Unpin" : "Pin") { model.togglePin(item.id) }
            Button("Duplicate") { model.duplicate(item.id) }
            MoveMenu(promptID: item.id, current: item.projectID)
            Divider()
            Button("Move to Trash", role: .destructive) { model.trash(item.id) }
        }
    }
}
