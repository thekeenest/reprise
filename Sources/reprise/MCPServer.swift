import Foundation
import RepriseCore

/// Minimal MCP server over stdio (newline-delimited JSON-RPC 2.0).
///
/// - `prompts/*`: your pinned + "agent command" prompts appear natively in any MCP client.
///   In Claude Code they become slash commands: /mcp__reprise__<slug>, with template
///   variables as arguments.
/// - `tools/*`: agents can search, render and *save* prompts — "save that as a Reprise template".
final class MCPServer {
    let store: Store
    let out = FileHandle.standardOutput

    init(store: Store) { self.store = store }

    func run() {
        while let line = readLine(strippingNewline: true) {
            guard !line.isEmpty, let data = line.data(using: .utf8),
                  let msg = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            let id = msg["id"]
            let method = msg["method"] as? String ?? ""
            let params = msg["params"] as? [String: Any] ?? [:]
            guard id != nil else { continue } // notification
            do {
                let result = try handle(method, params)
                send(["jsonrpc": "2.0", "id": id!, "result": result])
            } catch let e as RPCError {
                send(["jsonrpc": "2.0", "id": id!, "error": ["code": e.code, "message": e.message]])
            } catch {
                send(["jsonrpc": "2.0", "id": id!, "error": ["code": -32603, "message": "\(error)"]])
            }
        }
    }

    struct RPCError: Error { let code: Int; let message: String }

    func send(_ obj: [String: Any]) {
        guard var data = try? JSONSerialization.data(withJSONObject: obj, options: [.withoutEscapingSlashes]) else { return }
        data.append(0x0A)
        out.write(data)
    }

    func argKey(_ name: String) -> String { name.replacingOccurrences(of: " ", with: "_") }

    func exposedPrompts() throws -> [Prompt] {
        let all = try store.allPrompts()
        let chosen = all.filter { $0.exportCommand || $0.pinned }
        if !chosen.isEmpty { return chosen }
        return Array(all.sorted { $0.useCount > $1.useCount }.prefix(50))
    }

    func handle(_ method: String, _ params: [String: Any]) throws -> Any {
        switch method {
        case "initialize":
            let requested = params["protocolVersion"] as? String ?? "2025-06-18"
            return [
                "protocolVersion": requested,
                "capabilities": ["prompts": ["listChanged": false], "tools": ["listChanged": false]],
                "serverInfo": ["name": "reprise", "title": "Reprise", "version": version],
                "instructions": "Reprise is the user's personal prompt library. Use search_prompts to find a saved prompt before writing a long one from scratch, get_prompt to render a template, and save_prompt when the user asks to keep a prompt for later.",
            ] as [String: Any]
        case "ping":
            return [String: Any]()

        case "prompts/list":
            let prompts = try exposedPrompts().map { p -> [String: Any] in
                [
                    "name": p.slug,
                    "title": p.title,
                    "description": String(p.body.prefix(160)).replacingOccurrences(of: "\n", with: " "),
                    "arguments": store.variables(p).map { v in
                        ["name": argKey(v.name),
                         "description": v.isChoice ? "One of: \(v.options.joined(separator: ", "))" : (v.defaultValue.isEmpty ? v.name : "Default: \(v.defaultValue)"),
                         "required": v.defaultValue.isEmpty && !v.isChoice] as [String: Any]
                    },
                ]
            }
            return ["prompts": prompts]

        case "prompts/get":
            guard let name = params["name"] as? String, let p = try store.prompt(named: name) else {
                throw RPCError(code: -32602, message: "Unknown prompt")
            }
            let values = values(for: p, from: params["arguments"] as? [String: Any] ?? [:])
            try? store.markUsed(p.id)
            return [
                "description": p.title,
                "messages": [["role": "user", "content": ["type": "text", "text": store.payload(p, values: values)]]],
            ] as [String: Any]

        case "tools/list":
            return ["tools": [
                tool("search_prompts", "Full-text search the user's Reprise prompt library. Returns titles, projects and variables.",
                     ["query": ["type": "string", "description": "Search words"]], required: ["query"]),
                tool("get_prompt", "Render a saved prompt/template by name, filling its {{variables}}.",
                     ["name": ["type": "string", "description": "Prompt title or slug"],
                      "variables": ["type": "object", "description": "Variable values", "additionalProperties": ["type": "string"]]],
                     required: ["name"]),
                tool("save_prompt", "Save a new prompt into the user's Reprise library. Use {{name}} placeholders for parts that change.",
                     ["title": ["type": "string"], "body": ["type": "string"],
                      "project": ["type": "string", "description": "Project name (created if missing)"]],
                     required: ["title", "body"]),
                tool("list_projects", "List spaces and projects in the library.", [:], required: []),
            ]]

        case "tools/call":
            let name = params["name"] as? String ?? ""
            let a = params["arguments"] as? [String: Any] ?? [:]
            return ["content": [["type": "text", "text": try callTool(name, a)]], "isError": false] as [String: Any]

        default:
            throw RPCError(code: -32601, message: "Method not found: \(method)")
        }
    }

    func tool(_ name: String, _ description: String, _ props: [String: Any], required: [String]) -> [String: Any] {
        ["name": name, "description": description,
         "inputSchema": ["type": "object", "properties": props, "required": required] as [String: Any]]
    }

    func values(for p: Prompt, from raw: [String: Any]) -> [String: String] {
        var out: [String: String] = [:]
        for v in store.variables(p) {
            if let s = raw[argKey(v.name)] as? String ?? raw[v.name] as? String { out[v.name] = s }
        }
        return out
    }

    func callTool(_ name: String, _ a: [String: Any]) throws -> String {
        let projects = Dictionary(uniqueKeysWithValues: try store.projects().map { ($0.id, $0.name) })
        switch name {
        case "search_prompts":
            let hits = try store.summaries(scope: .all, query: a["query"] as? String ?? "", limit: 15)
            if hits.isEmpty { return "No matching prompts." }
            return hits.map { h in
                var line = "- \(h.title) [\(projects[h.projectID] ?? "")]"
                if h.isTemplate, let p = try? store.prompt(h.id) {
                    line += " vars: " + store.variables(p).map(\.name).joined(separator: ", ")
                }
                return line + "\n  " + String(h.snippet.prefix(140))
            }.joined(separator: "\n")
        case "get_prompt":
            guard let n = a["name"] as? String, let p = try store.prompt(named: n) else { return "No prompt with that name." }
            try? store.markUsed(p.id)
            return store.payload(p, values: values(for: p, from: a["variables"] as? [String: Any] ?? [:]))
        case "save_prompt":
            guard let title = a["title"] as? String, let body = a["body"] as? String else { return "title and body are required" }
            var project = try store.ensureInbox()
            if let pn = a["project"] as? String, !pn.isEmpty {
                if let found = try store.projects().first(where: { $0.name.lowercased() == pn.lowercased() }) { project = found }
                else { project = try store.createProject(spaceID: project.spaceID, name: pn) }
            }
            let p = try store.createPrompt(projectID: project.id, title: title, body: body)
            return "Saved \"\(p.title)\" to \(project.name). It is now available in Reprise (⌥⌘P)."
        case "list_projects":
            let spaces = try store.spaces()
            let all = try store.projects()
            return spaces.map { s in
                "\(s.name)\n" + all.filter { $0.spaceID == s.id }.map { "  - \($0.name)" }.joined(separator: "\n")
            }.joined(separator: "\n")
        default:
            throw RPCError(code: -32602, message: "Unknown tool \(name)")
        }
    }
}
