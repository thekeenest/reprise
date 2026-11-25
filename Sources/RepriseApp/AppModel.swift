import SwiftUI
import AppKit
import Observation
import RepriseCore

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    let store: Store
    var spaces: [Space] = []
    var projects: [Project] = []
    var counts: [String: Int] = [:]

    var scope: PromptScope = .all { didSet { if oldValue != scope { reloadList() } } }
    var sort: PromptSort = .edited { didSet { reloadList() } }
    var query: String = "" { didSet { scheduleSearch() } }
    var items: [PromptSummary] = []

    var selectedID: ID? { didSet { if oldValue != selectedID { loadSelected(previous: oldValue) } } }
    var current: Prompt?
    var attachments: [Attachment] = []
    var liveStats = LiveStats()

    // Sheets & transient UI
    var fillTarget: Prompt?
    var historyTarget: Prompt?
    var namingRequest: NamingRequest?
    var showHarvest = false
    var toast: Toast?
    var focusTitle = false

    @ObservationIgnored private var pendingBody: (ID, String)?
    @ObservationIgnored private var saveWork: DispatchWorkItem?
    @ObservationIgnored private var searchWork: DispatchWorkItem?
    @ObservationIgnored private var dirtySinceSnapshot = false
    @ObservationIgnored private let io = DispatchQueue(label: "reprise.io", qos: .userInitiated)

    struct LiveStats: Equatable {
        var characters = 0, words = 0, tokens = 0, variables = 0
        var saved = true
    }

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        var text: String
        var icon: String = "checkmark.circle.fill"
        var color: String = "#3DDC97"
    }

    struct NamingRequest: Identifiable {
        enum Kind { case newSpace, newProject(spaceID: ID), editSpace(Space), editProject(Project) }
        let id = UUID()
        var kind: Kind
    }

    init() {
        do {
            store = try Store()
            try Seed.installIfEmpty(store)
        } catch {
            fatalError("Reprise could not open its library: \(error)")
        }
        reloadStructure()
        reloadList()
        selectedID = items.first?.id
    }

    // MARK: Loading

    func reloadStructure() {
        spaces = (try? store.spaces()) ?? []
        projects = (try? store.projects()) ?? []
        counts = (try? store.counts()) ?? [:]
    }

    func reloadList() {
        items = (try? store.summaries(scope: scope, sort: sort, query: query)) ?? []
        counts = (try? store.counts()) ?? counts
    }

    private func scheduleSearch() {
        searchWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.reloadList() }
        searchWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: w)
    }

    private func loadSelected(previous: ID?) {
        flushSave()
        if let previous, dirtySinceSnapshot { try? store.snapshot(previous) }
        dirtySinceSnapshot = false
        guard let id = selectedID, let p = try? store.prompt(id) else {
            current = nil; attachments = []; return
        }
        current = p
        attachments = (try? store.attachments(id)) ?? []
        updateStats(p.body)
    }

    func project(_ id: ID) -> Project? { projects.first { $0.id == id } }
    func space(_ id: ID) -> Space? { spaces.first { $0.id == id } }

    /// Color driving the aura: selected prompt → selected project → space → brand violet.
    var accentHex: String {
        if let c = current { return c.color }
        switch scope {
        case .project(let id): return project(id)?.color ?? "#7A5CFA"
        case .space(let id): return space(id)?.color ?? "#7A5CFA"
        default: return "#7A5CFA"
        }
    }

    // MARK: Editing

    /// Called on every keystroke by the editor. Never triggers a SwiftUI re-render of the editor.
    func bodyDidChange(_ id: ID, _ text: String) {
        pendingBody = (id, text)
        dirtySinceSnapshot = true
        if liveStats.saved { liveStats.saved = false }
        saveWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.flushSave() }
        saveWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: w)
    }

    func flushSave() {
        saveWork?.cancel()
        guard let (id, text) = pendingBody else { return }
        pendingBody = nil
        let store = self.store
        let autoTitle = current?.id == id && (current?.title == "Untitled prompt")
        io.async {
            try? store.saveBody(id, body: text)
        }
        if current?.id == id {
            current?.body = text
            if autoTitle, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                current?.title = Harvest.title(for: text)
                if let c = current { try? store.updatePrompt(c) }
            }
        }
        if let i = items.firstIndex(where: { $0.id == id }) {
            items[i].snippet = Store.collapse(String(text.prefix(280)))
            items[i].isTemplate = Template.hasPlaceholders(text)
            items[i].length = text.utf16.count
            items[i].updatedAt = Date()
            if let t = current?.title, current?.id == id { items[i].title = t }
        }
        updateStats(text)
        liveStats.saved = true
    }

    func updateStats(_ text: String) {
        var words = 0
        var inWord = false
        for u in text.unicodeScalars {
            let ws = CharacterSet.whitespacesAndNewlines.contains(u)
            if !ws && !inWord { words += 1 }
            inWord = !ws
        }
        liveStats = LiveStats(characters: text.count, words: words, tokens: Template.estimateTokens(text),
                              variables: Template.variables(in: text).count, saved: pendingBody == nil)
    }

    func update(_ mutate: (inout Prompt) -> Void) {
        guard var p = current else { return }
        mutate(&p)
        p.title = p.title.trimmingCharacters(in: .newlines)
        current = p
        try? store.updatePrompt(p)
        if let fresh = try? store.prompt(p.id) { current?.slug = fresh.slug }
        if let i = items.firstIndex(where: { $0.id == p.id }) {
            items[i].title = p.title.isEmpty ? "Untitled prompt" : p.title
            items[i].color = p.color
            items[i].pinned = p.pinned
        }
    }

    // MARK: Commands

    var targetProjectID: ID {
        switch scope {
        case .project(let id): return id
        case .space(let sid): if let p = projects.first(where: { $0.spaceID == sid }) { return p.id }
        default: break
        }
        if let c = current { return c.projectID }
        return (try? store.ensureInbox().id) ?? projects.first?.id ?? 1
    }

    func newPrompt(body: String = "", title: String = "Untitled prompt") {
        flushSave()
        guard let p = try? store.createPrompt(projectID: targetProjectID, title: title, body: body) else { return }
        if case .project = scope {} else if scope != .all { scope = .all }
        query = ""
        reloadList()
        selectedID = p.id
        focusTitle = true
        reloadStructure()
    }

    func duplicate(_ id: ID) {
        flushSave()
        if let p = try? store.duplicate(id) { reloadList(); selectedID = p.id }
    }

    func togglePin(_ id: ID) {
        guard let p = try? store.prompt(id) else { return }
        try? store.setFlag(id, pinned: !p.pinned)
        if current?.id == id { current?.pinned = !p.pinned }
        reloadList()
    }

    func toggleAgentCommand(_ id: ID) {
        guard let p = try? store.prompt(id) else { return }
        try? store.setFlag(id, exportCommand: !p.exportCommand)
        if current?.id == id { current?.exportCommand = !p.exportCommand }
        syncAgents(silent: false)
    }

    func trash(_ id: ID) {
        flushSave()
        let restoring = scope == .trash
        try? store.setFlag(id, trashed: !restoring)
        if selectedID == id { selectedID = nil }
        reloadList()
        if selectedID == nil { selectedID = items.first?.id }
        show(restoring ? "Restored" : "Moved to Trash", icon: restoring ? "arrow.uturn.backward" : "trash", color: "#8E9AAF")
    }

    func deleteForever(_ id: ID) {
        try? store.deletePrompt(id)
        if selectedID == id { selectedID = nil }
        reloadList()
    }

    func emptyTrash() { try? store.emptyTrash(); reloadList(); selectedID = nil }

    func move(_ id: ID, to projectID: ID) {
        try? store.move(id, toProject: projectID)
        if current?.id == id { current?.projectID = projectID }
        reloadList(); reloadStructure()
        show("Moved to \(project(projectID)?.name ?? "project")", icon: "arrow.right.circle.fill", color: project(projectID)?.color ?? "#4D7CFE")
    }

    func setColor(_ id: ID, _ hex: String) {
        if current?.id == id { update { $0.color = hex } }
        else if var p = try? store.prompt(id) { p.color = hex; try? store.updatePrompt(p); reloadList() }
    }

    /// "Use" = the primary action. Templates open the fill sheet; plain prompts copy immediately.
    func use(_ id: ID) {
        flushSave()
        guard let p = try? store.prompt(id) else { return }
        if !store.variables(p).isEmpty { fillTarget = p; return }
        copy(p, values: [:])
    }

    func copy(_ p: Prompt, values: [String: String]) {
        let text = store.payload(p, values: values, includeAttachments: Prefs.includeAttachmentPaths, clipboard: Paster.clipboardString)
        Paster.copy(text, images: Prefs.includeAttachmentPaths ? [] : imageURLs(p.id))
        try? store.markUsed(p.id)
        Prefs.rememberValues(values, for: p.id)
        show("Copied “\(p.title)” · \(Template.estimateTokens(text).formatted()) tokens", color: p.color)
    }

    func copyRaw(_ id: ID) {
        flushSave()
        guard let p = try? store.prompt(id) else { return }
        Paster.copy(p.body)
        show("Copied source of “\(p.title)”", icon: "doc.on.doc.fill", color: p.color)
    }

    func imageURLs(_ id: ID) -> [URL] {
        ((try? store.attachments(id)) ?? []).filter { $0.kind == .image }.map { URL(fileURLWithPath: $0.value) }
    }

    // MARK: Attachments

    func attach(files: [URL]) {
        guard let id = current?.id else { return }
        for f in files { _ = try? store.addFile(id, from: f) }
        attachments = (try? store.attachments(id)) ?? []
        show("Attached \(files.count) file\(files.count == 1 ? "" : "s")", icon: "paperclip", color: current?.color ?? "#4D7CFE")
    }

    func attach(imageData: Data, ext: String) {
        guard let id = current?.id else { return }
        _ = try? store.addImageData(id, data: imageData, ext: ext)
        attachments = (try? store.attachments(id)) ?? []
        show("Image attached", icon: "photo.fill", color: current?.color ?? "#4D7CFE")
    }

    func attach(link: String) {
        guard let id = current?.id, !link.isEmpty else { return }
        var url = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.contains("://") { url = "https://" + url }
        _ = try? store.addLink(id, url: url)
        attachments = (try? store.attachments(id)) ?? []
    }

    func remove(_ a: Attachment) {
        try? store.deleteAttachment(a)
        attachments.removeAll { $0.id == a.id }
    }

    // MARK: Structure

    func createSpace(name: String, color: String, icon: String) {
        guard let s = try? store.createSpace(name: name, color: color, icon: icon) else { return }
        let p = try? store.createProject(spaceID: s.id, name: "General", color: Palette.random(near: Palette.hue(color)))
        reloadStructure()
        if let p { scope = .project(p.id) }
    }

    func createProject(spaceID: ID, name: String, color: String) {
        guard let p = try? store.createProject(spaceID: spaceID, name: name, color: color) else { return }
        reloadStructure()
        scope = .project(p.id)
    }

    func save(_ s: Space) { try? store.updateSpace(s); reloadStructure() }
    func save(_ p: Project) { try? store.updateProject(p); reloadStructure() }

    func deleteSpace(_ s: Space) {
        guard spaces.count > 1 else { show("Keep at least one space", icon: "exclamationmark.triangle.fill", color: "#FFC145"); return }
        try? store.deleteSpace(s.id); scope = .all; reloadStructure(); reloadList()
    }

    func deleteProject(_ p: Project) {
        guard projects.count > 1 else { show("Keep at least one project", icon: "exclamationmark.triangle.fill", color: "#FFC145"); return }
        try? store.deleteProject(p.id); scope = .all; reloadStructure(); reloadList()
    }

    // MARK: Versions

    func restore(_ v: PromptVersion) {
        guard var p = try? store.prompt(v.promptID) else { return }
        try? store.snapshot(p.id)
        p.body = v.body
        try? store.updatePrompt(p)
        historyTarget = nil
        let id = p.id
        selectedID = nil
        selectedID = id
        show("Restored version from \(v.createdAt.formatted(date: .abbreviated, time: .shortened))", icon: "clock.arrow.circlepath", color: p.color)
    }

    // MARK: Agents

    func syncAgents(silent: Bool) {
        do {
            let r = try AgentSync.sync(store: store, targets: Prefs.syncTargets)
            if !silent { show("Agent commands: \(r.summary)", icon: "terminal.fill", color: "#2EC4B6") }
        } catch {
            show("Sync failed: \(error.localizedDescription)", icon: "xmark.octagon.fill", color: "#FF6B6B")
        }
    }

    func importHarvest(_ candidates: [Harvest.Candidate], projectID: ID) {
        for c in candidates { _ = try? store.createPrompt(projectID: projectID, title: c.suggestedTitle, body: c.text) }
        reloadStructure(); reloadList()
        show("Saved \(candidates.count) harvested prompt\(candidates.count == 1 ? "" : "s")", icon: "leaf.fill", color: "#3DDC97")
    }

    // MARK: Toasts

    func show(_ text: String, icon: String = "checkmark.circle.fill", color: String = "#3DDC97") {
        let t = Toast(text: text, icon: icon, color: color)
        withAnimation(.spring(duration: 0.35)) { toast = t }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            if self?.toast?.id == t.id { withAnimation(.easeOut(duration: 0.3)) { self?.toast = nil } }
        }
    }
}

/// UserDefaults-backed preferences shared by views and non-view code.
enum Prefs {
    static var d: UserDefaults { .standard }
    static var includeAttachmentPaths: Bool { d.object(forKey: "includeAttachmentPaths") as? Bool ?? true }
    static var autoPaste: Bool { d.object(forKey: "autoPaste") as? Bool ?? true }
    static var syncTargets: [AgentSync.Target] {
        AgentSync.Target.allCases.filter { d.object(forKey: "sync.\($0.rawValue)") as? Bool ?? true }
    }

    static func rememberValues(_ v: [String: String], for id: ID) {
        guard !v.isEmpty else { return }
        d.set(v, forKey: "vars.\(id)")
    }

    static func lastValues(for id: ID) -> [String: String] {
        d.dictionary(forKey: "vars.\(id)") as? [String: String] ?? [:]
    }
}
