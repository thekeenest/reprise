import Foundation

/// The library. One SQLite file (WAL) shared by the app, the CLI and the MCP server.
public final class Store: @unchecked Sendable {
    public let db: SQLite
    public let root: URL
    public var attachmentsDir: URL { root.appendingPathComponent("Attachments", isDirectory: true) }

    public static var defaultRoot: URL {
        if let custom = ProcessInfo.processInfo.environment["REPRISE_HOME"], !custom.isEmpty {
            return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Reprise", isDirectory: true)
    }

    public init(root: URL = Store.defaultRoot) throws {
        self.root = root
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        db = try SQLite(path: root.appendingPathComponent("library.sqlite").path)
        try FileManager.default.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)
        try migrate()
    }

    // MARK: Schema

    private func migrate() throws {
        let version = try db.scalarInt("PRAGMA user_version")
        if version < 1 {
            try db.exec("""
            CREATE TABLE IF NOT EXISTS spaces(
              id INTEGER PRIMARY KEY, name TEXT NOT NULL, color TEXT NOT NULL,
              icon TEXT NOT NULL DEFAULT 'square.stack.3d.up.fill', sort REAL NOT NULL DEFAULT 0, created_at REAL NOT NULL);
            CREATE TABLE IF NOT EXISTS projects(
              id INTEGER PRIMARY KEY, space_id INTEGER NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
              name TEXT NOT NULL, color TEXT NOT NULL, sort REAL NOT NULL DEFAULT 0, created_at REAL NOT NULL);
            CREATE TABLE IF NOT EXISTS prompts(
              id INTEGER PRIMARY KEY, project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
              title TEXT NOT NULL, body TEXT NOT NULL DEFAULT '', color TEXT NOT NULL, tags TEXT NOT NULL DEFAULT '',
              pinned INTEGER NOT NULL DEFAULT 0, is_template INTEGER NOT NULL DEFAULT 0,
              use_count INTEGER NOT NULL DEFAULT 0, last_used_at REAL,
              created_at REAL NOT NULL, updated_at REAL NOT NULL,
              slug TEXT NOT NULL DEFAULT '', export_command INTEGER NOT NULL DEFAULT 0, trashed INTEGER NOT NULL DEFAULT 0);
            CREATE INDEX IF NOT EXISTS prompts_project ON prompts(project_id, trashed, updated_at DESC);
            CREATE INDEX IF NOT EXISTS prompts_updated ON prompts(trashed, updated_at DESC);
            CREATE INDEX IF NOT EXISTS prompts_title ON prompts(title COLLATE NOCASE);
            CREATE VIRTUAL TABLE IF NOT EXISTS prompts_fts USING fts5(
              title, body, tags, content='prompts', content_rowid='id',
              tokenize='unicode61 remove_diacritics 2', prefix='2 3');
            CREATE TRIGGER IF NOT EXISTS prompts_ai AFTER INSERT ON prompts BEGIN
              INSERT INTO prompts_fts(rowid, title, body, tags) VALUES (new.id, new.title, new.body, new.tags);
            END;
            CREATE TRIGGER IF NOT EXISTS prompts_ad AFTER DELETE ON prompts BEGIN
              INSERT INTO prompts_fts(prompts_fts, rowid, title, body, tags) VALUES ('delete', old.id, old.title, old.body, old.tags);
            END;
            CREATE TRIGGER IF NOT EXISTS prompts_au AFTER UPDATE OF title, body, tags ON prompts BEGIN
              INSERT INTO prompts_fts(prompts_fts, rowid, title, body, tags) VALUES ('delete', old.id, old.title, old.body, old.tags);
              INSERT INTO prompts_fts(rowid, title, body, tags) VALUES (new.id, new.title, new.body, new.tags);
            END;
            CREATE TABLE IF NOT EXISTS attachments(
              id INTEGER PRIMARY KEY, prompt_id INTEGER NOT NULL REFERENCES prompts(id) ON DELETE CASCADE,
              kind TEXT NOT NULL, name TEXT NOT NULL, value TEXT NOT NULL, created_at REAL NOT NULL);
            CREATE INDEX IF NOT EXISTS attachments_prompt ON attachments(prompt_id);
            CREATE TABLE IF NOT EXISTS versions(
              id INTEGER PRIMARY KEY, prompt_id INTEGER NOT NULL REFERENCES prompts(id) ON DELETE CASCADE,
              title TEXT NOT NULL, body TEXT NOT NULL, created_at REAL NOT NULL);
            CREATE INDEX IF NOT EXISTS versions_prompt ON versions(prompt_id, created_at DESC);
            PRAGMA user_version = 1;
            """)
        }
        if version < 2 {
            try db.exec("CREATE INDEX IF NOT EXISTS prompts_slug ON prompts(slug); PRAGMA user_version = 2;")
        }
    }

    private var now: Double { Date().timeIntervalSince1970 }

    // MARK: Spaces & projects

    public func spaces() throws -> [Space] {
        try db.query("SELECT id, name, color, icon, sort FROM spaces ORDER BY sort, id") {
            Space(id: $0.int(0), name: $0.text(1), color: $0.text(2), icon: $0.text(3), sort: $0.double(4))
        }
    }

    public func projects() throws -> [Project] {
        try db.query("SELECT id, space_id, name, color, sort FROM projects ORDER BY sort, id") {
            Project(id: $0.int(0), spaceID: $0.int(1), name: $0.text(2), color: $0.text(3), sort: $0.double(4))
        }
    }

    @discardableResult
    public func createSpace(name: String, color: String = Palette.random(), icon: String = "square.stack.3d.up.fill") throws -> Space {
        let sort = Double(try db.scalarInt("SELECT COALESCE(MAX(sort), 0) + 1 FROM spaces"))
        let id = try db.run("INSERT INTO spaces(name, color, icon, sort, created_at) VALUES (?,?,?,?,?)",
                            [.text(name), .text(color), .text(icon), .double(sort), .double(now)])
        return Space(id: id, name: name, color: color, icon: icon, sort: sort)
    }

    public func updateSpace(_ s: Space) throws {
        try db.run("UPDATE spaces SET name=?, color=?, icon=?, sort=? WHERE id=?",
                   [.text(s.name), .text(s.color), .text(s.icon), .double(s.sort), .int(s.id)])
    }

    public func deleteSpace(_ id: ID) throws { try db.run("DELETE FROM spaces WHERE id=?", [.int(id)]) }

    @discardableResult
    public func createProject(spaceID: ID, name: String, color: String? = nil) throws -> Project {
        let color = color ?? Palette.random()
        let sort = Double(try db.scalarInt("SELECT COALESCE(MAX(sort), 0) + 1 FROM projects WHERE space_id=?", [.int(spaceID)]))
        let id = try db.run("INSERT INTO projects(space_id, name, color, sort, created_at) VALUES (?,?,?,?,?)",
                            [.int(spaceID), .text(name), .text(color), .double(sort), .double(now)])
        return Project(id: id, spaceID: spaceID, name: name, color: color, sort: sort)
    }

    public func updateProject(_ p: Project) throws {
        try db.run("UPDATE projects SET space_id=?, name=?, color=?, sort=? WHERE id=?",
                   [.int(p.spaceID), .text(p.name), .text(p.color), .double(p.sort), .int(p.id)])
    }

    public func deleteProject(_ id: ID) throws { try db.run("DELETE FROM projects WHERE id=?", [.int(id)]) }

    /// Guarantees there is somewhere to put a prompt.
    public func ensureInbox() throws -> Project {
        if let p = try projects().first { return p }
        let s = try createSpace(name: "Personal", color: "#7A5CFA", icon: "person.crop.circle.fill")
        return try createProject(spaceID: s.id, name: "Inbox", color: "#4D7CFE")
    }

    // MARK: Prompts

    private static let summaryColumns = "p.id, p.project_id, p.title, substr(p.body, 1, 280), p.color, p.pinned, p.is_template, p.use_count, p.updated_at, length(p.body)"

    private func summary(_ r: SQLite.Row) -> PromptSummary {
        PromptSummary(id: r.int(0), projectID: r.int(1), title: r.text(2),
                      snippet: Store.collapse(r.text(3)), color: r.text(4), pinned: r.bool(5),
                      isTemplate: r.bool(6), useCount: Int(r.int(7)),
                      updatedAt: Date(timeIntervalSince1970: r.double(8)), length: Int(r.int(9)))
    }

    public static func collapse(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        var lastSpace = false
        for ch in s {
            if ch == "*" || ch == "`" || ch == "_" { continue }
            if ch.isWhitespace || ch == "#" {
                if !lastSpace && !out.isEmpty { out.append(" "); lastSpace = true }
            } else { out.append(ch); lastSpace = false }
        }
        return out
    }

    private func orderClause(_ sort: PromptSort) -> String {
        switch sort {
        case .edited: return "p.pinned DESC, p.updated_at DESC"
        case .used: return "p.use_count DESC, p.last_used_at DESC"
        case .created: return "p.created_at DESC"
        case .name: return "p.title COLLATE NOCASE ASC"
        }
    }

    private func scopeClause(_ scope: PromptScope) -> (String, [SQLite.Value]) {
        switch scope {
        case .all: return ("p.trashed = 0", [])
        case .pinned: return ("p.trashed = 0 AND p.pinned = 1", [])
        case .templates: return ("p.trashed = 0 AND p.is_template = 1", [])
        case .recent: return ("p.trashed = 0 AND p.last_used_at IS NOT NULL", [])
        case .trash: return ("p.trashed = 1", [])
        case .project(let id): return ("p.trashed = 0 AND p.project_id = ?", [.int(id)])
        case .space(let id): return ("p.trashed = 0 AND p.project_id IN (SELECT id FROM projects WHERE space_id = ?)", [.int(id)])
        }
    }

    public func summaries(scope: PromptScope, sort: PromptSort = .edited, query: String = "", limit: Int = 5000) throws -> [PromptSummary] {
        let (whereSQL, args) = scopeClause(scope)
        let order = scope == .recent ? "p.last_used_at DESC" : orderClause(sort)
        let q = Store.ftsQuery(query)
        if q.isEmpty {
            return try db.query("SELECT \(Store.summaryColumns) FROM prompts p WHERE \(whereSQL) ORDER BY \(order) LIMIT \(limit)", args, summary)
        }
        // Title matches weigh 6x body matches.
        let sql = """
        SELECT \(Store.summaryColumns) FROM prompts_fts f JOIN prompts p ON p.id = f.rowid
        WHERE prompts_fts MATCH ? AND \(whereSQL)
        ORDER BY bm25(prompts_fts, 6.0, 1.0, 3.0) LIMIT \(limit)
        """
        return try db.query(sql, [.text(q)] + args, summary)
    }

    /// Turns free text into a safe FTS5 prefix query: `fix bug` -> `"fix"* "bug"*`.
    public static func ftsQuery(_ raw: String) -> String {
        raw.split(whereSeparator: { $0.isWhitespace })
            .map { $0.replacingOccurrences(of: "\"", with: "") }
            .filter { !$0.isEmpty }
            .map { "\"\($0)\"*" }
            .joined(separator: " ")
    }

    public func counts() throws -> [String: Int] {
        let r = try db.query("""
        SELECT
          SUM(trashed = 0), SUM(trashed = 0 AND pinned = 1), SUM(trashed = 0 AND is_template = 1),
          SUM(trashed = 0 AND last_used_at IS NOT NULL), SUM(trashed = 1)
        FROM prompts
        """) { r in [Int(r.int(0)), Int(r.int(1)), Int(r.int(2)), Int(r.int(3)), Int(r.int(4))] }.first ?? [0, 0, 0, 0, 0]
        var out = ["all": r[0], "pinned": r[1], "templates": r[2], "recent": r[3], "trash": r[4]]
        for (pid, n) in try db.query("SELECT project_id, COUNT(*) FROM prompts WHERE trashed = 0 GROUP BY project_id", [], { ($0.int(0), Int($0.int(1))) }) {
            out["p\(pid)"] = n
        }
        return out
    }

    private func prompt(_ r: SQLite.Row) -> Prompt {
        Prompt(id: r.int(0), projectID: r.int(1), title: r.text(2), body: r.text(3), color: r.text(4), tags: r.text(5),
               pinned: r.bool(6), useCount: Int(r.int(7)), lastUsedAt: r.optionalDouble(8).map(Date.init(timeIntervalSince1970:)),
               createdAt: Date(timeIntervalSince1970: r.double(9)), updatedAt: Date(timeIntervalSince1970: r.double(10)),
               slug: r.text(11), exportCommand: r.bool(12), trashed: r.bool(13))
    }

    private static let promptColumns = "id, project_id, title, body, color, tags, pinned, use_count, last_used_at, created_at, updated_at, slug, export_command, trashed"

    public func prompt(_ id: ID) throws -> Prompt? {
        try db.query("SELECT \(Store.promptColumns) FROM prompts WHERE id = ?", [.int(id)], prompt).first
    }

    /// Lookup by exact title (case-insensitive), then slug, then numeric id. Used by includes, CLI and MCP.
    public func prompt(named name: String) throws -> Prompt? {
        let n = name.trimmingCharacters(in: .whitespaces)
        if let p = try db.query("SELECT \(Store.promptColumns) FROM prompts WHERE trashed = 0 AND title = ? COLLATE NOCASE ORDER BY updated_at DESC LIMIT 1", [.text(n)], prompt).first { return p }
        if let p = try db.query("SELECT \(Store.promptColumns) FROM prompts WHERE trashed = 0 AND slug = ? LIMIT 1", [.text(n.slugified)], prompt).first { return p }
        if let id = Int64(n) { return try prompt(id) }
        return nil
    }

    public func allPrompts(includeTrashed: Bool = false) throws -> [Prompt] {
        try db.query("SELECT \(Store.promptColumns) FROM prompts \(includeTrashed ? "" : "WHERE trashed = 0") ORDER BY id", [], prompt)
    }

    @discardableResult
    public func createPrompt(projectID: ID, title: String, body: String = "", color: String? = nil, tags: String = "") throws -> Prompt {
        let t = now
        let color = color ?? Palette.random()
        let title = title.isEmpty ? "Untitled prompt" : title
        let slug = try uniqueSlug(title.slugified)
        let id = try db.run("""
        INSERT INTO prompts(project_id, title, body, color, tags, is_template, created_at, updated_at, slug)
        VALUES (?,?,?,?,?,?,?,?,?)
        """, [.int(projectID), .text(title), .text(body), .text(color), .text(tags), .bool(Template.hasPlaceholders(body)), .double(t), .double(t), .text(slug)])
        return Prompt(id: id, projectID: projectID, title: title, body: body, color: color, tags: tags, pinned: false,
                      useCount: 0, lastUsedAt: nil, createdAt: Date(timeIntervalSince1970: t), updatedAt: Date(timeIntervalSince1970: t),
                      slug: slug, exportCommand: false, trashed: false)
    }

    private func uniqueSlug(_ base: String, excluding id: ID? = nil) throws -> String {
        let base = base.isEmpty ? "prompt" : base
        var candidate = base
        var n = 2
        while try db.scalarInt("SELECT COUNT(*) FROM prompts WHERE slug = ? AND id != ?", [.text(candidate), .int(id ?? -1)]) > 0 {
            candidate = "\(base)-\(n)"; n += 1
        }
        return candidate
    }

    public func updatePrompt(_ p: Prompt) throws {
        let slug = try uniqueSlug(p.slug.isEmpty ? p.title.slugified : p.slug.slugified, excluding: p.id)
        try db.run("""
        UPDATE prompts SET project_id=?, title=?, body=?, color=?, tags=?, pinned=?, is_template=?, updated_at=?, slug=?, export_command=?, trashed=?
        WHERE id=?
        """, [.int(p.projectID), .text(p.title), .text(p.body), .text(p.color), .text(p.tags), .bool(p.pinned),
              .bool(Template.hasPlaceholders(p.body)), .double(now), .text(slug), .bool(p.exportCommand), .bool(p.trashed), .int(p.id)])
    }

    /// Hot path for the editor: only touches body + derived flags.
    public func saveBody(_ id: ID, body: String) throws {
        try db.run("UPDATE prompts SET body=?, is_template=?, updated_at=? WHERE id=?",
                   [.text(body), .bool(Template.hasPlaceholders(body)), .double(now), .int(id)])
    }

    public func setFlag(_ id: ID, pinned: Bool? = nil, trashed: Bool? = nil, exportCommand: Bool? = nil) throws {
        if let pinned { try db.run("UPDATE prompts SET pinned=? WHERE id=?", [.bool(pinned), .int(id)]) }
        if let trashed { try db.run("UPDATE prompts SET trashed=? WHERE id=?", [.bool(trashed), .int(id)]) }
        if let exportCommand { try db.run("UPDATE prompts SET export_command=? WHERE id=?", [.bool(exportCommand), .int(id)]) }
    }

    public func move(_ id: ID, toProject projectID: ID) throws {
        try db.run("UPDATE prompts SET project_id=?, updated_at=? WHERE id=?", [.int(projectID), .double(now), .int(id)])
    }

    public func deletePrompt(_ id: ID) throws {
        for a in try attachments(id) where a.kind != .link { try? FileManager.default.removeItem(atPath: a.value) }
        try db.run("DELETE FROM prompts WHERE id=?", [.int(id)])
    }

    public func emptyTrash() throws {
        for id in try db.query("SELECT id FROM prompts WHERE trashed = 1", [], { $0.int(0) }) { try deletePrompt(id) }
    }

    @discardableResult
    public func duplicate(_ id: ID) throws -> Prompt? {
        guard let p = try prompt(id) else { return nil }
        let copy = try createPrompt(projectID: p.projectID, title: p.title + " copy", body: p.body, color: p.color, tags: p.tags)
        for a in try attachments(id) where a.kind == .link { try addLink(copy.id, url: a.value, name: a.name) }
        return copy
    }

    public func markUsed(_ id: ID) throws {
        try db.run("UPDATE prompts SET use_count = use_count + 1, last_used_at = ? WHERE id = ?", [.double(now), .int(id)])
    }

    // MARK: Versions

    public func snapshot(_ id: ID) throws {
        guard let p = try prompt(id) else { return }
        let last = try db.query("SELECT body FROM versions WHERE prompt_id=? ORDER BY created_at DESC LIMIT 1", [.int(id)]) { $0.text(0) }.first
        guard last != p.body, !p.body.isEmpty else { return }
        try db.run("INSERT INTO versions(prompt_id, title, body, created_at) VALUES (?,?,?,?)",
                   [.int(id), .text(p.title), .text(p.body), .double(now)])
        // Keep the newest 50 versions per prompt.
        try db.run("DELETE FROM versions WHERE prompt_id=? AND id NOT IN (SELECT id FROM versions WHERE prompt_id=? ORDER BY created_at DESC LIMIT 50)",
                   [.int(id), .int(id)])
    }

    public func versions(_ id: ID) throws -> [PromptVersion] {
        try db.query("SELECT id, prompt_id, title, body, created_at FROM versions WHERE prompt_id=? ORDER BY created_at DESC", [.int(id)]) {
            PromptVersion(id: $0.int(0), promptID: $0.int(1), title: $0.text(2), body: $0.text(3), createdAt: Date(timeIntervalSince1970: $0.double(4)))
        }
    }

    // MARK: Attachments

    public func attachments(_ promptID: ID) throws -> [Attachment] {
        try db.query("SELECT id, prompt_id, kind, name, value, created_at FROM attachments WHERE prompt_id=? ORDER BY id", [.int(promptID)]) {
            Attachment(id: $0.int(0), promptID: $0.int(1), kind: Attachment.Kind(rawValue: $0.text(2)) ?? .file,
                       name: $0.text(3), value: $0.text(4), createdAt: Date(timeIntervalSince1970: $0.double(5)))
        }
    }

    /// Copies the file into the library (so prompts never break when Downloads is cleaned up).
    @discardableResult
    public func addFile(_ promptID: ID, from url: URL) throws -> Attachment {
        let ext = url.pathExtension.lowercased()
        let isImage = ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp", "svg"].contains(ext)
        let dir = attachmentsDir.appendingPathComponent("\(promptID)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var dest = dir.appendingPathComponent(url.lastPathComponent)
        var n = 2
        while FileManager.default.fileExists(atPath: dest.path) {
            dest = dir.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)-\(n).\(ext)"); n += 1
        }
        try FileManager.default.copyItem(at: url, to: dest)
        return try insertAttachment(promptID, kind: isImage ? .image : .file, name: dest.lastPathComponent, value: dest.path)
    }

    @discardableResult
    public func addImageData(_ promptID: ID, data: Data, ext: String = "png") throws -> Attachment {
        let dir = attachmentsDir.appendingPathComponent("\(promptID)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmmss"
        let name = "image-\(f.string(from: Date()))-\(Int.random(in: 100...999)).\(ext)"
        let dest = dir.appendingPathComponent(name)
        try data.write(to: dest)
        return try insertAttachment(promptID, kind: .image, name: name, value: dest.path)
    }

    @discardableResult
    public func addLink(_ promptID: ID, url: String, name: String? = nil) throws -> Attachment {
        let display = name ?? URL(string: url)?.host ?? url
        return try insertAttachment(promptID, kind: .link, name: display, value: url)
    }

    private func insertAttachment(_ promptID: ID, kind: Attachment.Kind, name: String, value: String) throws -> Attachment {
        let t = now
        let id = try db.run("INSERT INTO attachments(prompt_id, kind, name, value, created_at) VALUES (?,?,?,?,?)",
                            [.int(promptID), .text(kind.rawValue), .text(name), .text(value), .double(t)])
        try db.run("UPDATE prompts SET updated_at=? WHERE id=?", [.double(t), .int(promptID)])
        return Attachment(id: id, promptID: promptID, kind: kind, name: name, value: value, createdAt: Date(timeIntervalSince1970: t))
    }

    public func deleteAttachment(_ a: Attachment) throws {
        if a.kind != .link { try? FileManager.default.removeItem(atPath: a.value) }
        try db.run("DELETE FROM attachments WHERE id=?", [.int(a.id)])
    }

    // MARK: Rendering

    /// Renders a template with includes resolved against the library.
    public func render(_ p: Prompt, values: [String: String], clipboard: @escaping () -> String = { "" }) -> String {
        Template.render(p.body, Template.Context(values: values, clipboard: clipboard, resolve: { [weak self] in
            (try? self?.prompt(named: $0))??.body
        }))
    }

    public func variables(_ p: Prompt) -> [Template.Variable] {
        Template.variables(in: p.body, resolve: { [weak self] in (try? self?.prompt(named: $0))??.body })
    }

    /// The text that goes to an agent: rendered body + attachment references agents understand
    /// (Claude Code and Codex both accept absolute image/file paths and URLs inline).
    public func payload(_ p: Prompt, values: [String: String], includeAttachments: Bool = true, clipboard: @escaping () -> String = { "" }) -> String {
        var text = render(p, values: values, clipboard: clipboard)
        guard includeAttachments, let atts = try? attachments(p.id), !atts.isEmpty else { return text }
        let refs = atts.map { a -> String in
            a.kind == .link ? a.value : (a.value.contains(" ") ? "\"\(a.value)\"" : a.value)
        }
        text += "\n\n" + refs.joined(separator: "\n")
        return text
    }

    // MARK: Stats

    public func stats() throws -> (prompts: Int, characters: Int, templates: Int) {
        try db.query("SELECT COUNT(*), COALESCE(SUM(length(body)), 0), COALESCE(SUM(is_template), 0) FROM prompts WHERE trashed = 0") {
            (Int($0.int(0)), Int($0.int(1)), Int($0.int(2)))
        }.first ?? (0, 0, 0)
    }
}
