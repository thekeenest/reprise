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
        if panel == nil {
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
    @AppStorage("look") private var look: Look = .liquid
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
            Divider().opacity(0.5)
            HStack(spacing: 0) {
                if let filling { fillForm(filling) } else { resultList }
                Divider().opacity(0.5)
                previewPane
            }
            footer
        }
        .frame(width: 760, height: 470)
        .background { if look == .ink { Color(white: 0.06).opacity(0.96) } }
        .surface(look, tint: Color(hex: selected?.color ?? "#7A5CFA"), radius: 26)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
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
            RepriseMark(size: 22)
            if let filling {
                HStack(spacing: 6) {
                    ColorDot(hex: filling.color, size: 9)
                    Text(filling.title).font(.title3.weight(.semibold)).lineLimit(1)
                    Text("— fill the blanks, ↩ to use").foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                TextField("Search prompts…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 22, weight: .regular))
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
                LazyVStack(spacing: 2) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { i, r in
                        QuickRow(item: r, selected: i == index, project: model.project(r.projectID)?.name ?? "")
                            .id(r.id)
                            .onTapGesture { index = i; activate(paste: Prefs.autoPaste) }
                    }
                }
                .padding(8)
            }
            .onChange(of: index) { _, i in
                if results.indices.contains(i) { proxy.scrollTo(results[i].id, anchor: nil) }
            }
        }
        .frame(width: 330)
        .overlay { if results.isEmpty { Text(query.isEmpty ? "Your library is empty" : "No matches").foregroundStyle(.secondary) } }
    }

    private func fillForm(_ p: Prompt) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(model.store.variables(p)) { v in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(v.name).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
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
            .padding(16)
        }
        .frame(width: 330)
    }

    private var previewPane: some View {
        ScrollView {
            Text(previewText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            hint("↩", filling == nil ? (Prefs.autoPaste && Paster.canAutoPaste ? "Paste" : "Copy") : "Next / Use")
            hint("⌘↩", "Copy only")
            hint("⌘O", "Open in Reprise")
            hint("esc", filling == nil ? "Close" : "Back")
            Spacer()
            if let s = selected { Text("~\(Template.estimateTokens(length: s.length).formatted()) tokens").foregroundStyle(.secondary) }
        }
        .font(.caption)
        .padding(.horizontal, 18)
        .frame(height: 34)
        .background(.black.opacity(look == .ink ? 0.2 : 0.04))
        .background {
            Group {
                Button("") { activate(paste: false) }.keyboardShortcut(.return, modifiers: .command)
                Button("") { openInApp() }.keyboardShortcut("o", modifiers: .command)
            }
            .opacity(0)
        }
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Text(key).font(.caption.monospaced().weight(.semibold))
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
            Text(label).foregroundStyle(.secondary)
        }
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
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(hex: item.color).gradient)
                .frame(width: 4, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(item.title).font(.body.weight(.medium)).lineLimit(1)
                    if item.isTemplate { Image(systemName: "curlybraces").font(.caption2).foregroundStyle(Color(hex: item.color)) }
                    if item.pinned { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.orange) }
                }
                Text(project).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if item.useCount > 0 { Text("×\(item.useCount)").font(.caption.monospacedDigit()).foregroundStyle(.tertiary) }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: item.color).opacity(0.22))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color(hex: item.color).opacity(0.35), lineWidth: 0.5))
            }
        }
        .contentShape(Rectangle())
    }
}
