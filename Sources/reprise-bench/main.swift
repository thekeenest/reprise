// swift run -c release reprise-bench
// Correctness checks + the "Apple Notes test": does Reprise stay instant with a huge library?
import Foundation
import RepriseCore

var failures = 0
func check(_ ok: Bool, _ what: String) { print(ok ? "  ✓ \(what)" : "  ✗ \(what)"); if !ok { failures += 1 } }
func ms(_ t: Date) -> Double { Date().timeIntervalSince(t) * 1000 }

print("Template engine")
let vars = Template.variables(in: "Fix {{file}} in {{lang = Swift}} {{tone: terse | warm}} {{file}}")
check(vars.map(\.name) == ["file", "lang", "tone"], "variables, de-duplicated in order")
check(vars[2].options == ["terse", "warm"] && vars[2].defaultValue == "terse", "choices default to first option")
check(Template.render(#"Hi {{name}}, {{lang = Swift}}. \{{x}}"#, .init(values: ["name": "Ada"])) == "Hi Ada, Swift. {{x}}", "render + defaults + escape")
let lib = ["Role": "You are {{who = an expert}}.", "Loop": "{{> Loop}}x"]
let ctx = Template.Context(resolve: { lib[$0] })
check(Template.render("{{> Role}} Do it", ctx) == "You are an expert. Do it", "includes compose prompts")
check(Template.render("{{> Loop}}", ctx).hasSuffix("x"), "include cycles terminate")
check(!Template.hasPlaceholders("const t = {{ a: 1 }}; <p>{{ user.name() }}</p>"), "code braces are not placeholders")
check((0..<1000).allSatisfy { _ in Palette.random().count == 7 }, "random shades are valid hex")

let root = FileManager.default.temporaryDirectory.appendingPathComponent("reprise-bench-\(UUID().uuidString)")
defer { try? FileManager.default.removeItem(at: root) }
let store = try Store(root: root)
let inbox = try store.ensureInbox()

print("Store")
let a = try store.createPrompt(projectID: inbox.id, title: "Hunt a bug", body: "Reproduce {{symptom}} first")
let b = try store.createPrompt(projectID: inbox.id, title: "Hunt a bug", body: "second")
check(a.slug != b.slug, "unique slugs")
check(try store.summaries(scope: .all, query: "repro").first?.id == a.id, "prefix full-text search")
try store.saveBody(a.id, body: "totally different words")
check(try store.summaries(scope: .all, query: "repro").isEmpty, "FTS index follows edits")
try store.snapshot(a.id); try store.saveBody(a.id, body: "v2"); try store.snapshot(a.id); try store.snapshot(a.id)
check(try store.versions(a.id).map(\.body) == ["v2", "totally different words"], "version history (deduplicated)")

print("Agent export")
let multi2 = try store.createPrompt(projectID: inbox.id, title: "Review", body: "Review {{file}} for {{focus: bugs | perf}}")
let cmd = AgentSync.command(for: multi2, store: store)
check(cmd.text.contains("Review $1 for $2") && cmd.hint == "[file] [bugs|perf]", "variables → positional args + argument-hint")
let single = try store.createPrompt(projectID: inbox.id, title: "Explain", body: "Explain {{topic}}")
check(AgentSync.command(for: single, store: store).text.contains("Explain $ARGUMENTS"), "single variable → $ARGUMENTS")

let n = Int(CommandLine.arguments.dropFirst().first ?? "") ?? 50_000
print("Scale — \(n.formatted()) prompts + one 4 MB prompt")
let words = ["agent", "refactor", "migration", "latency", "postgres", "swift", "review", "deploy", "kernel", "token", "context", "cache"]
var t = Date()
try store.db.transaction {
    for i in 0..<n {
        var body = ""
        for _ in 0..<150 { body += words.randomElement()! + " " }
        try store.createPrompt(projectID: inbox.id, title: "Prompt \(i)", body: body + "needle\(i)")
    }
}
let insert = ms(t)
let big = String(repeating: "A very large prompt line with a {{variable}} and **markdown** inside it. ", count: 56_000)
let bp = try store.createPrompt(projectID: inbox.id, title: "Huge", body: big)

t = Date(); let list = try store.summaries(scope: .all, limit: 5000); let listMS = ms(t)
t = Date(); let hit = try store.summaries(scope: .all, query: "needle\(n / 2)"); let searchMS = ms(t)
t = Date(); let multi = try store.summaries(scope: .all, query: "postgres lat", limit: 200); let multiMS = ms(t)
t = Date(); let loaded = try store.prompt(bp.id)!; let loadMS = ms(t)
t = Date(); try store.saveBody(bp.id, body: loaded.body + "x"); let saveMS = ms(t)
t = Date(); let rendered = store.render(loaded, values: ["variable": "v"]); let renderMS = ms(t)
let dbSize = ((try? FileManager.default.attributesOfItem(atPath: root.appendingPathComponent("library.sqlite").path)[.size]) as? Int ?? 0)

check(list.count == 5000, String(format: "list 5,000 rows            %7.1f ms", listMS))
check(hit.first?.title == "Prompt \(n / 2)", String(format: "exact search               %7.1f ms", searchMS))
check(!multi.isEmpty, String(format: "prefix search (200 hits)   %7.1f ms", multiMS))
check(loaded.body.utf8.count > 4_000_000, String(format: "load 4 MB prompt           %7.1f ms", loadMS))
check(saveMS < 500, String(format: "save 4 MB prompt           %7.1f ms", saveMS))
check(rendered.count > 3_000_000 && renderMS < 400, String(format: "render 4 MB template       %7.1f ms", renderMS))
print(String(format: "  · bulk insert %d prompts  %7.0f ms  (db %.0f MB)", n, insert, Double(dbSize) / 1_048_576))
check(searchMS < 50 && listMS < 250, "interactive budget (<50 ms search, <250 ms list)")

print(failures == 0 ? "\nAll checks passed." : "\n\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)
