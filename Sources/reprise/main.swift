import Foundation
import RepriseCore

// reprise — the command-line half of Reprise. Same library as the app (SQLite, WAL).

let version = "0.1.0"
var args = Array(CommandLine.arguments.dropFirst())
let isTTY = isatty(STDOUT_FILENO) == 1

func color(_ s: String, _ code: String) -> String { isTTY ? "\u{1B}[\(code)m\(s)\u{1B}[0m" : s }
func dim(_ s: String) -> String { color(s, "2") }
func bold(_ s: String) -> String { color(s, "1") }
func hexColor(_ s: String, _ hex: String) -> String {
    guard isTTY else { return s }
    let c = Palette.rgb(hex)
    return "\u{1B}[38;2;\(Int(c.r * 255));\(Int(c.g * 255));\(Int(c.b * 255))m\(s)\u{1B}[0m"
}
func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(("reprise: " + msg + "\n").data(using: .utf8)!)
    exit(1)
}

func option(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    let v = args[i + 1]
    args.removeSubrange(i...(i + 1))
    return v
}
func flag(_ name: String) -> Bool {
    guard let i = args.firstIndex(of: name) else { return false }
    args.remove(at: i)
    return true
}
func readStdin() -> String {
    String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? ""
}

let help = """
\(bold("reprise")) \(version) — prompts you can play again.

\(bold("USAGE"))
  reprise ls [--project NAME]            list prompts
  reprise search QUERY…                  full-text search (FTS5, ranked)
  reprise show NAME                      print a prompt's raw source
  reprise cast NAME [--var k=v]… [-c]    render a template (asks for missing vars on a TTY)
                                          -c copies the result to the clipboard
  reprise vars NAME                      list a template's variables
  reprise add TITLE [--project NAME]     save stdin as a new prompt
  reprise harvest [--min N]              find prompts you keep retyping in Claude Code / Codex
  reprise sync                           publish "agent command" prompts as /slash commands
  reprise export DIR                     export the library as Markdown files
  reprise mcp                            run the MCP server (stdio) for Claude Code, Codex, Cursor…
  reprise path                           print the library location

\(bold("MCP"))
  claude mcp add reprise -- reprise mcp
  codex mcp add reprise -- reprise mcp

\(bold("TEMPLATE SYNTAX"))
  {{file}}  {{lang = Swift}}  {{tone: terse | friendly}}  {{@date}} {{@clipboard}}  {{> Other Prompt}}
"""

guard let command = args.first else { print(help); exit(0) }
args.removeFirst()

if command == "--version" || command == "-v" { print(version); exit(0) }
if command == "help" || command == "--help" || command == "-h" { print(help); exit(0) }

let store: Store
do {
    store = try Store()
    try Seed.installIfEmpty(store)
} catch { fail("cannot open library: \(error)") }

func findPrompt(_ name: String) -> Prompt {
    if let p = try? store.prompt(named: name) { return p }
    if let hit = try? store.summaries(scope: .all, query: name, limit: 1).first, let p = try? store.prompt(hit.id) { return p }
    fail("no prompt named \"\(name)\". Try: reprise search \(name)")
}

func projectNames() -> [ID: String] {
    Dictionary(uniqueKeysWithValues: ((try? store.projects()) ?? []).map { ($0.id, $0.name) })
}

func printRows(_ rows: [PromptSummary]) {
    let names = projectNames()
    for r in rows {
        let mark = r.isTemplate ? hexColor("◆", r.color) : hexColor("●", r.color)
        let pin = r.pinned ? " ★" : ""
        print("\(mark) \(bold(r.title))\(pin)  \(dim("\(names[r.projectID] ?? "") · \(r.slugHint)"))")
    }
    if rows.isEmpty { print(dim("nothing here yet")) }
}

extension PromptSummary {
    var slugHint: String { "\(Template.estimateTokens(length: length)) tok" }
}

func copyToClipboard(_ s: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")
    let pipe = Pipe()
    p.standardInput = pipe
    try? p.run()
    pipe.fileHandleForWriting.write(s.data(using: .utf8)!)
    pipe.fileHandleForWriting.closeFile()
    p.waitUntilExit()
}

func clipboardText() -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/pbpaste")
    let pipe = Pipe()
    p.standardOutput = pipe
    try? p.run()
    p.waitUntilExit()
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}

switch command {
case "ls", "list":
    var scope = PromptScope.all
    if let name = option("--project") {
        guard let p = try? store.projects().first(where: { $0.name.lowercased() == name.lowercased() }) else { fail("no project \"\(name)\"") }
        scope = .project(p.id)
    }
    printRows((try? store.summaries(scope: scope)) ?? [])

case "search", "find":
    let q = args.joined(separator: " ")
    guard !q.isEmpty else { fail("usage: reprise search QUERY") }
    printRows((try? store.summaries(scope: .all, query: q, limit: 50)) ?? [])

case "show", "cat":
    guard let name = args.first else { fail("usage: reprise show NAME") }
    print(findPrompt(args.joined(separator: " ")).body)
    _ = name

case "vars":
    let p = findPrompt(args.joined(separator: " "))
    for v in store.variables(p) {
        let extra = v.isChoice ? " ∈ {\(v.options.joined(separator: ", "))}" : (v.defaultValue.isEmpty ? "" : " = \(v.defaultValue)")
        print("\(bold(v.name))\(dim(extra))")
    }

case "cast", "render", "use":
    var values: [String: String] = [:]
    while let kv = option("--var") ?? option("-V") {
        let parts = kv.split(separator: "=", maxSplits: 1).map(String.init)
        values[parts[0]] = parts.count > 1 ? parts[1] : ""
    }
    let copy = flag("-c") || flag("--copy")
    let noAttachments = flag("--no-attachments")
    guard !args.isEmpty else { fail("usage: reprise cast NAME [--var k=v]") }
    let p = findPrompt(args.joined(separator: " "))
    let missing = store.variables(p).filter { values[$0.name] == nil }
    if isatty(STDIN_FILENO) == 1 {
        for v in missing {
            let hint = v.isChoice ? " [\(v.options.joined(separator: "/"))]" : (v.defaultValue.isEmpty ? "" : " [\(v.defaultValue)]")
            FileHandle.standardError.write("\(hexColor("◆", p.color)) \(v.name)\(hint): ".data(using: .utf8)!)
            values[v.name] = readLine() ?? ""
        }
    } else if missing.contains(where: { $0.defaultValue.isEmpty }) {
        let names = missing.filter { $0.defaultValue.isEmpty }.map(\.name).joined(separator: ", ")
        FileHandle.standardError.write("reprise: warning — unfilled variables: \(names)\n".data(using: .utf8)!)
    }
    let out = store.payload(p, values: values, includeAttachments: !noAttachments, clipboard: clipboardText)
    try? store.markUsed(p.id)
    if copy {
        copyToClipboard(out)
        FileHandle.standardError.write("\(hexColor("✓", p.color)) copied \(p.title) (\(Template.estimateTokens(out)) tokens)\n".data(using: .utf8)!)
    } else {
        print(out)
    }

case "add", "new":
    let projectName = option("--project")
    let title = args.joined(separator: " ")
    guard !title.isEmpty else { fail("usage: echo 'body' | reprise add TITLE [--project NAME]") }
    let body = isatty(STDIN_FILENO) == 1 ? "" : readStdin()
    do {
        var project = try store.ensureInbox()
        if let projectName {
            if let p = try store.projects().first(where: { $0.name.lowercased() == projectName.lowercased() }) { project = p }
            else { project = try store.createProject(spaceID: project.spaceID, name: projectName) }
        }
        let p = try store.createPrompt(projectID: project.id, title: title, body: body.trimmingCharacters(in: .newlines))
        print("\(hexColor("●", p.color)) saved \(bold(p.title)) → \(project.name)")
    } catch { fail("\(error)") }

case "harvest":
    let min = Int(option("--min") ?? "") ?? 80
    let found = Harvest.scan(minLength: min, limit: 25)
    if found.isEmpty { print(dim("No agent history found in ~/.claude or ~/.codex.")); exit(0) }
    print(bold("Prompts you keep retyping") + dim("  (local only — nothing leaves your Mac)\n"))
    for c in found {
        print("\(color("×\(c.count)", "33"))  \(bold(c.suggestedTitle))  \(dim("\(c.text.count) chars · \(c.sources.sorted().joined(separator: ", "))"))")
    }
    print(dim("\nOpen Reprise → Harvest to save any of these as templates."))

case "sync":
    do {
        let report = try AgentSync.sync(store: store)
        for line in report.written { print("\(color("✓", "32")) \(line)") }
        for line in report.removed { print("\(color("−", "31")) \(line)") }
        for line in report.skipped { print("\(color("!", "33")) \(line)") }
        print(dim(report.summary))
    } catch { fail("\(error)") }

case "export":
    guard let dir = args.first else { fail("usage: reprise export DIR") }
    let url = URL(fileURLWithPath: (dir as NSString).expandingTildeInPath, isDirectory: true)
    do { print("exported \(try MarkdownIO.export(store: store, to: url)) prompts → \(url.path)") } catch { fail("\(error)") }

case "path":
    print(store.root.path)

case "mcp":
    MCPServer(store: store).run()

default:
    fail("unknown command \"\(command)\". Run: reprise help")
}
