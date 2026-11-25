import SwiftUI
import RepriseCore

/// The index: a table of contents, not a feed of snippets. One serif title per entry,
/// tabular token counts on the right, a small-caps apparatus line beneath, hairlines between.
struct PromptListView: View {
    @Environment(AppModel.self) private var model
    @LookSetting private var look
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var model = model
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
                            .contextMenu { PromptMenu(id: item.id, pinned: item.pinned) }
                    }
                }
                .padding(.vertical, 6)
            }
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
                if let id = model.selectedID { model.use(id); return .handled }
                return .ignored
            }
            .onChange(of: model.selectedID) { _, id in
                if let id { withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(id) } }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Ground(look: look).ignoresSafeArea())
        .overlay {
            if model.items.isEmpty { EmptyList() }
        }
        .navigationTitle(title)
        .navigationSubtitle(subtitle)
        .navigationSplitViewColumnWidth(min: 260, ideal: 310, max: 440)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Picker("Sort", selection: $model.sort) {
                        ForEach(PromptSort.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: { Label("Sort", systemImage: "arrow.up.arrow.down") }
                .help("Sort the index")
            }
        }
    }

    var title: String {
        switch model.scope {
        case .all: return "All Prompts"
        case .pinned: return "Pinned"
        case .templates: return "Templates"
        case .recent: return "Recently Used"
        case .trash: return "Trash"
        case .project(let id): return model.project(id)?.name ?? "Project"
        case .space(let id): return model.space(id)?.name ?? "Space"
        }
    }

    var subtitle: String {
        let n = model.items.count
        let count = "\(n.formatted()) prompt\(n == 1 ? "" : "s")"
        if case .project(let id) = model.scope, let p = model.project(id), let s = model.space(p.spaceID) {
            return "\(s.name), \(count)"
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
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                ColorKey(hex: item.color, size: 6)
                    .frame(width: 22, alignment: .leading)
                    .alignmentGuide(.firstTextBaseline) { d in d[.bottom] + 1 }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(item.title)
                            .font(.text(14.5, weight: selected ? .medium : Folio.style.entryWeight))
                            .foregroundStyle(selected && Folio.style.selection == .accentTitle ? Folio.rubric : Folio.ink)
                            .lineLimit(1)
                        if item.pinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8.5))
                                .foregroundStyle(Folio.slate)
                                .help("Pinned")
                        }
                        Spacer(minLength: 10)
                        Text(Template.estimateTokens(length: item.length).formatted())
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(Folio.slate)
                            .help("Approximate tokens")
                    }
                    HStack(spacing: 0) {
                        Caps(apparatus, size: 10)
                            .lineLimit(1)
                        Spacer(minLength: 10)
                        Caps(item.updatedAt.relative, size: 10)
                    }
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .padding(.vertical, 9)
            .background { SelectionBackground(selected: selected, active: active, hovering: hovering) }
            Hairline()
                .padding(.leading, 36)
                .padding(.trailing, 16)
                .opacity(selected ? 0 : 1)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    private var apparatus: String {
        var parts: [String] = []
        if let project { parts.append(project.name) }
        if item.useCount > 0 { parts.append("played \(item.useCount)×") }
        return parts.joined(separator: " · ")
    }
}

struct EmptyList: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.query.isEmpty ? "Nothing here yet." : "Nothing matches “\(model.query)”.")
                .font(.text(17))
                .foregroundStyle(Folio.ink)
            if model.query.isEmpty, model.scope != .trash {
                Text("Write a prompt you'll want again, or pull the ones you keep retyping out of your agent history.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Folio.slate)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button("New Prompt") { model.newPrompt() }
                        .buttonStyle(.borderedProminent)
                    Button("Harvest History…") { model.showHarvest = true }
                }
                .padding(.top, 4)
            } else if !model.query.isEmpty {
                Text("Search covers titles, text and tags. Try a shorter word.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Folio.slate)
            }
        }
        .frame(maxWidth: 260, alignment: .leading)
        .padding(24)
    }
}

/// Small-caps text label, used where a pill badge used to be.
struct Badge: View {
    var text: String
    var body: some View { Caps(text) }
}

struct PromptMenu: View {
    @Environment(AppModel.self) private var model
    let id: ID
    let pinned: Bool

    var body: some View {
        if model.scope == .trash {
            Button("Restore", systemImage: "arrow.uturn.backward") { model.trash(id) }
            Button("Delete Forever", systemImage: "trash.slash", role: .destructive) { model.deleteForever(id) }
        } else {
            Button("Use", systemImage: "play") { model.use(id) }
            Button("Copy Source", systemImage: "doc.on.doc") { model.copyRaw(id) }
            Divider()
            Button(pinned ? "Unpin" : "Pin", systemImage: pinned ? "pin.slash" : "pin") { model.togglePin(id) }
            Button("Duplicate", systemImage: "plus.square.on.square") { model.duplicate(id) }
            Menu("Move to", systemImage: "folder") {
                ForEach(model.spaces) { s in
                    Section(s.name) {
                        ForEach(model.projects.filter { $0.spaceID == s.id }) { p in
                            Button(p.name) { model.move(id, to: p.id) }
                        }
                    }
                }
            }
            Button("Toggle Agent Command", systemImage: "terminal") { model.toggleAgentCommand(id) }
            Divider()
            Button("Move to Trash", systemImage: "trash", role: .destructive) { model.trash(id) }
        }
    }
}
