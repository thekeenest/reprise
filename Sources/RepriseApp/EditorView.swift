import SwiftUI
import AppKit
import QuickLook
import RepriseCore
import UniformTypeIdentifiers

struct EditorView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("look") private var look: Look = .liquid
    @AppStorage("editorFont") private var editorFont: EditorFont = .mono
    @AppStorage("editorSize") private var editorSize: Double = 14

    var body: some View {
        if let p = model.current {
            VStack(spacing: 0) {
                EditorHeader(prompt: p)
                    .padding(.horizontal, 28)
                    .padding(.top, 18)
                    .padding(.bottom, 6)

                if !model.attachments.isEmpty {
                    AttachmentStrip(attachments: model.attachments, accent: Color(hex: p.color))
                        .padding(.horizontal, 22)
                        .padding(.bottom, 6)
                }

                MarkdownEditor(
                    promptID: p.id,
                    initialText: p.body,
                    font: editorFont,
                    fontSize: editorSize,
                    accent: NSColor(hex: p.color),
                    look: look,
                    onChange: { model.bodyDidChange(p.id, $0) },
                    onPasteImage: { data, ext in model.attach(imageData: data, ext: ext) },
                    onDropFiles: { model.attach(files: $0) }
                )
                .id(p.id)
            }
            .overlay(alignment: .bottom) {
                ActionBar(prompt: p)
                    .padding(.bottom, 16)
            }
            .background { Aura(color: Color(hex: p.color), look: look).ignoresSafeArea() }
            .animation(.smooth(duration: 0.5), value: p.color)
        } else {
            ZStack {
                Aura(color: Color(hex: model.accentHex), look: look).ignoresSafeArea()
                VStack(spacing: 12) {
                    RepriseMark(size: 64)
                    Text("Select a prompt, or press ⌘N").font(.title3).foregroundStyle(.secondary)
                    Text("⌥⌘P summons Reprise from anywhere").font(.callout).foregroundStyle(.tertiary)
                }
            }
        }
    }
}

struct EditorHeader: View {
    @Environment(AppModel.self) private var model
    let prompt: Prompt
    @State private var title = ""
    @State private var tags = ""
    @State private var showColors = false
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Button { showColors.toggle() } label: {
                    ColorDot(hex: prompt.color, size: 18)
                }
                .buttonStyle(.plain)
                .help("Color — click for the shade pool")
                .popover(isPresented: $showColors, arrowEdge: .bottom) {
                    ShadePicker(hex: prompt.color) { hex in model.update { $0.color = hex } }
                }

                TextField("Name this prompt", text: $title, axis: .horizontal)
                    .textFieldStyle(.plain)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .focused($titleFocused)
                    .onSubmit { commitTitle() }
                    .onChange(of: titleFocused) { _, f in if !f { commitTitle() } }
            }

            HStack(spacing: 10) {
                ProjectChip(prompt: prompt)
                if prompt.isTemplate {
                    VariableChips(prompt: prompt)
                }
                if prompt.exportCommand {
                    Badge(text: "/\(prompt.slug)", icon: "terminal.fill", color: .teal)
                        .help("Published as a slash command in Claude Code (/\(prompt.slug)) and Codex (/prompts:\(prompt.slug))")
                }
                Spacer()
                StatsLine()
            }
        }
        .onAppear { title = prompt.title; tags = prompt.tags; if model.focusTitle { titleFocused = true; model.focusTitle = false } }
        .onChange(of: prompt.id) { title = prompt.title; tags = prompt.tags }
        .onChange(of: prompt.title) { _, t in if !titleFocused { title = t } }
        .onChange(of: model.focusTitle) { _, f in if f { titleFocused = true; model.focusTitle = false } }
    }

    private func commitTitle() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        // Names are required: an empty name falls back to the first line of the prompt.
        let final = t.isEmpty ? Harvest.title(for: prompt.body.isEmpty ? "Untitled prompt" : prompt.body) : t
        if final != prompt.title { model.update { $0.title = final } }
        title = final
    }
}

struct ProjectChip: View {
    @Environment(AppModel.self) private var model
    let prompt: Prompt

    var body: some View {
        let project = model.project(prompt.projectID)
        let space = project.flatMap { model.space($0.spaceID) }
        Menu {
            ForEach(model.spaces) { s in
                Section(s.name) {
                    ForEach(model.projects.filter { $0.spaceID == s.id }) { p in
                        Button { model.move(prompt.id, to: p.id) } label: {
                            Label(p.name, systemImage: p.id == prompt.projectID ? "checkmark" : "circle.fill")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                if let space { Text(space.name).foregroundStyle(.secondary) ; Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary) }
                ColorDot(hex: project?.color ?? "#888888", size: 7)
                Text(project?.name ?? "—").fontWeight(.medium)
            }
            .font(.callout)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

struct VariableChips: View {
    @Environment(AppModel.self) private var model
    let prompt: Prompt
    var body: some View {
        let vars = model.store.variables(prompt)
        HStack(spacing: 4) {
            ForEach(vars.prefix(5)) { v in
                Text(v.name)
                    .font(.caption.monospaced().weight(.medium))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .foregroundStyle(Color(hex: prompt.color))
                    .background(Color(hex: prompt.color).opacity(0.14), in: Capsule())
            }
            if vars.count > 5 { Text("+\(vars.count - 5)").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct StatsLine: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let s = model.liveStats
        HStack(spacing: 10) {
            Text("\(s.words.formatted()) words")
            Text("~\(s.tokens.formatted()) tokens")
            Image(systemName: s.saved ? "checkmark.icloud" : "circle.dotted")
                .foregroundStyle(s.saved ? Color.secondary : Color.orange)
                .contentTransition(.symbolEffect(.replace))
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }
}

/// Floating Liquid Glass action bar — the buttons morph together inside a GlassEffectContainer.
struct ActionBar: View {
    @Environment(AppModel.self) private var model
    @AppStorage("look") private var look: Look = .liquid
    let prompt: Prompt
    @State private var showLink = false
    @State private var link = ""
    @State private var importing = false

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 8) {
                Button { model.use(prompt.id) } label: {
                    Label(prompt.isTemplate ? "Fill & Copy" : "Copy", systemImage: prompt.isTemplate ? "wand.and.sparkles" : "doc.on.doc.fill")
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(Color(hex: prompt.color))
                .keyboardShortcut(.return, modifiers: .command)
                .help("⌘↩")

                HStack(spacing: 2) {
                    iconButton("pin\(prompt.pinned ? ".fill" : "")", prompt.pinned ? "Unpin" : "Pin") { model.togglePin(prompt.id) }
                    iconButton("paperclip", "Attach files or images") { importing = true }
                    iconButton("link", "Attach a link") { showLink = true }
                        .popover(isPresented: $showLink) {
                            HStack {
                                TextField("https://…", text: $link).frame(width: 280).onSubmit(addLink)
                                Button("Add", action: addLink).buttonStyle(.glassProminent)
                            }.padding(12)
                        }
                    iconButton("clock.arrow.circlepath", "Version history") { model.flushSave(); try? model.store.snapshot(prompt.id); model.historyTarget = prompt }
                    iconButton(prompt.exportCommand ? "terminal.fill" : "terminal", "Publish as /\(prompt.slug) in Claude Code & Codex") { model.toggleAgentCommand(prompt.id) }
                    Menu {
                        Button("Copy Source", systemImage: "doc.on.doc") { model.copyRaw(prompt.id) }
                        Button("Duplicate", systemImage: "plus.square.on.square") { model.duplicate(prompt.id) }
                        Button("Shuffle Color", systemImage: "dice") { model.update { $0.color = Palette.random() } }
                        Divider()
                        Button("Move to Trash", systemImage: "trash", role: .destructive) { model.trash(prompt.id) }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 30, height: 26)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
        }
        .controlSize(.large)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { r in
            if case .success(let urls) = r {
                let granted = urls.filter { $0.startAccessingSecurityScopedResource() || true }
                model.attach(files: granted)
            }
        }
    }

    private func addLink() { model.attach(link: link); link = ""; showLink = false }

    private func iconButton(_ icon: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 30, height: 26)
                .contentShape(Rectangle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct AttachmentStrip: View {
    @Environment(AppModel.self) private var model
    let attachments: [Attachment]
    let accent: Color
    @State private var preview: URL?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { a in
                    AttachmentTile(attachment: a, accent: accent)
                        .onTapGesture {
                            if a.kind == .link, let u = URL(string: a.value) { NSWorkspace.shared.open(u) }
                            else { preview = URL(fileURLWithPath: a.value) }
                        }
                        .contextMenu {
                            Button("Copy Path / URL", systemImage: "doc.on.clipboard") { Paster.copy(a.value) }
                            if a.kind == .image, let img = NSImage(contentsOfFile: a.value) {
                                Button("Copy Image", systemImage: "photo") {
                                    NSPasteboard.general.clearContents(); NSPasteboard.general.writeObjects([img])
                                }
                            }
                            if a.kind != .link {
                                Button("Reveal in Finder", systemImage: "folder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: a.value)]) }
                            }
                            Divider()
                            Button("Remove", systemImage: "trash", role: .destructive) { model.remove(a) }
                        }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .quickLookPreview($preview)
    }
}

struct AttachmentTile: View {
    let attachment: Attachment
    let accent: Color
    @State private var thumb: NSImage?

    var body: some View {
        Group {
            switch attachment.kind {
            case .image:
                Group {
                    if let thumb { Image(nsImage: thumb).resizable().scaledToFill() }
                    else { Color.secondary.opacity(0.15) }
                }
                .frame(width: 64, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                .task(id: attachment.id) { thumb = await Thumbs.load(attachment.value, max: 160) }
                .onDrag { NSItemProvider(contentsOf: URL(fileURLWithPath: attachment.value)) ?? NSItemProvider() }
            case .link, .file:
                Label(attachment.name, systemImage: attachment.kind == .link ? "link" : "doc.fill")
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .frame(maxWidth: 180)
                    .padding(.horizontal, 10)
                    .frame(height: 46)
                    .glassEffect(.regular.tint(accent.opacity(0.15)), in: .rect(cornerRadius: 10))
                    .onDrag {
                        attachment.kind == .link
                            ? NSItemProvider(object: (URL(string: attachment.value) ?? URL(fileURLWithPath: "/")) as NSURL)
                            : (NSItemProvider(contentsOf: URL(fileURLWithPath: attachment.value)) ?? NSItemProvider())
                    }
            }
        }
        .help(attachment.value)
    }
}

/// Downsampled thumbnails via ImageIO — never decodes a full 40 MP screenshot just to show 64 px.
enum Thumbs {
    static let cache = NSCache<NSString, NSImage>()

    static func load(_ path: String, max: Int) async -> NSImage? {
        if let c = cache.object(forKey: path as NSString) { return c }
        let img: NSImage? = await Task.detached(priority: .utility) {
            guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
            let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                         kCGImageSourceThumbnailMaxPixelSize: max * 2,
                                         kCGImageSourceCreateThumbnailWithTransform: true]
            guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
            return NSImage(cgImage: cg, size: .zero)
        }.value
        if let img { cache.setObject(img, forKey: path as NSString) }
        return img
    }
}
