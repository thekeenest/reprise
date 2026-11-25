import Foundation

/// Harvest finds the prompts you keep retyping. It reads your local agent histories
/// (Claude Code, Codex), never uploads anything, clusters duplicates, and ranks by
/// how much retyping each one costs you.
public enum Harvest {
    public struct Candidate: Identifiable, Hashable, Sendable {
        public var id: String { key }
        public var key: String
        public var text: String
        public var count: Int
        public var lastUsed: Date
        public var sources: Set<String>
        public var projects: Set<String>
        public var score: Double { Double(count) * log2(Double(max(text.count, 2))) }
        public var suggestedTitle: String { Harvest.title(for: text) }
    }

    public static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    public static func scan(minLength: Int = 80, limit: Int = 300) -> [Candidate] {
        var map: [String: Candidate] = [:]
        func add(_ raw: String, source: String, date: Date, project: String?) {
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= minLength, !text.hasPrefix("/"), !text.hasPrefix("!") else { return }
            let key = normalize(text)
            if var c = map[key] {
                c.count += 1
                c.sources.insert(source)
                if let project { c.projects.insert(project) }
                if date > c.lastUsed { c.lastUsed = date; c.text = text }
                map[key] = c
            } else {
                map[key] = Candidate(key: key, text: text, count: 1, lastUsed: date, sources: [source],
                                     projects: project.map { [$0] } ?? [])
            }
        }
        scanClaude(add)
        scanCodex(add)
        return map.values.sorted { $0.score > $1.score }.prefix(limit).map { $0 }
    }

    static func lines(_ url: URL, _ each: ([String: Any]) -> Void) {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return }
        data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) in
            var start = 0
            let bytes = buf.bindMemory(to: UInt8.self)
            for i in 0...bytes.count {
                if i == bytes.count || bytes[i] == 0x0A {
                    if i > start, let obj = try? JSONSerialization.jsonObject(with: Data(bytes[start..<i])) as? [String: Any] { each(obj) }
                    start = i + 1
                }
            }
        }
    }

    static func scanClaude(_ add: (String, String, Date, String?) -> Void) {
        let base = home.appendingPathComponent(".claude")
        let pasteCache = base.appendingPathComponent("paste-cache")
        lines(base.appendingPathComponent("history.jsonl")) { obj in
            guard var display = obj["display"] as? String else { return }
            if let pasted = obj["pastedContents"] as? [String: Any] {
                for (_, v) in pasted {
                    guard let item = v as? [String: Any], (item["type"] as? String) == "text" else { continue }
                    var content = item["content"] as? String
                    if content == nil, let hash = item["contentHash"] as? String {
                        content = try? String(contentsOf: pasteCache.appendingPathComponent("\(hash).txt"), encoding: .utf8)
                    }
                    guard let content, let id = item["id"] else { continue }
                    // Replace "[Pasted text #1 +59 lines]" with the real content.
                    if let r = display.range(of: #"\[Pasted text #\#(id)[^\]]*\]"#, options: .regularExpression) {
                        display.replaceSubrange(r, with: content)
                    } else if display.trimmingCharacters(in: .whitespaces).isEmpty {
                        display = content
                    }
                }
            }
            let ts = (obj["timestamp"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date.distantPast
            let project = (obj["project"] as? String).map { ($0 as NSString).lastPathComponent }
            add(display, "Claude Code", ts, project)
        }
    }

    static func scanCodex(_ add: (String, String, Date, String?) -> Void) {
        lines(home.appendingPathComponent(".codex/history.jsonl")) { obj in
            guard let text = obj["text"] as? String else { return }
            let ts = (obj["ts"] as? Double).map { Date(timeIntervalSince1970: $0) } ?? Date.distantPast
            add(text, "Codex", ts, nil)
        }
    }

    /// Near-duplicate key: case/whitespace-insensitive, first 600 chars.
    static func normalize(_ s: String) -> String {
        var out = ""
        var space = false
        for ch in s.lowercased().prefix(600) {
            if ch.isWhitespace || ch.isPunctuation { if !space { out.append(" "); space = true } }
            else { out.append(ch); space = false }
        }
        return out
    }

    public static func title(for text: String) -> String {
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        var t = firstLine.trimmingCharacters(in: CharacterSet(charactersIn: "#*-> \t"))
        if t.count > 60 {
            let cut = t.prefix(60)
            t = (cut.lastIndex(of: " ").map { String(cut[..<$0]) } ?? String(cut)) + "…"
        }
        return t.isEmpty ? "Harvested prompt" : t
    }
}
