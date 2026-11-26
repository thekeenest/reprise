import SwiftUI
import AppKit
import RepriseCore

// Shared components. Rules: buttons hug their content, every corner is rounded,
// and there is exactly one way to get a prompt out, called Copy.

// MARK: Buttons

/// Solid: an 8 pt rounded rectangle. Glass: a capsule, as glass controls are.
struct ControlShape: Shape {
    func path(in rect: CGRect) -> Path {
        Variant.glass
            ? Capsule(style: .continuous).path(in: rect)
            : RoundedRectangle(cornerRadius: min(8, rect.height / 2), style: .continuous).path(in: rect)
    }
}

/// The filled accent button (New Prompt, Copy Prompt). On hover it lifts: the fill brightens,
/// a glow in the accent appears beneath, a sheen sweeps across once, and it grows 3%.
struct FilledButtonStyle: ButtonStyle {
    var height: CGFloat = 30
    var fontSize: CGFloat = 12.5
    func makeBody(configuration: Configuration) -> some View {
        FilledBody(label: configuration.label, pressed: configuration.isPressed, height: height, fontSize: fontSize)
    }

    private struct FilledBody<L: View>: View {
        let label: L
        let pressed: Bool
        let height: CGFloat
        let fontSize: CGFloat
        @State private var hovering = false
        @State private var sweep = false

        var body: some View {
            let shape = ControlShape()
            label
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(Folio.onFill)
                .padding(.horizontal, Variant.glass ? 15 : 13)
                .frame(height: height)
                .fixedSize()
                .background {
                    ZStack {
                        shape.fill(Folio.fill)
                        shape.fill(LinearGradient(colors: [.white.opacity(hovering ? 0.22 : 0.1), .white.opacity(0)],
                                                  startPoint: .top, endPoint: .bottom))
                        GeometryReader { g in
                            LinearGradient(colors: [.clear, .white.opacity(0.32), .clear], startPoint: .leading, endPoint: .trailing)
                                .frame(width: g.size.width * 0.45)
                                .rotationEffect(.degrees(18))
                                .offset(x: sweep ? g.size.width * 1.2 : -g.size.width * 0.6)
                        }
                        .clipShape(shape)
                        .allowsHitTesting(false)
                    }
                }
                .overlay(shape.stroke(.white.opacity(hovering ? 0.28 : 0.12), lineWidth: 1))
                .shadow(color: Folio.fill.opacity(hovering ? 0.5 : 0), radius: hovering ? 12 : 0, y: hovering ? 4 : 0)
                .scaleEffect(pressed ? 0.96 : hovering ? 1.03 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.68), value: hovering)
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: pressed)
                .contentShape(shape)
                .onHover { h in
                    hovering = h
                    if h {
                        sweep = false
                        withAnimation(.easeOut(duration: 0.65)) { sweep = true }
                    }
                }
                .environment(\.buttonHovering, hovering)
        }
    }
}

private struct ButtonHoveringKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    /// True while the enclosing styled button is hovered, so labels can animate (the + turns).
    var buttonHovering: Bool {
        get { self[ButtonHoveringKey.self] }
        set { self[ButtonHoveringKey.self] = newValue }
    }
}

/// Secondary actions: no border at rest in glass, a hairline in solid; on hover the fill
/// rises and the edge takes the accent.
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
            let shape = ControlShape()
            label
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Folio.ink)
                .padding(.horizontal, 11)
                .frame(minWidth: height, minHeight: height)
                .fixedSize()
                .background(shape.fill(Folio.ink.opacity(hovering || pressed ? 0.09 : (Variant.glass ? 0.06 : 0))))
                .overlay(shape.stroke(hovering ? Folio.rubric.opacity(0.7) : Folio.rule, lineWidth: 1))
                .scaleEffect(pressed ? 0.97 : 1)
                .animation(.easeOut(duration: 0.16), value: hovering)
                .contentShape(shape)
                .onHover { hovering = $0 }
                .environment(\.buttonHovering, hovering)
        }
    }
}

/// A glyph-only button: slate at rest, ink in a soft circle on hover.
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
                .background(Circle().fill(Folio.ink.opacity(hovering || pressed ? 0.1 : 0)).scaleEffect(hovering ? 1 : 0.6))
                .scaleEffect(pressed ? 0.92 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hovering)
                .contentShape(Circle())
                .onHover { hovering = $0 }
        }
    }
}

/// "+ New Prompt", top right of the window. The plus turns a quarter on hover.
struct NewPromptButton: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        Button { model.newPrompt() } label: { NewPromptLabel() }
            .buttonStyle(FilledButtonStyle())
            .help("New prompt (⌘N)")
    }
}

private struct NewPromptLabel: View {
    @Environment(\.buttonHovering) private var hovering
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 11.5, weight: .bold))
                .rotationEffect(.degrees(hovering ? 90 : 0))
                .scaleEffect(hovering ? 1.18 : 1)
            Text("New Prompt")
        }
    }
}

/// The primary action: blanks filled, includes expanded, file paths appended. Hugs its label.
struct CopyButton: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        Button { model.copyCurrent() } label: { CopyLabel() }
            .buttonStyle(FilledButtonStyle(height: 32, fontSize: 12.5))
            .help(model.attachments.isEmpty ? "Copy with the blanks filled in (⌘↩)"
                                            : "Copy with the blanks filled in and the file paths appended (⌘↩)")
    }
}

private struct CopyLabel: View {
    @Environment(\.buttonHovering) private var hovering
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "doc.on.doc.fill").font(.system(size: 11))
                .offset(y: hovering ? -1 : 0)
            Text("Copy Prompt")
            Text("⌘↩").font(.system(size: 11, weight: .medium).monospacedDigit()).opacity(0.72)
        }
    }
}

// MARK: Inspector

/// Beside the page: the blanks and Copy first, everything else folded away until asked for.
struct InspectorView: View {
    @Environment(AppModel.self) private var model
    let prompt: Prompt
    @FocusState private var focused: String?
    @AppStorage("fold.includes") private var openIncludes = false
    @AppStorage("fold.files") private var openFiles = false
    @AppStorage("fold.agents") private var openAgents = false
    @AppStorage("fold.record") private var openRecord = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Caps("Blanks", color: Folio.ink, size: 11)
                    Spacer()
                    if !model.blanks.isEmpty { Caps("\(model.blanks.count)") }
                }
                .padding(.bottom, 12)

                if model.blanks.isEmpty {
                    Text("No blanks. Copy takes the prompt as written.")
                        .font(.system(size: 12))
                        .foregroundStyle(Folio.slate)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(model.blanks) { v in BlankField(variable: v, focused: $focused) }
                    }
                }
                CopyButton().padding(.top, 16)

                VStack(alignment: .leading, spacing: 0) {
                    Fold(title: "Includes", detail: model.includes.isEmpty ? "none" : "\(model.includes.count)", open: $openIncludes) {
                        IncludesSection(names: model.includes)
                    }
                    Fold(title: "Files & links", detail: model.attachments.isEmpty ? "none" : "\(model.attachments.count)", open: $openFiles) {
                        FilesSection(attachments: model.attachments)
                    }
                    Fold(title: "Agents", detail: prompt.exportCommand ? "/\(prompt.slug)" : "off", open: $openAgents) {
                        PublishSection(prompt: prompt)
                    }
                    Fold(title: "Record", detail: prompt.useCount > 0 ? "played \(prompt.useCount)×" : "never played", open: $openRecord) {
                        RecordSection(prompt: prompt)
                    }
                }
                .padding(.top, 26)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.never)
    }
}

/// A folded section: one quiet line until opened.
struct Fold<Content: View>: View {
    let title: String
    let detail: String
    @Binding var open: Bool
    @ViewBuilder var content: Content
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Hairline()
            Button { withAnimation(.easeOut(duration: 0.18)) { open.toggle() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Folio.slate)
                        .rotationEffect(.degrees(open ? 90 : 0))
                        .frame(width: 10)
                    Caps(title, color: hovering ? Folio.ink : Folio.ink.opacity(0.85), size: 11)
                    Spacer(minLength: 8)
                    Text(detail)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(Folio.slate)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(height: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            if open {
                content
                    .padding(.leading, 18)
                    .padding(.bottom, 14)
                    .transition(.opacity)
            }
        }
    }
}

struct BlankField: View {
    @Environment(AppModel.self) private var model
    let variable: Template.Variable
    var focused: FocusState<String?>.Binding

    var body: some View {
        let isFocused = focused.wrappedValue == variable.name
        let shape = RoundedRectangle(cornerRadius: Variant.glass ? 10 : 7, style: .continuous)
        VStack(alignment: .leading, spacing: 5) {
            Text(variable.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isFocused ? Folio.ink : Folio.slate)
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
                        Text(current).font(.system(size: 13)).foregroundStyle(Folio.ink)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(Folio.slate)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(FieldFill(), in: shape)
                    .overlay(shape.strokeBorder(Folio.rule, lineWidth: 1))
                    .contentShape(shape)
                }
                .menuStyle(.button)
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
            } else {
                TextField(variable.defaultValue.isEmpty ? "Type a value" : variable.defaultValue,
                          text: Binding(get: { model.fillValues[variable.name] ?? "" },
                                        set: { model.fillValues[variable.name] = $0 }),
                          axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Folio.ink)
                    .lineLimit(1...6)
                    .focused(focused, equals: variable.name)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(FieldFill(), in: shape)
                    .overlay(shape.strokeBorder(isFocused ? Folio.rubric : Folio.rule, lineWidth: 1))
                    .animation(.easeOut(duration: 0.15), value: isFocused)
            }
        }
    }
}

/// Field backgrounds: raised paper in solid, a darker well in glass.
struct FieldFill: ShapeStyle {
    func resolve(in env: EnvironmentValues) -> Color.Resolved {
        if Variant.glass {
            return (env.colorScheme == .dark ? Color.black.opacity(0.22) : Color.white.opacity(0.55)).resolve(in: env)
        }
        return Folio.raised.resolve(in: env)
    }
}

// MARK: Menus

/// Everything you can do to a prompt besides copying it.
struct PromptActions: View {
    @Environment(AppModel.self) private var model
    let prompt: Prompt
    var body: some View {
        if prompt.trashed {
            Button("Restore") { model.trash(prompt.id) }
            Button("Delete Forever", role: .destructive) { model.deleteForever(prompt.id) }
        } else {
            Button(prompt.pinned ? "Unpin" : "Pin") { model.togglePin(prompt.id) }
            Button("Duplicate") { model.duplicate(prompt.id) }
            MoveMenu(promptID: prompt.id, current: prompt.projectID)
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

/// Spaces as sections, their projects as items, and the way to make new ones.
struct MoveMenu: View {
    @Environment(AppModel.self) private var model
    let promptID: ID
    let current: ID
    var body: some View {
        Menu("Move to") { ProjectChoices(current: current) { model.move(promptID, to: $0) } }
    }
}

struct ProjectChoices: View {
    @Environment(AppModel.self) private var model
    let current: ID
    let pick: (ID) -> Void
    var body: some View {
        ForEach(model.spaces) { s in
            Section(s.name) {
                ForEach(model.projects.filter { $0.spaceID == s.id }) { p in
                    Button { pick(p.id) } label: {
                        if p.id == current { Label(p.name, systemImage: "checkmark") } else { Text(p.name) }
                    }
                }
            }
        }
        Divider()
        Button("New Project…") {
            model.namingRequest = .init(kind: .newProject(spaceID: model.project(current)?.spaceID ?? model.spaces.first?.id ?? 1))
        }
        Button("New Space…") { model.namingRequest = .init(kind: .newSpace) }
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

/// Shown when nothing is open.
struct StartHere: View {
    var title = "Select a prompt, or write a new one."
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RepriseMark(size: 30)
            Text(title)
                .font(.text(20))
                .foregroundStyle(Folio.ink)
            VStack(alignment: .leading, spacing: 8) {
                ForEach([("⌘N", "New prompt"), ("⌥⌘P", "Quick Panel from any app"), ("⇧⌘H", "Harvest from agent history")], id: \.0) { k, t in
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
