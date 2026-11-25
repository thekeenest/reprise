import SwiftUI
import RepriseCore

/// Console: launcher-first. One search field at the top, results on the left, the selected prompt
/// ready to run on the right, an action bar at the bottom. No sidebar, no list of notes.
struct ConsoleView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            commandBar
            Hairline()
            HStack(spacing: 0) {
                ConsoleResults()
                    .frame(width: 340)
                Hairline(vertical: true)
                ConsoleDetail()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Hairline()
            ConsoleActionBar(focusSearch: { searchFocused = true })
        }
        .background(Folio.paper.ignoresSafeArea())
        .onAppear {
            if model.selectedID == nil { model.selectedID = model.items.first?.id }
            searchFocused = true
        }
        .onChange(of: model.focusSearchToken) { searchFocused = true }
    }

    private var commandBar: some View {
        @Bindable var model = model
        return HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Folio.slate)
            TextField("Search prompts", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .foregroundStyle(Folio.ink)
                .focused($searchFocused)
                .onKeyPress(.downArrow) { step(1); return .handled }
                .onKeyPress(.upArrow) { step(-1); return .handled }
                .onSubmit { model.copyCurrent() }
            if !model.query.isEmpty {
                Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(Folio.ash)
            }
            ScopeMenu()
            NewPromptButton()
        }
        .padding(.horizontal, 20)
        .frame(height: 60)
    }

    private func step(_ d: Int) {
        guard !model.items.isEmpty else { return }
        let i = model.items.firstIndex { $0.id == model.selectedID } ?? -1
        let next = max(0, min(model.items.count - 1, i + d))
        model.editing = false
        model.selectedID = model.items[next].id
    }
}

struct ConsoleResults: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    let pinned = model.items.filter(\.pinned)
                    let rest = model.items.filter { !$0.pinned }
                    if model.query.isEmpty && model.scope == .all && !pinned.isEmpty {
                        header("Pinned")
                        ForEach(pinned) { row($0) }
                        header("Everything else")
                        ForEach(rest) { row($0) }
                    } else {
                        header(model.query.isEmpty ? model.scopeTitle : "\(model.items.count) results")
                        ForEach(model.items) { row($0) }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
            }
            .onChange(of: model.selectedID) { _, id in
                if let id { withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(id) } }
            }
        }
        .overlay {
            if model.items.isEmpty {
                VStack(spacing: 8) {
                    Text(model.query.isEmpty ? "Nothing here yet" : "No prompt matches")
                        .font(.system(size: 13.5, weight: .medium)).foregroundStyle(Folio.ink)
                    Text(model.query.isEmpty ? "Press ⌘N to write one." : "Press ⌘N to write it.")
                        .font(.system(size: 12)).foregroundStyle(Folio.slate)
                }
            }
        }
        .background(Folio.paperDeep)
    }

    private func header(_ t: String) -> some View {
        Caps(t).padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 4)
    }

    private func row(_ item: PromptSummary) -> some View {
        ConsoleRow(item: item, project: model.project(item.projectID), selected: item.id == model.selectedID)
            .id(item.id)
            .onTapGesture { model.editing = false; model.selectedID = item.id }
            .onTapGesture(count: 2) { model.selectedID = item.id; model.editing = true }
            .contextMenu {
                Button("Copy") { model.use(item.id) }
                Button("Edit") { model.selectedID = item.id; model.editing = true }
                Divider()
                Button(item.pinned ? "Unpin" : "Pin") { model.togglePin(item.id) }
                Button("Move to Trash", role: .destructive) { model.trash(item.id) }
            }
            .draggable(String(item.id))
    }
}

struct ConsoleRow: View {
    let item: PromptSummary
    let project: Project?
    let selected: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            ColorKey(hex: item.color, size: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13.5, weight: selected ? .semibold : .regular))
                    .foregroundStyle(Folio.ink)
                    .lineLimit(1)
                Text([project?.name, item.useCount > 0 ? "used \(item.useCount)×" : nil].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Folio.slate)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if item.isTemplate {
                Image(systemName: "curlybraces")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Folio.ash)
                    .help("Template: has blanks to fill")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: Folio.radius, style: .continuous)
                .fill(selected ? Folio.ink.opacity(0.09) : hovering ? Folio.wash : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

struct ConsoleDetail: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let p = model.current {
            if model.editing {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Button { model.flushSave(); model.editing = false } label: {
                            HStack(spacing: 5) { Image(systemName: "chevron.left"); Text("Done") }
                        }
                        .buttonStyle(GhostButtonStyle())
                        .keyboardShortcut(.escape, modifiers: [])
                        Text("Editing").font(.system(size: 12)).foregroundStyle(Folio.slate)
                        Spacer()
                        ActionsButton(prompt: p)
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 48)
                    Hairline()
                    HStack(spacing: 0) {
                        PageEditor(prompt: p, inset: 36, topPadding: 18)
                        Hairline(vertical: true)
                        ScrollView { DetailsView(prompt: p).padding(20) }
                            .frame(width: 260)
                            .scrollIndicators(.never)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(p.title)
                                .font(.title)
                                .tracking(Folio.style.titleTracking)
                                .foregroundStyle(Folio.ink)
                                .lineLimit(2)
                            HStack(spacing: 8) {
                                PlaceText(projectID: p.projectID)
                                if p.useCount > 0 {
                                    Text("·").foregroundStyle(Folio.ash)
                                    Text("used \(p.useCount)×").font(.system(size: 12)).foregroundStyle(Folio.slate)
                                }
                            }
                        }
                        Spacer()
                        Button { model.editing = true } label: {
                            HStack(spacing: 5) { Image(systemName: "pencil"); Text("Edit") }
                        }
                        .buttonStyle(GhostButtonStyle())
                        .help("Edit the prompt (⌘E)")
                        ActionsButton(prompt: p)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                    RunPanel()
                        .padding(.horizontal, 28)
                        .padding(.bottom, 24)
                        .frame(maxWidth: 760, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        } else {
            StartHere(title: "Search, or start a new prompt.")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ConsoleActionBar: View {
    @Environment(AppModel.self) private var model
    var focusSearch: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            RepriseMark(size: 15)
            Text("\(model.items.count.formatted()) prompts")
                .font(.system(size: 12))
                .foregroundStyle(Folio.slate)
            Spacer()
            if model.current != nil {
                KeyHint(key: "⌘↩", label: "Copy") { model.copyCurrent() }
                KeyHint(key: "⌘E", label: model.editing ? "Done" : "Edit") { model.editing.toggle() }
            }
            KeyHint(key: "⌘N", label: "New") { model.newPrompt() }
            KeyHint(key: "⌘K", label: "Search") { focusSearch() }
        }
        .padding(.horizontal, 18)
        .frame(height: 38)
        .background(Folio.paperDeep)
    }
}
