import SwiftUI
import RepriseCore

/// The keyed index of the library. Monochrome symbols, small-caps sections,
/// and projects marked by a square color key: the only color in the column.
struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @LookSetting private var look

    var body: some View {
        @Bindable var model = model
        List(selection: $model.scope) {
            Section {
                row("All Prompts", "text.page", .all, "all")
                row("Pinned", "pin", .pinned, "pinned")
                row("Templates", "curlybraces", .templates, "templates")
                row("Recently Used", "clock", .recent, "recent")
            } header: {
                Caps("Library")
            }

            ForEach(model.spaces) { space in
                Section {
                    ForEach(model.projects.filter { $0.spaceID == space.id }) { project in
                        ProjectRow(project: project, count: model.counts["p\(project.id)"] ?? 0)
                            .tag(PromptScope.project(project.id))
                    }
                } header: {
                    SpaceHeader(space: space)
                }
            }

            Section {
                row("Trash", "trash", .trash, "trash")
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Ground(look: look, deep: true).ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Hairline()
                HStack(spacing: 14) {
                    Button { model.namingRequest = .init(kind: .newSpace) } label: {
                        Label("New Space", systemImage: "plus")
                    }
                    .help("New space (⌥⌘N)")
                    Spacer()
                    Button { model.showHarvest = true } label: {
                        Label("Harvest", systemImage: "arrow.down.to.line")
                    }
                    .help("Find the prompts you keep retyping in Claude Code and Codex (⇧⌘H)")
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Folio.slate)
                .padding(.horizontal, 16)
                .frame(height: 38)
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 228, max: 300)
    }

    private func row(_ title: String, _ icon: String, _ scope: PromptScope, _ key: String) -> some View {
        HStack(spacing: 0) {
            Label { Text(title) } icon: { Image(systemName: icon).foregroundStyle(Folio.slate) }
            Spacer(minLength: 8)
            if let n = model.counts[key], n > 0 {
                Text(n.formatted()).font(.system(size: 11).monospacedDigit()).foregroundStyle(Folio.slate)
            }
        }
        .tag(scope)
        .contextMenu {
            if scope == .trash, (model.counts["trash"] ?? 0) > 0 {
                Button("Empty Trash", role: .destructive) { model.emptyTrash() }
            }
        }
    }
}

struct SpaceHeader: View {
    @Environment(AppModel.self) private var model
    let space: Space
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Caps(space.name)
            Spacer()
            Menu {
                Button("New Project…", systemImage: "plus") { model.namingRequest = .init(kind: .newProject(spaceID: space.id)) }
                Button("Rename Space…", systemImage: "pencil") { model.namingRequest = .init(kind: .editSpace(space)) }
                Button("Show All in Space", systemImage: "square.stack") { model.scope = .space(space.id) }
                Divider()
                Button("Delete Space", systemImage: "trash", role: .destructive) { model.deleteSpace(space) }
            } label: {
                Image(systemName: "plus").font(.system(size: 11, weight: .medium)).foregroundStyle(Folio.slate)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .opacity(hovering ? 1 : 0)
            .help("New project, rename, delete")
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { model.namingRequest = .init(kind: .editSpace(space)) }
    }
}

struct ProjectRow: View {
    @Environment(AppModel.self) private var model
    let project: Project
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            ColorKey(hex: project.color, size: 7)
                .frame(width: 16)
            Text(project.name).lineLimit(1)
            Spacer(minLength: 8)
            if count > 0 {
                Text(count.formatted()).font(.system(size: 11).monospacedDigit()).foregroundStyle(Folio.slate)
            }
        }
        .dropDestination(for: String.self) { items, _ in
            for s in items { if let id = ID(s) { model.move(id, to: project.id) } }
            return true
        }
        .contextMenu {
            Button("Rename Project…", systemImage: "pencil") { model.namingRequest = .init(kind: .editProject(project)) }
            Button("New Prompt Here", systemImage: "square.and.pencil") { model.scope = .project(project.id); model.newPrompt() }
            Menu("Move to Space") {
                ForEach(model.spaces.filter { $0.id != project.spaceID }) { s in
                    Button(s.name) { var p = project; p.spaceID = s.id; model.save(p) }
                }
            }
            Divider()
            Button("Delete Project", systemImage: "trash", role: .destructive) { model.deleteProject(project) }
        }
    }
}
