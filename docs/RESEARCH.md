# Reprise: research, ICP and competitive analysis

*November 2026. Inputs: web research (vendor sites, App Store listings, GitHub, Apple Community threads, comparison articles), the agent ecosystem's on-disk formats (Claude Code / Codex), and a scan of a real power user's local agent history.*

---

## 1. The problem, stated precisely

High-leverage agent work runs on long, carefully written prompts: role preambles, task specs, review checklists, research briefs. Three things are true for heavy agent users:

1. **The same prompts recur with small variations.** Same skeleton, different file, repo, goal or tone.
2. **Prompts are long.** 2–50k characters is normal. Pasted context makes them longer.
3. **Prompts are used inside terminals and agents**, not in the tool where they're stored.

Every current solution breaks at least one of these.

### Evidence from a real power user's machine
Running Reprise's *Harvest* against one heavy user's `~/.claude/history.jsonl` (1,982 entries) and `~/.codex/history.jsonl` (1,075 entries):

| Retyped | Size | Source |
|---|---|---|
| ×32 | 49,507 chars | Codex |
| ×25 | 2,908 chars | Claude Code |
| ×18 | 1,007 chars | Claude Code + Codex |
| ×16 | 13,130 chars | Codex |
| ×9 | 12,561 chars | Codex |

The top item alone is about **1.6 million characters of re-pasting**. Most of the top patterns open with the same role preamble before the task-specific part, which is exactly the *include/preamble* use case. This finding drove three features: **Harvest**, **includes** (`{{> Role}}`), and **templates with remembered values**.

### Evidence from Apple Notes users
Apple Community threads report notes becoming unusable past about 100–130k characters ("Updated to 18.1.1, but large notes (>130,000 characters) still slow down, it is impossible to work"). The lag predates iOS 18 (a 2023 macOS thread reports splitting notes to reduce lag). The root cause is architectural: rich-text layout of the entire note plus iCloud sync of a single large object. This drove the **TextKit 2 viewport editor + SQLite store** decision and the benchmark target of "a 4 MB prompt must feel like 4 KB".
Sources: [Apple Community 255765334](https://discussions.apple.com/thread/255765334), [Apple Community 254559867](https://origin-discussions2-us-dr-prz.apple.com/thread/254559867).

---

## 2. ICP

**Primary: the agent-native builder.** A senior or staff engineer, indie hacker or technical founder on macOS who runs 2–6 coding agents daily (Claude Code, Codex CLI, Cursor, OpenCode, Pi, Gemini CLI), often in parallel through tmux, herdr or Ghostty splits.

| Trait | Implication for the product |
|---|---|
| Lives in the terminal; keyboard-first | Global hotkey, zero-mouse flow, paste into the frontmost app, CLI |
| Writes long structured prompts (XML tags, markdown, role preambles) | Real editor with prompt-aware highlighting; includes |
| Uses several agents | Agent-agnostic output; MCP + Claude and Codex slash commands |
| Taste-driven: adopts Ghostty, Raycast, Linear, herdr | Native, fast, beautiful; looks like it belongs on macOS 26 |
| Privacy-aware, distrusts SaaS for IP-laden prompts | Local-first, no account, no telemetry, open source |
| Shares tooling publicly on X / GitHub | Screenshot-worthy UI, a shareable `cast` command, Harvest stats |

**Secondary:** prompt engineers, AI-heavy PMs and researchers, and content teams using ChatGPT or Claude desktop. They are served by the same app (Quick Panel works in any text field) without being the design center.

**Jobs to be done**
1. *"When I start a task, give me my best prompt for it in under 2 seconds, with the details filled in."*
2. *"When I write a great prompt, let me keep it without breaking flow."* (MCP `save_prompt`, ⌘N, CLI `add`)
3. *"Keep hundreds of prompts organized by client and project, and let me find any of them instantly."*
4. *"Let my agents use my library directly."* (MCP / slash commands)

---

## 3. Competitive landscape (audited)

| Product | Type | Strengths | Gaps we exploit |
|---|---|---|---|
| **Apple Notes** | General notes | Free, already there, iCloud | Lags on large notes; no variables; no agent integration; rich text mangles prompts |
| **Raycast snippets / AI commands** | Launcher | Great hotkey UX, huge user base | Snippets aren't a library: weak organization, no long-form editor, no includes; Pro paywall for AI features |
| **Prompttly** ([site](https://prompttly.com/)) | Mac + web + Chrome, freemium | Syncs to `~/.claude/skills` and `~/.codex/skills`; hotkey palette | Closed source, account and cloud model, metered "AI optimizations" and MCP calls; skills-focused rather than a prompt editor |
| **Promptzy** ([site](https://promptzy.app/)) | Mac app, $5 Pro | Plain `.md` storage, sync to Claude, Cursor, OpenClaw | Free tier capped at 10 prompts / 1 collection; sync is paid; small-library focus |
| **PromptBox / Promptler / PromptPad** (App Store) | Mac / iOS apps | Templates with `{{vars}}`, iCloud | Generic "prompt manager" positioning; no agent wiring; tiny review bases |
| **TextExpander / Espanso** | Text expansion | Mature expansion and fill-ins | Built for short snippets; no long-form editor; no agent wiring |
| **Browser extensions** (AIPRM, Prompt Genius, Toolbox for Claude…) | Chrome | Live inside chat UIs | Useless in terminals; reported data-loss complaints (Prompt Genius ~2.8★) |
| **OSS Swift prompt managers** (PromptPanel, PromptStash, promptbox, ghuey-prompt) | GitHub | Native, some use GRDB and hotkeys | Low traction (0–few ★); none combine editor + templates + MCP + Harvest + design |
| **Version-controlled prompt files** (CLAUDE.md, AGENTS.md, `.claude/commands`) | DIY | Git, portable | Per-repo; no search across projects; no fill-in UX; no organization |

Sources: [Prompttly comparison](https://prompttly.com/resources/best-prompt-organizer-mac), [Promptzy roundup](https://promptzy.app/blog/best-ai-prompt-managers-mac-2026), [Promptzy pricing](https://promptzy.app/), [Promptler](https://apps.apple.com/us/app/promptler-ai-prompt-manager/id6670718658), [PromptPad](https://apps.apple.com/us/app/promptpad-ai-prompt-manager/id6748589385), [Chrome extension roundup](https://prompt-architects.com/blog/11-best-prompt-manager-2026), [PromptPanel](https://github.com/qilaidev/PromptPanel), [PromptStash](https://github.com/karmanverma/PromptStash), [promptbox](https://github.com/DouglasPrado/promptbox), [Claude Code slash commands docs](https://code.claude.com/docs/en/slash-commands).

### Diagnosis
The market is **crowded and undifferentiated at the bottom**: dozens of "prompt managers" with `{{variables}}`, folders and a hotkey. Nobody owns the intersection of:

1. **Agent-native wiring**: MCP (read *and write*), slash-command publishing, a CLI.
2. **Serious long-form editing**: multi-MB prompts, prompt-aware highlighting, versions.
3. **Taste**: a first-class macOS 26 app with a design of its own, rather than a utility window or a notes app in costume.
4. **Open source + local-first**, which this ICP strongly prefers for prompts containing IP.
5. **A built-in "aha" moment** (Harvest) that proves value on first launch using the user's own data.

Each competitor has one or two of these. Reprise ships all five on day one.

---

## 4. Positioning

**Category:** a *prompt studio* for agent-native developers (not a "prompt manager").

**One-liner:** *Reprise: prompts you play again.*

**Elevator pitch:** Reprise is a native, open-source Mac app where your best prompts live as templates. ⌥⌘P from any terminal, fill in the blanks, and it's pasted into Claude Code or Codex. Your agents can search and save to it over MCP. It handles 4 MB prompts without a stutter, and it looks like Apple built it.

**Why the name:** a *reprise* is a returning musical theme with variations, which is literally a template. It's short, pronounceable worldwide, unclaimed in the dev-tools and AI space (GitHub shows no conflicting dev tool; "cantrip" and "rote" were rejected because active projects in the agent/notes space already use them), and it carries a visual identity: the musical **repeat sign** (𝄇), which became the logo.

**Moat strategy ("monopoly" path)**
1. **Own the standard.** The template syntax (`{{x = default}}`, `{{x: a | b}}`, `{{> include}}`) is plain text and documented. If shared prompt packs adopt it, Reprise becomes the reference renderer, and the CLI and MCP make it usable anywhere.
2. **Data gravity without lock-in.** People move their whole library in through Harvest and Markdown import; one-click Markdown export builds trust.
3. **Distribution through agents.** Every `claude mcp add reprise` install puts Reprise inside the user's daily loop. `save_prompt` means agents *grow* the library.
4. **Community packs.** (Roadmap) shareable `.reprise` packs from tastemakers: "Staff Engineer review kit", "Security audit kit". Each pack is a growth loop.
5. **Open source.** Competitors charge $5–$10/month; free plus MIT plus better makes the paid closed apps' pitch hard to defend.

---

## 5. Feature set: research → decision

| Research signal | Feature shipped |
|---|---|
| Notes lags on 100k+ char notes | TextKit 2 editor, incremental highlighting, chunked first paint, SQLite store; benchmarked |
| Same preamble re-pasted dozens of times | `{{> include}}` composition + Harvest |
| "Only certain details change" | Templates: defaults, choices, built-ins, remembered values, live preview |
| Organize by projects and areas, named and colored | Spaces → Projects → Prompts; required names; OKLCH random color pool + picker + "shades near this one" |
| Prompts are used in terminals | Global hotkey glass panel, paste into frontmost app, CLI `cast -c` |
| Agents should reach the library | MCP (prompts + tools incl. `save_prompt`), Claude/Codex slash-command publishing |
| Images and links pasted into agents | Attachments copied into the library; absolute paths and URLs appended on use |
| Rich-text mangling (smart quotes) | Plain-text storage, smart substitutions off, prompt-aware highlighting (XML tags) |
| Fear of data loss (extension reviews) | Autosave, 50-version history, WAL, Markdown export |
| Taste-driven users; "must not feel vibe-coded or like a notes app" | Three structurally different designs (Console, Board, Studio), dark by default, one Copy action (see section 6) |

### Deliberately *not* built (yet)
- **Cloud accounts / sync service.** Conflicts with local-first; `REPRISE_HOME` on an iCloud folder covers the simple case.
- **In-app LLM "prompt optimizer".** Commodity and metered by competitors; agents can already do this through MCP.
- **Prompt marketplace.** Comes after community packs prove demand.

---

## 6. Design research: why v0.1 looked generic, and what replaced it

v0.1 shipped with three "looks" (Liquid, Tinted, Ink): glass panes over a soft color aura that took on each prompt's color, colored project pills, and a dark monospaced mode. It worked, and it photographed well. But it read as generic, and the reasons can be named.

### What makes an app look vibe-coded
Sources: [Linear, "A calmer interface for a product in motion" (2026)](https://linear.app/now/behind-the-latest-design-refresh), [Linear, "How we redesigned the Linear UI"](https://linear.app/now/how-we-redesigned-the-linear-ui), [the "AI purple problem"](https://dev.to/jaainil/ai-purple-problem-make-your-ui-unmistakable-3ono), [Why every AI-built website looks the same](https://dev.to/alanwest/why-every-ai-built-website-looks-the-same-blame-tailwinds-indigo-500-3h2p), [How to fix the AI-generated look](https://dev.to/alanwest/how-to-fix-the-ai-generated-look-in-your-frontend-1ahh), [Why AI-generated UIs are all the same color](https://dev.to/kenimo49/why-ai-generated-uis-are-all-the-same-color-and-the-data-to-prove-it-12oe), [iA Writer](https://ia.net/?p=261) on typography as function, plus app galleries (Mobbin, Refero) for how shipped Mac and productivity apps handle sidebars, lists and inspectors.

The tells that recur across those sources, and which v0.1 had:

| Tell | v0.1 | Now |
|---|---|---|
| Color everywhere: gradients, glows, every object tinted | Aura behind every pane; tinted glass; colored pills | One accent for what you act on; project colors are 6–8pt square keys |
| Default type, one weight, no hierarchy of voices | SF everywhere | Each design commits to a type voice (serif page, grotesk instrument, light gallery) and all metadata is a caption |
| Cards and pills as the unit of everything | Pill badges, rounded snippet rows | Index as a table of contents; hairlines; no snippets |
| Chrome competes with content | Glass on every surface | Navigation recedes (Linear's rule); the page is the brightest, calmest thing on screen |
| Costume (terminal, "hacker" mono) | Ink look | Mono only for placeholders and commands, unless the user picks it |
| Sparse, slow layouts that look like a landing page | Big empty glass | A dense margin of real apparatus beside a readable measure |

### Round one: one structure, three palettes (rejected)
The first redesign kept the three-column layout and set it like an annotated book page (Edition), with two alternates that changed only type and color (Machined, Quiet). The user's verdict: still "the usual notes app", the actions were unclear ("Use", two copy buttons and "Copy filled" all copied), and New Prompt was hard to find. The lesson: **the notes-app tell is the structure**, not the palette. A sidebar, a list and an editor read as Notes whatever the typeface.

### Round two: three structures
References for structure, not style:

- **Launchers** ([Raycast's design principles: fast, simple, delightful](https://raycast.com/blog/a-fresh-look-and-feel)): one input owns the window, results are keyboard-first, and an action bar teaches shortcuts by showing them. Raycast's write-up also notes the team built custom components because stock ones weren't keyboard-first ([technical deep dive](https://www.raycast.com/blog/a-technical-deep-dive-into-the-new-raycast)).
- **Boards** ([Linear, "A calmer interface"](https://linear.app/now/behind-the-latest-design-refresh)): the working surface stays in focus and navigation recedes; dense, monochrome, low-contrast structure.
- **Editors with inspectors and palettes** (Zed, Xcode, and the command-palette pattern surveyed in [Retool's "Designing the command palette"](https://retool.com/blog/designing-the-command-palette)): tabs for open work, ⌘P to open anything, an inspector for properties.
- **Monochrome dark systems** ([Vercel Geist](https://vercel.com/geist/terminal)): near-black ground, three grays for primary, secondary and quiet text; accents only for meaning.

Decisions:

| Problem | Fix |
|---|---|
| Notes-app skeleton | Console has no sidebar; Board has no list; Studio has no persistent list |
| Use / Copy Source / Copy filled confusion | One action, **Copy Prompt** (⌘↩), with "What gets copied" shown above it. Copy Template Source moved into the ⋯ menu. Quick Panel says "Paste" or "Copy", never both |
| New Prompt buried at the bottom of the sidebar | A filled **New Prompt** button at the top right of every design; New Project and New Space where projects and spaces are shown |
| Too many colors | One signal color per design; Board's primary is ink; project colors are small keys only |
| Light-first | Theme setting in every design, **Dark by default** |

The three designs, their tokens and rules are in [`DESIGN.md`](../DESIGN.md).
