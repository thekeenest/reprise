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
    /// The margin apparatus for the open prompt, refreshed on load and on each (debounced) save.
    var blanks: [Template.Variable] = []
    var includes: [String] = []

    // Sheets & transient UI
    var fillTarget: Prompt?
    var historyTarget: Prompt?
    var namingRequest: NamingRequest?
    var showHarvest = false
    var toast: Toast?
    var focusTitle = false
    /// The margin apparatus beside the page (blanks, includes, files, publishing).
    var showMargin = UserDefaults.standard.object(forKey: "showMargin") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showMargin, forKey: "showMargin") }
    }
    /// Values typed into the margin's blanks for the current prompt.
    var fillValues: [String: String] = [:] {
        didSet { if let id = current?.id { Prefs.rememberValues(fillValues, for: id) } }
    }

    // MARK: Layout state

    var showSidebar = UserDefaults.standard.object(forKey: "showSidebar") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showSidebar, forKey: "showSidebar") }
    }
    /// Bumped by ⌘K to focus the search field.
    var focusSearchToken = 0
    /// Bumped to open the Settings window (demo recording).
    var openSettingsToken = 0

    enum Renaming: Equatable { case space(ID), project(ID) }
    /// The sidebar row being renamed in place.
    var renaming: Renaming?

    enum Deletion: Identifiable {
        case space(Space), project(Project)
        var id: String { switch self { case .space(let s): "s\(s.id)"; case .project(let p): "p\(p.id)" } }
    }
    var confirmDelete: Deletion?

    /// Spaces folded shut in the sidebar.
    var foldedSpaces: Set<ID> = Set((UserDefaults.standard.array(forKey: "foldedSpaces") as? [NSNumber])?.map(\.int64Value) ?? []) {
        didSet { UserDefaults.standard.set(foldedSpaces.map { NSNumber(value: $0) }, forKey: "foldedSpaces") }
    }
    /// Outline layout: projects unfolded to show their prompts.
    var openProjects: Set<ID> = Set((UserDefaults.standard.array(forKey: "openProjects") as? [NSNumber])?.map(\.int64Value) ?? []) {
        didSet { UserDefaults.standard.set(openProjects.map { NSNumber(value: $0) }, forKey: "openProjects") }
    }

    func toggleFold(space id: ID) {
        withAnimation(.easeOut(duration: 0.18)) {
            if foldedSpaces.contains(id) { foldedSpaces.remove(id) } else { foldedSpaces.insert(id) }
        }
    }

    func toggleOpen(project id: ID) {
        withAnimation(.easeOut(duration: 0.18)) {
            if openProjects.contains(id) { openProjects.remove(id) } else { openProjects.insert(id) }
        }
    }

    /// A search or a filter narrows the library (the outline then shows only matching prompts).
    var filtering: Bool { !query.isEmpty || (scope != .all && scope != .trash) }

    /// Copy the open prompt with the values typed into its blanks.
    func copyCurrent() {
        guard let p = current else { return }
        flushSave()
        copy((try? store.prompt(p.id)) ?? p, values: fillValues)
    }

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
        var isError = false
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
        fillValues = Prefs.lastValues(for: id)
        refreshApparatus()
        updateStats(p.body)
    }

    func project(_ id: ID) -> Project? { projects.first { $0.id == id } }
    func space(_ id: ID) -> Space? { spaces.first { $0.id == id } }

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
        if current?.id == id { refreshApparatus() }
        updateStats(text)
        liveStats.saved = true
    }

    func refreshApparatus() {
        guard let p = current else { blanks = []; includes = []; return }
        blanks = store.variables(p)
        if p.body.contains("{{>") || p.body.contains("{{ >") {
            var seen = Set<String>()
            includes = Template.tokenize(p.body).compactMap { t in
                if case .include(let n) = t, seen.insert(n).inserted { return n }
                return nil
            }
        } else {
            includes = []
        }
    }

    func open(named title: String) {
        guard let p = try? store.prompt(named: title) else { show("No prompt named “\(title)”", error: true); return }
        flushSave()
        if scope != .all, !items.contains(where: { $0.id == p.id }) { scope = .all }
        query = ""
        reloadList()
        selectedID = p.id
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
                              variables: blanks.count, saved: pendingBody == nil)
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

    /// Set by a column's "+" so the next new prompt lands in that project.
    @ObservationIgnored private var nextProjectID: ID?
    func scopeForNew(_ id: ID) { nextProjectID = id }

    var scopeTitle: String {
        switch scope {
        case .all: return "All Prompts"
        case .pinned: return "Pinned"
        case .templates: return "Templates"
        case .recent: return "Recently Used"
        case .trash: return "Trash"
        case .project(let id): return project(id)?.name ?? "Project"
        case .space(let id): return space(id)?.name ?? "Space"
        }
    }

    var targetProjectID: ID {
        if let n = nextProjectID { nextProjectID = nil; return n }
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
        if scope == .trash || scope == .pinned || scope == .recent || scope == .templates { scope = .all }
        if case .project(let id) = scope, id != p.projectID { scope = .all }
        query = ""
        reloadList()
        selectedID = p.id
        openProjects.insert(p.projectID)
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
        show(restoring ? "Restored" : "Moved to Trash")
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
        show("Moved to \(project(projectID)?.name ?? "project")")
    }

    func setColor(_ id: ID, _ hex: String) {
        if current?.id == id { update { $0.color = hex } }
        else if var p = try? store.prompt(id) { p.color = hex; try? store.updatePrompt(p); reloadList() }
    }

    /// "Use" = the primary action. The open prompt copies with the margin's values;
    /// another template opens the fill sheet; plain prompts copy immediately.
    func use(_ id: ID) {
        flushSave()
        guard let p = try? store.prompt(id) else { return }
        if id == current?.id { copy(p, values: fillValues); return }
        if !store.variables(p).isEmpty { fillTarget = p; return }
        copy(p, values: [:])
    }

    func copy(_ p: Prompt, values: [String: String]) {
        let text = store.payload(p, values: values, includeAttachments: Prefs.includeAttachmentPaths, clipboard: Paster.clipboardString)
        Paster.copy(text, images: Prefs.includeAttachmentPaths ? [] : imageURLs(p.id))
        try? store.markUsed(p.id)
        Prefs.rememberValues(values, for: p.id)
        show("Copied “\(p.title)”, \(Template.estimateTokens(text).formatted()) tokens")
    }

    func copyRaw(_ id: ID) {
        flushSave()
        guard let p = try? store.prompt(id) else { return }
        Paster.copy(p.body)
        show("Copied the source of “\(p.title)”")
    }

    func imageURLs(_ id: ID) -> [URL] {
        ((try? store.attachments(id)) ?? []).filter { $0.kind == .image }.map { URL(fileURLWithPath: $0.value) }
    }

    // MARK: Attachments

    func attach(files: [URL]) {
        guard let id = current?.id else { return }
        for f in files { _ = try? store.addFile(id, from: f) }
        attachments = (try? store.attachments(id)) ?? []
        show("Attached \(files.count) file\(files.count == 1 ? "" : "s")")
    }

    func attach(imageData: Data, ext: String) {
        guard let id = current?.id else { return }
        _ = try? store.addImageData(id, data: imageData, ext: ext)
        attachments = (try? store.attachments(id)) ?? []
        show("Image attached")
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
        foldedSpaces.remove(s.id)
        if let p {
            if Variant.library == .columns { scope = .project(p.id) } else { openProjects.insert(p.id) }
            renaming = .project(p.id)
        }
    }

    func createProject(spaceID: ID, name: String, color: String) {
        guard let p = try? store.createProject(spaceID: spaceID, name: name, color: color) else { return }
        reloadStructure()
        foldedSpaces.remove(spaceID)
        if Variant.library == .columns { scope = .project(p.id) } else { openProjects.insert(p.id) }
    }

    func save(_ s: Space) { try? store.updateSpace(s); reloadStructure() }
    func save(_ p: Project) { try? store.updateProject(p); reloadStructure() }

    /// Where a deleted project's prompts go: another project in the same space if there is one.
    func fallbackProject(excluding ids: Set<ID>, preferSpace: ID?) -> Project? {
        let others = projects.filter { !ids.contains($0.id) }
        return others.first { $0.spaceID == preferSpace } ?? others.first
    }

    func promptCount(in projectIDs: Set<ID>) -> Int {
        ((try? store.allPrompts(includeTrashed: true)) ?? []).filter { projectIDs.contains($0.projectID) }.count
    }

    /// Deleting never deletes prompts: they move to another project first.
    private func rehome(_ ids: Set<ID>, preferSpace: ID?) -> Project? {
        guard let target = fallbackProject(excluding: ids, preferSpace: preferSpace) else { return nil }
        for p in (try? store.allPrompts(includeTrashed: true)) ?? [] where ids.contains(p.projectID) {
            try? store.move(p.id, toProject: target.id)
        }
        return target
    }

    func deleteSpace(_ s: Space) {
        guard spaces.count > 1 else { show("Keep at least one space", error: true); return }
        let ids = Set(projects.filter { $0.spaceID == s.id }.map(\.id))
        guard let target = rehome(ids, preferSpace: nil) else { show("Make another project first", error: true); return }
        try? store.deleteSpace(s.id); scope = .all; reloadStructure(); reloadList()
        if let id = current?.id { current = try? store.prompt(id) }
        show("Deleted “\(s.name)”. Its prompts moved to \(target.name).")
    }

    func deleteProject(_ p: Project) {
        guard projects.count > 1 else { show("Keep at least one project", error: true); return }
        guard let target = rehome([p.id], preferSpace: p.spaceID) else { return }
        try? store.deleteProject(p.id); scope = .all; reloadStructure(); reloadList()
        if let id = current?.id { current = try? store.prompt(id) }
        show("Deleted “\(p.name)”. Its prompts moved to \(target.name).")
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
        show("Restored the version from \(v.createdAt.formatted(date: .abbreviated, time: .shortened))")
    }

    // MARK: Agents

    func syncAgents(silent: Bool) {
        do {
            let r = try AgentSync.sync(store: store, targets: Prefs.syncTargets)
            if !silent { show("Agent commands: \(r.summary)") }
        } catch {
            show("Sync failed: \(error.localizedDescription)", error: true)
        }
    }

    func importHarvest(_ candidates: [Harvest.Candidate], projectID: ID) {
        for c in candidates { _ = try? store.createPrompt(projectID: projectID, title: c.suggestedTitle, body: c.text) }
        reloadStructure(); reloadList()
        show("Saved \(candidates.count) harvested prompt\(candidates.count == 1 ? "" : "s")")
    }

    // MARK: Toasts

    func show(_ text: String, error: Bool = false) {
        let t = Toast(text: text, isError: error)
        withAnimation(.easeOut(duration: 0.18)) { toast = t }
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
