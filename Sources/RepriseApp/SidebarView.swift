import SwiftUI
import RepriseCore

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List(selection: $model.scope) {
            Section {
                row("All Prompts", "tray.full.fill", .all, "all", color: .accentColor)
                row("Pinned", "pin.fill", .pinned, "pinned", color: .orange)
                row("Templates", "curlybraces", .templates, "templates", color: .purple)
                row("Recently Used", "clock.fill", .recent, "recent", color: .teal)
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
                row("Trash", "trash.fill", .trash, "trash", color: .secondary)
            }
        }
        .listStyle(.sidebar)
        .modifier(InkSidebar())
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Button {
                    model.namingRequest = .init(kind: .newSpace)
                } label: {
                    Label("New Space", systemImage: "plus.square.on.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                Button { model.showHarvest = true } label: {
                    Image(systemName: "leaf.fill")
                }
                .buttonStyle(.glass)
                .help("Harvest prompts you keep retyping in Claude Code & Codex")
            }
            .controlSize(.large)
            .tint(.primary)
            .padding(12)
        }
        .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 320)
    }

    private func row(_ title: String, _ icon: String, _ scope: PromptScope, _ key: String, color: Color) -> some View {
        HStack {
            Label { Text(title) } icon: { Image(systemName: icon).foregroundStyle(color) }
            Spacer()
            if let n = model.counts[key], n > 0 {
                Text(n.formatted()).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
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
            Image(systemName: space.icon)
                .font(.caption)
                .foregroundStyle(Color(hex: space.color))
            Text(space.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.75))
            Spacer()
            Menu {
                Button("New Project…", systemImage: "plus") { model.namingRequest = .init(kind: .newProject(spaceID: space.id)) }
                Button("Edit Space…", systemImage: "pencil") { model.namingRequest = .init(kind: .editSpace(space)) }
                Button("Show All in Space", systemImage: "square.stack") { model.scope = .space(space.id) }
                Divider()
                Button("Delete Space", systemImage: "trash", role: .destructive) { model.deleteSpace(space) }
            } label: {
                Image(systemName: "ellipsis.circle").font(.callout)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .opacity(hovering ? 1 : 0.0)
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
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(Color(hex: project.color).gradient)
                .frame(width: 12, height: 12)
                .shadow(color: Color(hex: project.color).opacity(0.45), radius: 3)
            Text(project.name).lineLimit(1)
            Spacer()
            if count > 0 {
                Text(count.formatted()).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .dropDestination(for: String.self) { items, _ in
            for s in items { if let id = ID(s) { model.move(id, to: project.id) } }
            return true
        }
        .contextMenu {
            Button("Edit Project…", systemImage: "pencil") { model.namingRequest = .init(kind: .editProject(project)) }
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

/// Ink trades the glass sidebar for a near-black slab — closer to a terminal than to Finder.
struct InkSidebar: ViewModifier {
    @AppStorage("look") private var look: Look = .liquid
    func body(content: Content) -> some View {
        if look == .ink {
            content.scrollContentBackground(.hidden).background(Color(white: 0.03))
        } else {
            content
        }
    }
}
