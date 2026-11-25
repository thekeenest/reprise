import SwiftUI
import AppKit
import RepriseCore

// Components shared by the three designs. One rule runs through all of them:
// there is exactly one way to get a prompt out, and it is called Copy.

// MARK: Buttons

/// The one filled button on a surface: New Prompt in the bar, Copy in the run panel.
struct FilledButtonStyle: ButtonStyle {
    var height: CGFloat = 30
    var fontSize: CGFloat = 12.5
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(Folio.onFill)
            .padding(.horizontal, 12)
            .frame(height: height)
            .background(Folio.fill, in: RoundedRectangle(cornerRadius: min(Folio.radius, height / 2), style: .continuous))
            .opacity(configuration.isPressed ? 0.78 : 1)
            .contentShape(Rectangle())
    }
}

/// Secondary actions: a quiet bordered button.
struct GhostButtonStyle: ButtonStyle {
    var height: CGFloat = 28
    func makeBody(configuration: Configuration) -> some View {
        GhostBody(label: configuration.label, pressed: configuration.isPressed, height: height)
    }
    private struct GhostBody<L: View>: View {
        let label: L
        let pressed: Bool
        let height: CGFloat
        @State private var hovering = false
        var body: some View {
            let shape = RoundedRectangle(cornerRadius: min(Folio.radius, height / 2), style: .continuous)
            label
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Folio.ink)
                .padding(.horizontal, 10)
                .frame(minWidth: height, minHeight: height)
                .background(shape.fill(hovering || pressed ? Folio.wash : Color.clear))
                .overlay(shape.strokeBorder(Folio.rule, lineWidth: 1))
                .contentShape(shape)
                .onHover { hovering = $0 }
        }
    }
}

/// A glyph-only button with a hover wash.
struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 28
    func makeBody(configuration: Configuration) -> some View {
        IconBody(label: configuration.label, pressed: configuration.isPressed, size: size)
    }
    private struct IconBody<L: View>: View {
        let label: L
        let pressed: Bool
        let size: CGFloat
        @State private var hovering = false
        var body: some View {
            label
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(hovering ? Folio.ink : Folio.slate)
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: min(Folio.radius, 7), style: .continuous)
                    .fill(hovering || pressed ? Folio.wash : Color.clear))
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
        }
    }
}

/// "+ New Prompt". Always visible, always the same words.
struct NewPromptButton: View {
    @Environment(AppModel.self) private var model
    var projectID: ID? = nil
    var compact = false
    var body: some View {
        Button {
            if let projectID { model.scopeForNew(projectID) }
            model.newPrompt()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus").font(.system(size: 11.5, weight: .bold))
                if !compact { Text("New Prompt") }
            }
        }
        .buttonStyle(FilledButtonStyle())
        .help("New prompt (⌘N)")
    }
}

// MARK: Run

/// Fill the blanks, read what will be copied, copy it. The whole job of a prompt library.
struct RunPanel: View {
    @Environment(AppModel.self) private var model
    /// Side by side (fields left, preview right) instead of stacked.
    var split = false
    @FocusState private var focused: String?

    var body: some View {
        if split {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    fields
                    Spacer(minLength: 0)
                    CopyButton()
                }
                .frame(width: 300)
                PreviewBox(text: model.preview)
            }
        } else {
            VStack(alignment: .leading, spacing: 18) {
                fields
                PreviewBox(text: model.preview)
                CopyButton()
            }
        }
    }

    @ViewBuilder private var fields: some View {
        if model.blanks.isEmpty {
            Text("No blanks to fill. Copy takes the prompt as written.")
                .font(.system(size: 12.5))
                .foregroundStyle(Folio.slate)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(model.blanks.enumerated()), id: \.element.id) { i, v in
                    BlankField(index: i, variable: v, focused: $focused)
                }
            }
        }
    }
}

struct BlankField: View {
    @Environment(AppModel.self) private var model
    let index: Int
    let variable: Template.Variable
    var focused: FocusState<String?>.Binding

    var body: some View {
        let isFocused = focused.wrappedValue == variable.name
        let shape = RoundedRectangle(cornerRadius: min(Folio.radius, 7), style: .continuous)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                BlankKey(index: index)
                Text(variable.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Folio.slate)
            }
            if variable.isChoice {
                let current = model.fillValues[variable.name] ?? variable.defaultValue
                Menu {
                    ForEach(variable.options, id: \.self) { o in
                        Button { model.fillValues[variable.name] = o } label: {
                            if o == current { Label(o, systemImage: "checkmark") } else { Text(o) }
                        }
                    }
                } label: {
                    HStack {
                        Text(current).font(.system(size: 13.5)).foregroundStyle(Folio.ink)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(Folio.slate)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Folio.raised, in: shape)
                    .overlay(shape.strokeBorder(Folio.rule, lineWidth: 1))
                    .contentShape(shape)
                }
                .menuStyle(.button)
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField(variable.defaultValue.isEmpty ? "Type a value" : variable.defaultValue,
                          text: Binding(get: { model.fillValues[variable.name] ?? "" },
                                        set: { model.fillValues[variable.name] = $0 }),
                          axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Folio.ink)
                    .lineLimit(1...6)
                    .focused(focused, equals: variable.name)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Folio.raised, in: shape)
                    .overlay(shape.strokeBorder(isFocused ? Folio.rubric : Folio.rule, lineWidth: 1))
            }
        }
    }
}

/// Exactly what Copy will put on the clipboard.
struct PreviewBox: View {
    let text: String
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: min(Folio.radius, 8), style: .continuous)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Caps("What gets copied")
                Spacer()
                Caps("\(Template.estimateTokens(text).formatted()) tokens")
            }
            ScrollView {
                Text(text.isEmpty ? " " : text)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Folio.ink.opacity(0.86))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(minHeight: 90, maxHeight: .infinity)
            .background(Folio.wash, in: shape)
            .overlay(shape.strokeBorder(Folio.rule, lineWidth: 1))
        }
    }
}

/// The primary action, everywhere: fill the blanks, expand includes, copy.
struct CopyButton: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        Button { model.copyCurrent() } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.doc.fill").font(.system(size: 12))
                Text("Copy Prompt")
                Spacer()
                Text("⌘↩").font(.system(size: 12, weight: .medium).monospacedDigit()).opacity(0.7)
            }
        }
        .buttonStyle(FilledButtonStyle(height: 38, fontSize: 13.5))
        .help(model.attachments.isEmpty ? "Copy with the blanks filled in (⌘↩)"
                                        : "Copy with the blanks filled in and the file paths appended (⌘↩)")
    }
}

// MARK: Menus

/// Where you are in the library. Replaces the sidebar in Console.
struct ScopeMenu: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        Menu {
            Button("All Prompts") { model.scope = .all }
            Button("Pinned") { model.scope = .pinned }
            Button("Templates") { model.scope = .templates }
            Button("Recently Used") { model.scope = .recent }
            ForEach(model.spaces) { space in
                Section(space.name) {
                    Button("All in \(space.name)") { model.scope = .space(space.id) }
                    ForEach(model.projects.filter { $0.spaceID == space.id }) { p in
                        Button(p.name) { model.scope = .project(p.id) }
                    }
                }
            }
            Divider()
            Button("New Project…") {
                model.namingRequest = .init(kind: .newProject(spaceID: model.project(model.targetProjectID)?.spaceID ?? model.spaces.first?.id ?? 1))
            }
            Button("New Space…") { model.namingRequest = .init(kind: .newSpace) }
            Divider()
            Button("Trash") { model.scope = .trash }
        } label: {
            HStack(spacing: 6) {
                Text(model.scopeTitle).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(Folio.slate)
            }
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(GhostButtonStyle(height: 30))
        .fixedSize()
        .help("Choose a project, or make a new one")
    }
}

/// Everything you can do to a prompt besides copying it.
struct PromptActions: View {
    @Environment(AppModel.self) private var model
    let prompt: Prompt
    var body: some View {
        if model.scope == .trash {
            Button("Restore") { model.trash(prompt.id) }
            Button("Delete Forever", role: .destructive) { model.deleteForever(prompt.id) }
        } else {
            Button(prompt.pinned ? "Unpin" : "Pin") { model.togglePin(prompt.id) }
            Button("Duplicate") { model.duplicate(prompt.id) }
            Menu("Move to") {
                ForEach(model.spaces) { s in
                    Section(s.name) {
                        ForEach(model.projects.filter { $0.spaceID == s.id }) { p in
                            Button(p.name) { model.move(prompt.id, to: p.id) }
                        }
                    }
                }
            }
            Button("Shuffle Color") { model.update { $0.color = Palette.random() } }
            Divider()
            Button("Copy Template Source") { model.copyRaw(prompt.id) }
            Button(prompt.exportCommand ? "Unpublish Slash Command" : "Publish as Slash Command") { model.toggleAgentCommand(prompt.id) }
            Button("Earlier Versions…") {
                model.flushSave(); try? model.store.snapshot(prompt.id); model.historyTarget = prompt
            }
            Divider()
            Button("Move to Trash", role: .destructive) { model.trash(prompt.id) }
        }
    }
}

struct ActionsButton: View {
    let prompt: Prompt
    var body: some View {
        Menu { PromptActions(prompt: prompt) } label: {
            Image(systemName: "ellipsis").font(.system(size: 13, weight: .semibold))
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(IconButtonStyle())
        .fixedSize()
        .help("Pin, duplicate, move, publish, history, trash")
    }
}

// MARK: Small parts

/// A clickable shortcut hint for action bars.
struct KeyHint: View {
    let key: String
    let label: String
    var action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label).font(.system(size: 12)).foregroundStyle(hovering ? Folio.ink : Folio.slate)
                KeyCap(key: key)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// The place line: space / project, used for subtitles.
struct PlaceText: View {
    @Environment(AppModel.self) private var model
    let projectID: ID
    var body: some View {
        let p = model.project(projectID)
        let s = p.flatMap { model.space($0.spaceID) }
        Text([s?.name, p?.name].compactMap { $0 }.joined(separator: " / "))
            .font(.system(size: 12))
            .foregroundStyle(Folio.slate)
            .lineLimit(1)
    }
}

/// Shown when nothing is open: what to do next, in the design's voice.
struct StartHere: View {
    @Environment(AppModel.self) private var model
    var title = "Nothing open."
    var hints: [(String, String)] = [("⌘N", "New prompt"), ("⌥⌘P", "Quick Panel from any app"), ("⇧⌘H", "Harvest from agent history")]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RepriseMark(size: 30)
            Text(title)
                .font(.system(size: 19, weight: .medium, design: Folio.style.textDesign))
                .foregroundStyle(Folio.ink)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(hints, id: \.0) { k, t in
                    HStack(spacing: 10) {
                        KeyCap(key: k).frame(width: 44, alignment: .leading)
                        Text(t).font(.system(size: 12.5)).foregroundStyle(Folio.slate)
                    }
                }
            }
            NewPromptButton().padding(.top, 4)
        }
    }
}
