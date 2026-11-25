import Foundation

/// Publishes prompts as native slash commands:
///   Claude Code → ~/.claude/commands/<slug>.md   (invoke: /slug args)
///   Codex       → ~/.codex/prompts/<slug>.md     (invoke: /prompts:slug args)
/// Template variables become positional arguments ($1, $2…, or $ARGUMENTS for one).
/// Files are tagged as managed; Reprise never overwrites or deletes a file it didn't write.
public enum AgentSync {
    public enum Target: String, CaseIterable, Sendable {
        case claude = "Claude Code"
        case codex = "Codex"

        public var directory: URL {
            let home = FileManager.default.homeDirectoryForCurrentUser
            switch self {
            case .claude: return home.appendingPathComponent(".claude/commands", isDirectory: true)
            case .codex: return home.appendingPathComponent(".codex/prompts", isDirectory: true)
            }
        }

        public func invocation(_ slug: String) -> String {
            switch self {
            case .claude: return "/\(slug)"
            case .codex: return "/prompts:\(slug)"
            }
        }
    }

    public struct Report: Sendable {
        public var written: [String] = []
        public var removed: [String] = []
        public var skipped: [String] = []
        public var summary: String {
            "\(written.count) synced, \(removed.count) removed" + (skipped.isEmpty ? "" : ", \(skipped.count) skipped (name taken by your own file)")
        }
    }

    static let marker = "<!-- managed-by: reprise"

    public static func command(for p: Prompt, store: Store) -> (text: String, hint: String) {
        let vars = store.variables(p)
        var values: [String: String] = [:]
        if vars.count == 1 {
            values[vars[0].name] = "$ARGUMENTS"
        } else {
            for (i, v) in vars.enumerated() { values[v.name] = "$\(i + 1)" }
        }
        let body = store.render(p, values: values, clipboard: { "" })
        let hint = vars.map { v in v.isChoice ? "[\(v.options.joined(separator: "|"))]" : "[\(v.name)]" }.joined(separator: " ")
        let description = p.title.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\"", with: "'")
        var front = "---\ndescription: \"\(description)\"\n"
        if !hint.isEmpty { front += "argument-hint: \"\(hint)\"\n" }
        front += "---\n"
        return (front + "\(marker) id=\(p.id) -->\n\n" + body + "\n", hint)
    }

    @discardableResult
    public static func sync(store: Store, targets: [Target] = Target.allCases) throws -> Report {
        var report = Report()
        let exported = try store.allPrompts().filter { $0.exportCommand }
        for target in targets {
            let dir = target.directory
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            var keep = Set<String>()
            for p in exported {
                let file = dir.appendingPathComponent("\(p.slug).md")
                if let existing = try? String(contentsOf: file, encoding: .utf8), !existing.contains(marker) {
                    report.skipped.append("\(target.rawValue): \(p.slug)")
                    continue
                }
                try command(for: p, store: store).text.write(to: file, atomically: true, encoding: .utf8)
                keep.insert(file.lastPathComponent)
                report.written.append("\(target.rawValue): \(target.invocation(p.slug))")
            }
            // Remove commands we wrote earlier that are no longer exported.
            for f in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            where f.pathExtension == "md" && !keep.contains(f.lastPathComponent) {
                if let s = try? String(contentsOf: f, encoding: .utf8), s.contains(marker) {
                    try? FileManager.default.removeItem(at: f)
                    report.removed.append("\(target.rawValue): \(f.lastPathComponent)")
                }
            }
        }
        return report
    }
}

/// Plain-files escape hatch: the whole library as Markdown with YAML front matter.
/// Your prompts are never locked in.
public enum MarkdownIO {
    public static func export(store: Store, to folder: URL) throws -> Int {
        let spaces = Dictionary(uniqueKeysWithValues: try store.spaces().map { ($0.id, $0) })
        let projects = Dictionary(uniqueKeysWithValues: try store.projects().map { ($0.id, $0) })
        var n = 0
        for p in try store.allPrompts() {
            guard let proj = projects[p.projectID] else { continue }
            let spaceName = spaces[proj.spaceID]?.name ?? "Space"
            let dir = folder.appendingPathComponent(safe(spaceName)).appendingPathComponent(safe(proj.name))
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let atts = try store.attachments(p.id)
            var fm = "---\ntitle: \"\(p.title.replacingOccurrences(of: "\"", with: "'"))\"\ncolor: \"\(p.color)\"\n"
            if !p.tags.isEmpty { fm += "tags: [\(p.tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: ", "))]\n" }
            if p.pinned { fm += "pinned: true\n" }
            if !atts.isEmpty { fm += "attachments:\n" + atts.map { "  - \($0.value)" }.joined(separator: "\n") + "\n" }
            fm += "created: \(ISO8601DateFormatter().string(from: p.createdAt))\n---\n\n"
            try (fm + p.body + "\n").write(to: dir.appendingPathComponent("\(p.slug).md"), atomically: true, encoding: .utf8)
            n += 1
        }
        return n
    }

    /// Imports .md / .txt files. Subfolder name becomes the project.
    public static func importFiles(_ urls: [URL], store: Store, spaceID: ID) throws -> Int {
        var projectsByName = Dictionary(try store.projects().filter { $0.spaceID == spaceID }.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })
        var files: [URL] = []
        for u in urls {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: u.path, isDirectory: &isDir), isDir.boolValue {
                let e = FileManager.default.enumerator(at: u, includingPropertiesForKeys: nil)
                while let f = e?.nextObject() as? URL {
                    if ["md", "txt", "markdown"].contains(f.pathExtension.lowercased()) { files.append(f) }
                }
            } else { files.append(u) }
        }
        var n = 0
        try store.db.transaction {
            for f in files {
                guard let raw = try? String(contentsOf: f, encoding: .utf8) else { continue }
                var body = raw
                var title = f.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "-", with: " ")
                var color: String?
                if raw.hasPrefix("---\n"), let end = raw.range(of: "\n---\n", range: raw.index(raw.startIndex, offsetBy: 4)..<raw.endIndex) {
                    let fm = raw[raw.index(raw.startIndex, offsetBy: 4)..<end.lowerBound]
                    for line in fm.split(separator: "\n") {
                        let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
                        guard parts.count == 2 else { continue }
                        if parts[0] == "title" || parts[0] == "description" { title = parts[1] }
                        if parts[0] == "color" { color = parts[1] }
                    }
                    body = String(raw[end.upperBound...]).trimmingCharacters(in: .newlines)
                }
                let projectName = f.deletingLastPathComponent().lastPathComponent
                let project: Project
                if let p = projectsByName[projectName.lowercased()] { project = p }
                else {
                    project = try store.createProject(spaceID: spaceID, name: projectName)
                    projectsByName[projectName.lowercased()] = project
                }
                try store.createPrompt(projectID: project.id, title: title, body: body, color: color)
                n += 1
            }
        }
        return n
    }

    static func safe(_ s: String) -> String {
        s.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
    }
}
