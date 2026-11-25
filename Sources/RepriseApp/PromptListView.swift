import SwiftUI
import RepriseCore

struct PromptListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List(selection: $model.selectedID) {
            ForEach(model.items) { item in
                PromptRow(item: item, query: model.query)
                    .tag(item.id)
                    .draggable(String(item.id))
                    .contextMenu { PromptMenu(id: item.id, pinned: item.pinned) }
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .overlay {
            if model.items.isEmpty { EmptyList() }
        }
        .navigationTitle(title)
        .navigationSubtitle(subtitle)
        .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 460)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Picker("Sort", selection: $model.sort) {
                        ForEach(PromptSort.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: { Label("Sort", systemImage: "arrow.up.arrow.down") }
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
        if case .project(let id) = model.scope, let p = model.project(id), let s = model.space(p.spaceID) {
            return "\(s.name) · \(model.items.count.formatted()) prompts"
        }
        return "\(model.items.count.formatted()) prompts"
    }
}

struct EmptyList: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: model.query.isEmpty ? "text.badge.plus" : "magnifyingglass")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text(model.query.isEmpty ? "No prompts here yet" : "Nothing matches “\(model.query)”")
                .font(.headline)
            if model.query.isEmpty, model.scope != .trash {
                Button("New Prompt  ⌘N") { model.newPrompt() }
                    .buttonStyle(.glassProminent)
                Button("Harvest from Claude Code & Codex") { model.showHarvest = true }
                    .buttonStyle(.glass)
            }
        }
        .padding(30)
    }
}

struct PromptRow: View {
    let item: PromptSummary
    let query: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Capsule()
                .fill(Color(hex: item.color).gradient)
                .frame(width: 4)
                .padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(.body, weight: .semibold))
                        .lineLimit(1)
                    if item.pinned {
                        Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.orange)
                    }
                    Spacer(minLength: 4)
                    Text(item.updatedAt.relative)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                Text(item.snippet.isEmpty ? "Empty prompt" : item.snippet)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if item.isTemplate {
                        Badge(text: "template", icon: "curlybraces", color: Color(hex: item.color))
                    }
                    if item.useCount > 0 {
                        Badge(text: "×\(item.useCount)", icon: "arrow.trianglehead.2.clockwise", color: .secondary)
                    }
                    Text("\(Template.estimateTokens(length: item.length).formatted()) tok")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 1)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}

struct Badge: View {
    var text: String
    var icon: String
    var color: Color
    var body: some View {
        Label(text, systemImage: icon)
            .labelStyle(.titleAndIcon)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.13), in: Capsule())
    }
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
            Button("Use", systemImage: "play.fill") { model.use(id) }
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
            Button("Shuffle Color", systemImage: "dice") { model.setColor(id, Palette.random()) }
            Button("Toggle Agent Command", systemImage: "terminal") { model.toggleAgentCommand(id) }
            Divider()
            Button("Move to Trash", systemImage: "trash", role: .destructive) { model.trash(id) }
        }
    }
}
