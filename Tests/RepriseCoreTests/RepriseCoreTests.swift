import XCTest
@testable import RepriseCore

final class TemplateTests: XCTestCase {
    func testVariablesDefaultsChoices() {
        let vars = Template.variables(in: "Fix {{file}} in {{lang = Swift}} tone {{tone: terse | warm}} again {{file}}")
        XCTAssertEqual(vars.map(\.name), ["file", "lang", "tone"])
        XCTAssertEqual(vars[1].defaultValue, "Swift")
        XCTAssertEqual(vars[2].options, ["terse", "warm"])
        XCTAssertEqual(vars[2].defaultValue, "terse")
    }

    func testRenderFillsDefaultsAndEscapes() {
        let out = Template.render(#"Hi {{name}}, {{lang = Swift}}. Keep \{{literal}} and {{ not a var! }}"#,
                                  .init(values: ["name": "Ada"]))
        XCTAssertEqual(out, "Hi Ada, Swift. Keep {{literal}} and {{ not a var! }}")
    }

    func testIncludesAndCycleGuard() {
        let lib = ["Role": "You are {{who = an expert}}.", "Loop": "{{> Loop}}x"]
        let ctx = Template.Context(values: [:], resolve: { lib[$0] })
        XCTAssertEqual(Template.render("{{> Role}} Do {{task}}", ctx), "You are an expert. Do ")
        XCTAssertEqual(Template.variables(in: "{{> Role}} {{task}}", resolve: { lib[$0] }).map(\.name), ["who", "task"]) // first appearance, following includes
        XCTAssertTrue(Template.render("{{> Loop}}", ctx).hasSuffix("x")) // terminates
    }

    func testCodeBracesAreNotPlaceholders() {
        XCTAssertFalse(Template.hasPlaceholders("const t = {{ a: 1 }}; <div>{{ user.name() }}</div>"))
        XCTAssertTrue(Template.hasPlaceholders("{{@date}}"))
    }

    func testPaletteIsValidHex() {
        for _ in 0..<500 { XCTAssertTrue(Palette.random().range(of: #"^#[0-9A-F]{6}$"#, options: .regularExpression) != nil) }
    }

    func testSlug() { XCTAssertEqual("Review this PR — fast!".slugified, "review-this-pr-fast") }
}

final class StoreTests: XCTestCase {
    var dir: URL!
    var store: Store!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("reprise-test-\(UUID().uuidString)")
        store = try Store(root: dir)
    }
    override func tearDownWithError() throws { store = nil; try? FileManager.default.removeItem(at: dir) }

    func testCRUDSearchAndSlugs() throws {
        let inbox = try store.ensureInbox()
        let a = try store.createPrompt(projectID: inbox.id, title: "Hunt a bug", body: "Reproduce {{symptom}} first")
        let b = try store.createPrompt(projectID: inbox.id, title: "Hunt a bug", body: "second")
        XCTAssertNotEqual(a.slug, b.slug)
        XCTAssertEqual(try store.summaries(scope: .templates).map(\.id), [a.id])
        XCTAssertEqual(try store.summaries(scope: .all, query: "repro").first?.id, a.id)
        try store.saveBody(a.id, body: "totally different words")
        XCTAssertTrue(try store.summaries(scope: .all, query: "repro").isEmpty)
        XCTAssertEqual(try store.summaries(scope: .all, query: "totally").first?.id, a.id)
        try store.setFlag(a.id, trashed: true)
        XCTAssertEqual(try store.summaries(scope: .trash).count, 1)
    }

    func testVersionsKeepHistory() throws {
        let p = try store.createPrompt(projectID: try store.ensureInbox().id, title: "v", body: "one")
        try store.snapshot(p.id)
        try store.saveBody(p.id, body: "two")
        try store.snapshot(p.id)
        try store.snapshot(p.id) // no-op, unchanged
        XCTAssertEqual(try store.versions(p.id).map(\.body), ["two", "one"])
    }

    /// The Apple Notes test: 20k prompts + one 2 MB prompt. Search must stay interactive.
    func testScalePerformance() throws {
        let inbox = try store.ensureInbox()
        let words = ["agent", "refactor", "migration", "latency", "postgres", "swift", "review", "deploy", "kernel", "token"]
        let t0 = Date()
        try store.db.transaction {
            for i in 0..<20_000 {
                let body = (0..<120).map { _ in words.randomElement()! }.joined(separator: " ") + " unique\(i)"
                try store.createPrompt(projectID: inbox.id, title: "Prompt \(i)", body: body)
            }
        }
        let big = String(repeating: "A long line of a very large prompt with {{var}} inside. ", count: 38_000)
        let bp = try store.createPrompt(projectID: inbox.id, title: "Huge", body: big)
        let insert = Date().timeIntervalSince(t0)

        let t1 = Date(); let list = try store.summaries(scope: .all, limit: 5000); let listTime = Date().timeIntervalSince(t1)
        let t2 = Date(); let hits = try store.summaries(scope: .all, query: "unique1999"); let searchTime = Date().timeIntervalSince(t2)
        let t3 = Date(); _ = try store.prompt(bp.id); try store.saveBody(bp.id, body: big + "x"); let bigTime = Date().timeIntervalSince(t3)

        print(String(format: "BENCH insert20k=%.2fs list5k=%.1fms search=%.1fms load+save2MB=%.1fms",
                     insert, listTime * 1000, searchTime * 1000, bigTime * 1000))
        XCTAssertEqual(list.count, 5000)
        XCTAssertEqual(hits.first?.title, "Prompt 1999")
        XCTAssertLessThan(searchTime, 0.05)
        // Debug build on a shared CI runner; the release budget (<250 ms) is enforced by reprise-bench.
        XCTAssertLessThan(listTime, 0.6)
    }
}
