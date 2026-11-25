import Foundation

/// A small, opinionated starter library that also teaches the template syntax by example.
public enum Seed {
    public static let welcome = """
    # Welcome to Reprise
    Every great prompt deserves a **reprise**. Write it once, play it again with *variations*.

    <task>
    Refactor `{{file}}` for {{goal: readability | performance | testability}}.
    Keep the public API stable and explain every trade-off in {{tone = two sentences}}.
    </task>

    ## The whole template language
    - `{{name}}` — a blank you fill in when you use the prompt
    - `{{lang = Swift}}` — a blank with a default
    - `{{tone: terse | friendly}}` — a choice (first is the default)
    - {{@date}}, {{@clipboard}} — built-ins, resolved at use time
    - {{> Staff Engineer}} — include another prompt by name

    ## Shortcuts
    1. **⌥⌘P** anywhere — Quick Panel, type, ↩ pastes into your terminal
    2. **⌘↩** — Fill & Copy this prompt
    3. **⇧⌘T** — publish as a `/slash-command` for Claude Code and Codex

    ```bash
    reprise cast "Welcome to Reprise" --var file=main.swift -c
    claude mcp add reprise -- reprise mcp
    ```

    > Paste a screenshot (⌘V) to attach it. Drop files and links too — agents get their paths.

    https://github.com/thekeenest/reprise
    """

    public static func installIfEmpty(_ store: Store) throws {
        guard try store.db.scalarInt("SELECT COUNT(*) FROM spaces") == 0 else { return }
        try store.db.transaction {
            let work = try store.createSpace(name: "Engineering", color: "#4D7CFE", icon: "hammer.fill")
            let roles = try store.createProject(spaceID: work.id, name: "Roles & Preambles", color: "#7A5CFA")
            let daily = try store.createProject(spaceID: work.id, name: "Daily Agent Work", color: "#2EC4B6")
            let research = try store.createSpace(name: "Research", color: "#F05CC8", icon: "sparkle.magnifyingglass")
            let deep = try store.createProject(spaceID: research.id, name: "Deep Dives", color: "#FF8E3C")

            let welcome = try store.createPrompt(projectID: daily.id, title: "Welcome to Reprise", body: Seed.welcome, color: "#7A5CFA")
            try store.setFlag(welcome.id, pinned: true)

            let role = try store.createPrompt(projectID: roles.id, title: "Staff Engineer", body: """
            You are a Staff-level software engineer. You think in systems, name trade-offs explicitly,
            and prefer the smallest change that fully solves the problem.

            - Read the relevant code before proposing anything.
            - State assumptions; ask only when an assumption is costly to get wrong.
            - Verify your work: run the build and the tests, and report real output.
            """, color: "#7A5CFA")
            try store.setFlag(role.id, pinned: true)

            try store.createPrompt(projectID: daily.id, title: "Review this change", body: """
            {{> Staff Engineer}}

            ## Task
            Review the current diff in `{{repo = this repository}}` with a focus on **{{focus: correctness | security | performance | readability}}**.

            For every finding give: file:line, what breaks, a concrete failing scenario, and the fix.
            Skip style nits unless they hide a bug. End with a one-line verdict: ship / fix first / rethink.
            """, color: "#2EC4B6")

            try store.createPrompt(projectID: daily.id, title: "Hunt a bug", body: """
            {{> Staff Engineer}}

            ## Symptom
            {{symptom}}

            ## What I already know
            {{context = nothing yet}}

            Reproduce it first, then find the root cause (not the first plausible one), fix it,
            and add a regression test. Show me the failing test before the fix.
            """, color: "#FF6B6B")

            let ship = try store.createPrompt(projectID: daily.id, title: "Ship a feature", body: """
            {{> Staff Engineer}}

            Implement: **{{feature}}**

            Constraints:
            - Language/stack: {{stack = match the existing code}}
            - Scope: {{scope: minimal | production-ready | with tests and docs}}

            Plan in 3–7 steps, then execute. Commit nothing until I confirm.
            Today is {{@date}}.
            """, color: "#3DDC97")
            try store.setFlag(ship.id, pinned: true)

            try store.createPrompt(projectID: deep.id, title: "Research brief", body: """
            Research **{{topic}}** for {{audience = a technical founder}}.

            1. Current state (as of {{@date}}): what is true now, with sources.
            2. The 3 strongest competing approaches and where each wins.
            3. What people complain about (forums, issues, reviews) — quote them.
            4. A recommendation with the reasoning a skeptic would accept.

            Depth: {{depth: skim | solid | exhaustive}}.
            """, color: "#FF8E3C")

            try store.createPrompt(projectID: deep.id, title: "Explain like a staff engineer", body: """
            Explain `{{concept}}` to me as a senior engineer who is new to this area.
            Start with the mental model, then the mechanism, then the sharp edges people hit in production.
            Use one concrete example. No analogies to cooking.
            """, color: "#B45CF0")
        }
    }
}
