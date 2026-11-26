import SwiftUI
import AppKit
import RepriseCore

/// A Spotlight-style floating glass panel. It never activates Reprise, so focus returns to
/// your terminal instantly and the prompt can be pasted straight into Claude Code / Codex.
@MainActor
final class QuickPanelController {
    static let shared = QuickPanelController()
    private var panel: QuickPanel?
    private var hotKey: HotKey?
    private var builtFor: String?

    func registerHotKey() {
        hotKey?.invalidate()
        let label = UserDefaults.standard.string(forKey: "hotkey") ?? HotKey.Combo.optCmdP.label
        hotKey = HotKey(HotKey.Combo.named(label)) { [weak self] in self?.toggle() }
    }

    func toggle() {
        if let p = panel, p.isVisible { hide() } else { show() }
    }

    @MainActor
    func show() {
        if panel != nil, builtFor != Variant.signature { panel?.orderOut(nil); panel = nil }
        if panel == nil {
            builtFor = Variant.signature
            let p = QuickPanel(contentRect: NSRect(x: 0, y: 0, width: 760, height: 470))
            let host = NSHostingView(rootView: QuickPanelView(close: { [weak self] in self?.hide() }).environment(AppModel.shared))
            host.sizingOptions = []
            p.contentView = host
            panel = p
        }
        guard let panel else { return }
        AppModel.shared.flushSave()
        NotificationCenter.default.post(name: .quickPanelWillShow, object: nil)
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let f = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: f.midX - panel.frame.width / 2, y: f.minY + f.height * 0.62 - panel.frame.height / 2))
        }
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.14
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: { panel.orderOut(nil) })
    }
}

extension Notification.Name {
    static let quickPanelWillShow = Notification.Name("reprise.quickPanelWillShow")
}

final class QuickPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        QuickPanelController.shared.hide()
    }

    override func cancelOperation(_ sender: Any?) { QuickPanelController.shared.hide() }
}

struct QuickPanelView: View {
    @Environment(AppModel.self) private var model
    @LookSetting private var look
    var close: () -> Void

    @State private var query = ""
    @State private var results: [PromptSummary] = []
    @State private var index = 0
    @State private var filling: Prompt?
    @State private var values: [String: String] = [:]
    @FocusState private var focus: Field?

    enum Field: Hashable { case search, variable(String) }

    var selected: PromptSummary? { results.indices.contains(index) ? results[index] : nil }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Hairline()
            HStack(spacing: 0) {
                if let filling { fillForm(filling) } else { resultList }
                Hairline(vertical: true)
                previewPane
            }
            Hairline()
            footer
        }
        .frame(width: 760, height: 470)
        .foregroundStyle(Folio.ink)
        .background { if Variant.glass { WindowGround() } else { Folio.paper } }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Variant.glass ? Color.white.opacity(0.16) : Folio.rule, lineWidth: 1))
        .tint(Folio.rubric)
        .preferredColorScheme(look.scheme)
        .onAppear(perform: reset)
        .onReceive(NotificationCenter.default.publisher(for: .quickPanelWillShow)) { _ in reset() }
        .onChange(of: query) { search() }
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onKeyPress(.escape) {
            if filling != nil { filling = nil; focus = .search } else { close() }
            return .handled
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            RepriseMark(size: 20)
            if let filling {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(filling.title).font(.text(20)).lineLimit(1)
                    Caps("fill the blanks, ↩ to use")
                }
                Spacer()
            } else {
                TextField("Find a prompt", text: $query)
                    .textFieldStyle(.plain)
                    .font(.text(21))
                    .focused($focus, equals: .search)
                    .onSubmit { activate(paste: Prefs.autoPaste) }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 62)
    }

    private var resultList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { i, r in
                        QuickRow(item: r, selected: i == index, project: model.project(r.projectID)?.name ?? "")
                            .id(r.id)
                            .onTapGesture { index = i; activate(paste: Prefs.autoPaste) }
                    }
                }
                .padding(.vertical, 6)
            }
            .onChange(of: index) { _, i in
                if results.indices.contains(i) { proxy.scrollTo(results[i].id, anchor: nil) }
            }
        }
        .frame(width: 330)
        .overlay { if results.isEmpty { Text(query.isEmpty ? "Your library is empty." : "Nothing matches.").font(.text(14)).foregroundStyle(Folio.slate) } }
    }

    private func fillForm(_ p: Prompt) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(model.store.variables(p).enumerated()), id: \.element.id) { i, v in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(v.name).font(.system(size: 11.5, weight: .medium)).foregroundStyle(Folio.slate)
                        if v.isChoice {
                            Picker("", selection: Binding(get: { values[v.name] ?? v.defaultValue }, set: { values[v.name] = $0 })) {
                                ForEach(v.options, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        } else {
                            TextField(v.defaultValue.isEmpty ? v.name : v.defaultValue,
                                      text: Binding(get: { values[v.name] ?? "" }, set: { values[v.name] = $0 }))
                                .textFieldStyle(.roundedBorder)
                                .focused($focus, equals: .variable(v.name))
                                .onSubmit { advance(from: v.name, in: p) }
                        }
                    }
                    }
                }
            }
            .padding(18)
        }
        .frame(width: 330)
    }

    private var previewPane: some View {
        ScrollView {
            Text(Self.marked(previewText))
                .font(.text(12.5))
                .lineSpacing(3)
                .foregroundStyle(Folio.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            let pastes = Prefs.autoPaste && Paster.canAutoPaste
            hint("↩", filling == nil ? (pastes ? "Paste" : "Copy") : "Next blank")
            if pastes { hint("⌘↩", "Copy without pasting") }
            hint("⌘O", "Open in Reprise")
            hint("esc", filling == nil ? "Close" : "Back")
            Spacer()
            if let s = selected { Caps("\(Template.estimateTokens(length: s.length).formatted()) tokens").monospacedDigit() }
        }
        .font(.system(size: 11.5))
        .padding(.horizontal, 18)
        .frame(height: 36)
        .background {
            Group {
                Button("") { activate(paste: false) }.keyboardShortcut(.return, modifiers: .command)
                Button("") { openInApp() }.keyboardShortcut("o", modifiers: .command)
            }
            .opacity(0)
        }
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 6) {
            KeyCap(key: key)
            Text(label).foregroundStyle(Folio.slate)
        }
    }

    /// Blanks in rubric, as on the page.
    static func marked(_ text: String) -> AttributedString {
        var out = AttributedString(text)
        guard text.contains("{{") else { return out }
        for r in Template.placeholderRanges(in: text) {
            guard let sr = Range(r, in: text),
                  let lo = AttributedString.Index(sr.lowerBound, within: out),
                  let hi = AttributedString.Index(sr.upperBound, within: out) else { continue }
            let inner = text[sr]
            let blank = !(inner.hasPrefix("{{>") || inner.contains("{{@"))
            out[lo..<hi].foregroundColor = blank ? Folio.rubric : Folio.slate
            out[lo..<hi].font = .system(size: 11, weight: .semibold, design: .monospaced)
        }
        return out
    }

    private var previewText: String {
        if let filling {
            return model.store.payload(filling, values: values, includeAttachments: Prefs.includeAttachmentPaths, clipboard: Paster.clipboardString)
        }
        guard let s = selected, let p = try? model.store.prompt(s.id) else { return "" }
        return String(p.body.prefix(6000))
    }

    // MARK: Actions

    private func reset() {
        query = ""
        filling = nil
        values = [:]
        index = 0
        search()
        DispatchQueue.main.async { focus = .search }
    }

    private func search() {
        if query.isEmpty {
            // Empty query: pinned first, then most used, then recent.
            let pinned = (try? model.store.summaries(scope: .pinned, sort: .used, limit: 12)) ?? []
            let used = (try? model.store.summaries(scope: .all, sort: .used, limit: 40)) ?? []
            var seen = Set<ID>()
            results = (pinned + used).filter { seen.insert($0.id).inserted }
        } else {
            results = (try? model.store.summaries(scope: .all, query: query, limit: 60)) ?? []
        }
        index = 0
    }

    private func move(_ d: Int) {
        guard filling == nil, !results.isEmpty else { return }
        index = (index + d + results.count) % results.count
    }

    private func activate(paste: Bool) {
        if let filling {
            finish(filling, paste: paste)
            return
        }
        guard let s = selected, let p = try? model.store.prompt(s.id) else { return }
        let vars = model.store.variables(p)
        if vars.isEmpty {
            finish(p, paste: paste)
        } else {
            values = Prefs.lastValues(for: p.id)
            filling = p
            DispatchQueue.main.async { focus = .variable(vars.first(where: { !$0.isChoice })?.name ?? "") }
        }
    }

    private func advance(from name: String, in p: Prompt) {
        let fields = model.store.variables(p).filter { !$0.isChoice }.map(\.name)
        if let i = fields.firstIndex(of: name), i + 1 < fields.count { focus = .variable(fields[i + 1]) }
        else { finish(p, paste: Prefs.autoPaste) }
    }

    private func finish(_ p: Prompt, paste: Bool) {
        let text = model.store.payload(p, values: values, includeAttachments: Prefs.includeAttachmentPaths, clipboard: Paster.clipboardString)
        Paster.copy(text)
        try? model.store.markUsed(p.id)
        Prefs.rememberValues(values, for: p.id)
        close()
        if paste && Paster.canAutoPaste { Paster.pasteIntoFrontmost(after: 0.16) }
        model.reloadList()
    }

    private func openInApp() {
        guard let s = selected else { return }
        close()
        NSApp.activate(ignoringOtherApps: true)
        model.scope = .all
        model.query = ""
        model.selectedID = s.id
        NSApp.windows.first { $0.identifier?.rawValue.contains("main") == true || $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
    }
}

struct QuickRow: View {
    let item: PromptSummary
    let selected: Bool
    let project: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            ColorKey(hex: item.color, size: 6)
                .frame(width: 20, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.title).font(.text(14.5, weight: selected ? .medium : .regular)).lineLimit(1)
                        .foregroundStyle(Folio.ink)
                    if item.pinned { Image(systemName: "pin.fill").font(.system(size: 8.5)).foregroundStyle(Folio.slate) }
                    Spacer(minLength: 6)
                    if item.isTemplate { Caps("template", size: 10) }
                }
                Caps(project + (item.useCount > 0 ? " · played \(item.useCount)×" : ""), size: 10).lineLimit(1)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 14)
        .padding(.vertical, 8)
        .background { SelectionBackground(selected: selected, active: true, hovering: false) }
        .contentShape(Rectangle())
    }
}
