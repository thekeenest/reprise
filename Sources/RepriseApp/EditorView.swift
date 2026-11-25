import SwiftUI
import AppKit
import QuickLook
import RepriseCore
import UniformTypeIdentifiers

/// The page: the prompt's title, its apparatus line, and the TextKit 2 editor on a reading measure.
/// Every design embeds it; none of them puts anything else on the page.
struct PageEditor: View {
    @Environment(AppModel.self) private var model
    let prompt: Prompt
    var inset: CGFloat = 44
    var topPadding: CGFloat = 26
    @AppStorage("editorFontChoice") private var fontChoice = ""
    @AppStorage("editorSizeChoice") private var sizeChoice: Double = 0
    private var editorFont: EditorFont { EditorFont.resolve(fontChoice) }
    private var editorSize: Double { sizeChoice > 0 ? sizeChoice : Folio.style.editorSize }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(prompt: prompt, measure: measure)
                .padding(.horizontal, inset)
                .padding(.top, topPadding)
                .padding(.bottom, 14)
            MarkdownEditor(
                promptID: prompt.id,
                initialText: prompt.body,
                font: editorFont,
                fontSize: editorSize,
                inset: inset,
                measure: measure,
                onChange: { model.bodyDidChange(prompt.id, $0) },
                onPasteImage: { data, ext in model.attach(imageData: data, ext: ext) },
                onDropFiles: { model.attach(files: $0) }
            )
            .id(prompt.id)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var measure: CGFloat { CGFloat(editorSize) * (editorFont == .mono ? 50 : 44) }
}

struct EmptyPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RepriseMark(size: 34)
            Text("Select a prompt, or start a new one.")
                .font(.text(20))
                .foregroundStyle(Folio.ink)
            VStack(alignment: .leading, spacing: 7) {
                hint("⌘N", "New prompt")
                hint("⌥⌘P", "Quick Panel from any app")
                hint("⇧⌘H", "Harvest prompts from Claude Code and Codex")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(44)
        .padding(.top, 40)
    }

    private func hint(_ key: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            KeyCap(key: key).frame(width: 44, alignment: .leading)
            Text(text).font(.system(size: 12.5)).foregroundStyle(Folio.slate)
        }
    }
}

// MARK: Header

struct PageHeader: View {
    @Environment(AppModel.self) private var model
    let prompt: Prompt
    let measure: CGFloat
    @State private var title = ""
    @State private var showColors = false
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Name this prompt", text: $title, axis: .horizontal)
                .textFieldStyle(.plain)
                .font(.title)
                .tracking(Folio.style.titleTracking)
                .foregroundStyle(Folio.ink)
                .focused($titleFocused)
                .onSubmit { commitTitle() }
                .onChange(of: titleFocused) { _, f in if !f { commitTitle() } }

            DetentRule()
                .frame(maxWidth: measure)
                .padding(.top, 2)

            // The apparatus line: identity and place first, then the measurements.
            // On a narrow page the measurements drop to a second line instead of wrapping.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    place
                    Text("·").font(.apparatus(10.5)).foregroundStyle(Folio.slate)
                    StatsLine(prompt: prompt)
                }
                VStack(alignment: .leading, spacing: 4) {
                    place
                    StatsLine(prompt: prompt)
                }
            }
            .frame(maxWidth: measure, alignment: .leading)
        }
        .onAppear { title = prompt.title; if model.focusTitle { titleFocused = true; model.focusTitle = false } }
        .onChange(of: prompt.id) { title = prompt.title }
        .onChange(of: prompt.title) { _, t in if !titleFocused { title = t } }
        .onChange(of: model.focusTitle) { _, f in if f { titleFocused = true; model.focusTitle = false } }
    }

    private var place: some View {
        HStack(spacing: 8) {
            Button { showColors.toggle() } label: {
                ColorKey(hex: prompt.color, size: 8)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("This prompt's color. Click for the shade pool (⇧⌘K shuffles).")
            .popover(isPresented: $showColors, arrowEdge: .bottom) {
                ShadePicker(hex: prompt.color) { hex in model.update { $0.color = hex } }
            }
            .padding(.leading, -4)
            ProjectLine(prompt: prompt)
        }
    }

    private func commitTitle() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        // Names are required: an empty name falls back to the first line of the prompt.
        let final = t.isEmpty ? Harvest.title(for: prompt.body.isEmpty ? "Untitled prompt" : prompt.body) : t
        if final != prompt.title { model.update { $0.title = final } }
        title = final
    }
}

/// "ENGINEERING · DAILY AGENT WORK", and a menu that moves the prompt.
struct ProjectLine: View {
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
                            if p.id == prompt.projectID { Label(p.name, systemImage: "checkmark") } else { Text(p.name) }
                        }
                    }
                }
            }
        } label: {
            Caps([space?.name, project?.name].compactMap { $0 }.joined(separator: " / "), color: Folio.ink, size: 10.5)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Move to another project")
    }
}

struct StatsLine: View {
    @Environment(AppModel.self) private var model
    let prompt: Prompt

    var body: some View {
        let s = model.liveStats
        HStack(spacing: 0) {
            Caps(parts(s).joined(separator: " · "), size: 10.5)
            Text(" · ").font(.apparatus(10.5)).foregroundStyle(Folio.slate)
            Caps(s.saved ? "saved" : "editing", color: s.saved ? Folio.slate : Folio.rubric, size: 10.5)
        }
        .monospacedDigit()
        .fixedSize()
        .contentTransition(.opacity)
    }

    private func parts(_ s: AppModel.LiveStats) -> [String] {
        var out = ["\(s.tokens.formatted()) tokens"]
        if s.variables > 0 { out.append("\(s.variables) blank\(s.variables == 1 ? "" : "s")") }
        if prompt.useCount > 0 { out.append("played \(prompt.useCount)×") }
        return out
    }
}

// MARK: Toolbar

// MARK: Details

/// Everything about a prompt except its text and its blanks: includes, files, agent commands, record.
struct DetailsView: View {
    @Environment(AppModel.self) private var model
    let prompt: Prompt

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            if !model.includes.isEmpty { IncludesSection(names: model.includes) }
            FilesSection(attachments: model.attachments)
            PublishSection(prompt: prompt)
            RecordSection(prompt: prompt)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MarginHeading<Trailing: View>: View {
    var title: String
    @ViewBuilder var trailing: Trailing
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Caps(title, color: Folio.ink, size: 11)
                Spacer()
                trailing
            }
            Hairline()
        }
    }
}

extension MarginHeading where Trailing == EmptyView {
    init(title: String) { self.title = title; self.trailing = EmptyView() }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct IncludesSection: View {
    @Environment(AppModel.self) private var model
    let names: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MarginHeading(title: "Includes")
            ForEach(names, id: \.self) { n in
                Button { model.open(named: n) } label: {
                    HStack(spacing: 6) {
                        Text(n).font(.text(13.5)).foregroundStyle(Folio.ink).lineLimit(1)
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .medium)).foregroundStyle(Folio.slate)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open “\(n)”. Edits there change every prompt that includes it.")
            }
        }
    }
}

struct FilesSection: View {
    @Environment(AppModel.self) private var model
    let attachments: [Attachment]
    @State private var importing = false
    @State private var showLink = false
    @State private var link = ""
    @State private var preview: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MarginHeading(title: "Files & Links") {
                Menu {
                    Button("Add Files…") { importing = true }
                    Button("Add Link…") { showLink = true }
                } label: {
                    Image(systemName: "plus").font(.system(size: 11, weight: .medium)).foregroundStyle(Folio.slate)
                }
                .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                .help("Attach files or a link")
                .popover(isPresented: $showLink) {
                    HStack {
                        TextField("https://…", text: $link).frame(width: 260).onSubmit(addLink)
                        Button("Add", action: addLink).buttonStyle(.borderedProminent)
                    }.padding(12)
                }
            }
            if attachments.isEmpty {
                Text("Paste or drop images and files onto the page. Their paths are added when you use the prompt.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Folio.slate)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(attachments) { a in
                    AttachmentRow(attachment: a)
                        .onTapGesture {
                            if a.kind == .link, let u = URL(string: a.value) { NSWorkspace.shared.open(u) }
                            else { preview = URL(fileURLWithPath: a.value) }
                        }
                        .contextMenu {
                            Button("Copy Path or URL", systemImage: "doc.on.clipboard") { Paster.copy(a.value) }
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
        }
        .quickLookPreview($preview)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { r in
            if case .success(let urls) = r {
                let granted = urls.filter { $0.startAccessingSecurityScopedResource() || true }
                model.attach(files: granted)
            }
        }
    }

    private func addLink() { model.attach(link: link); link = ""; showLink = false }
}

struct AttachmentRow: View {
    let attachment: Attachment
    @State private var thumb: NSImage?

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if attachment.kind == .image {
                    Group {
                        if let thumb { Image(nsImage: thumb).resizable().scaledToFill() } else { Folio.wash }
                    }
                    .frame(width: 34, height: 26)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: min(Folio.radius, 4)))
                    .overlay(RoundedRectangle(cornerRadius: min(Folio.radius, 4)).strokeBorder(Folio.rule, lineWidth: Hairline.px))
                    .task(id: attachment.id) { thumb = await Thumbs.load(attachment.value, max: 80) }
                } else {
                    Image(systemName: attachment.kind == .link ? "link" : "doc")
                        .font(.system(size: 11))
                        .foregroundStyle(Folio.slate)
                        .frame(width: 34, height: 26)
                        .overlay(RoundedRectangle(cornerRadius: min(Folio.radius, 4)).strokeBorder(Folio.rule, lineWidth: Hairline.px))
                }
            }
            Text(attachment.name)
                .font(.system(size: 12))
                .foregroundStyle(Folio.ink)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .help(attachment.value)
        .onDrag {
            attachment.kind == .link
                ? NSItemProvider(object: (URL(string: attachment.value) ?? URL(fileURLWithPath: "/")) as NSURL)
                : (NSItemProvider(contentsOf: URL(fileURLWithPath: attachment.value)) ?? NSItemProvider())
        }
    }
}

struct PublishSection: View {
    @Environment(AppModel.self) private var model
    let prompt: Prompt

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MarginHeading(title: "Agents")
            Toggle(isOn: Binding(get: { prompt.exportCommand }, set: { _ in model.toggleAgentCommand(prompt.id) })) {
                Text("Publish as a slash command").font(.system(size: 12))
            }
            .toggleStyle(.checkbox)
            .help("Writes ~/.claude/commands/\(prompt.slug).md and ~/.codex/prompts/\(prompt.slug).md (⇧⌘T)")
            ViewThatFits(in: .horizontal) {
                VStack(alignment: .leading, spacing: 3) {
                    row("Claude Code", "/\(prompt.slug)", stacked: false)
                    row("Codex", "/prompts:\(prompt.slug)", stacked: false)
                }
                VStack(alignment: .leading, spacing: 6) {
                    row("Claude Code", "/\(prompt.slug)", stacked: true)
                    row("Codex", "/prompts:\(prompt.slug)", stacked: true)
                }
            }
            .opacity(prompt.exportCommand ? 1 : 0.55)
        }
    }

    @ViewBuilder
    private func row(_ agent: String, _ command: String, stacked: Bool) -> some View {
        let cmd = Text(command)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Folio.ink)
            .lineLimit(1)
            .truncationMode(.middle)
            .textSelection(.enabled)
        if stacked {
            VStack(alignment: .leading, spacing: 1) { Caps(agent, size: 10); cmd }
        } else {
            HStack { Caps(agent, size: 10).fixedSize(); Spacer(minLength: 8); cmd.fixedSize() }
        }
    }
}

struct RecordSection: View {
    @Environment(AppModel.self) private var model
    let prompt: Prompt

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MarginHeading(title: "Record")
            line("Written", prompt.createdAt.formatted(date: .abbreviated, time: .omitted))
            line("Edited", prompt.updatedAt.formatted(date: .abbreviated, time: .shortened))
            line("Played", prompt.useCount == 0 ? "never" : "\(prompt.useCount)×" + (prompt.lastUsedAt.map { ", last \($0.relative) ago" } ?? ""))
            Button {
                model.flushSave(); try? model.store.snapshot(prompt.id); model.historyTarget = prompt
            } label: {
                Text("Earlier versions…").underline(color: Folio.rule).foregroundStyle(Folio.ink)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .padding(.top, 2)
        }
    }

    private func line(_ k: String, _ v: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Caps(k, size: 10)
            Spacer()
            Text(v).font(.system(size: 11.5).monospacedDigit()).foregroundStyle(Folio.ink)
        }
    }
}

/// Downsampled thumbnails via ImageIO. It never decodes a full 40 MP screenshot just to show 34 px.
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
