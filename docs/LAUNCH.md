# Launching Reprise on X

Goal: **#1 GitHub Trending (Swift + overall) on launch day, 2k★ in week one, 10k★ in 60 days.** herdr hit #1 Trending with a sharp terminal-native demo, and the same audience is ours.

---

## 0. The thesis

The agent-native crowd shares tools that (a) are visibly beautiful in a 20-second clip, (b) solve a pain everyone has felt but nobody named, and (c) feel like a cheat code. Reprise has one of each:

| Lever | Asset |
|---|---|
| **Named pain** | "I've pasted the same 600-word prompt 32 times." Harvest makes everyone's own number visible, and **that number is the meme**. |
| **Visual** | Type three letters, fill two blanks, ⌘↩, and the prompt lands in Claude Code. The panel summoned over a terminal. A 4 MB prompt scrolling smoothly next to Apple Notes freezing. Three apps with three different layouts, side by side. |
| **Cheat code** | ⌥⌘P → type 3 letters → ↩ → a filled, 2k-token prompt lands in Claude Code. And `claude mcp add reprise`. |

The meme mechanic: **"Run Harvest. Post your number."** It's personal, slightly embarrassing, and everyone has one.

---

## 1. Demos to record (Screen Studio or CleanShot X, 60 fps, 2560×1600 → export 1920×1200 and 1080×1080)

Shared setup: macOS 26, wallpaper with strong color (the glass needs something to refract), Ghostty with a large font, Claude Code open, dock hidden, Do Not Disturb on. Burn in captions; 80% of X autoplays muted.

| # | Name | Length | Script (shot by shot) | Use |
|---|---|---|---|---|
| D1 | **The hero** | 22 s | Ghostty + Claude Code → ⌥⌘P → glass panel fades in → type `bug` → ↩ → fill `symptom: login returns 500` → ↩ → a 900-token prompt (role preamble included) pastes into Claude → Claude starts working. Caption: *"3 keystrokes. 900 tokens. Never typed again."* | Launch tweet #1, README GIF, PH |
| D2 | **Notes vs Reprise** | 15 s | Split screen: the same 4 MB prompt. Left: Notes with a beachball while scrolling. Right: Reprise, buttery scroll + live highlighting. Caption: *"Apple Notes: 4 MB prompt. Reprise: 4 MB prompt."* | The "why" tweet; this is the one that travels |
| D3 | **Harvest** | 18 s | Click 🌱 → list populates → zoom on "×32 · 49,507 chars" → check 5 → *Save* → they appear as templates. Caption: *"It read my Claude Code + Codex history. I'd pasted one prompt 32 times."* | Meme starter |
| D4 | **Agents use it** | 25 s | In Claude Code: "save the prompt you just ran as a Reprise template called 'Migrate to Swift 6'". Cut to Reprise: it appears live with `{{module}}` placeholders. Then type `/mcp__reprise__migrate-to-swift-6 Networking`. | MCP / agent-native crowd |
| D5 | **Finishes** | 12 s | The same prompt in Solid, then Settings → Finish → Glass: panes float off the desktop. Then Accent → Wine, then ⇧⌘L to Light. Caption: "Solid or glass. Coral or wine. Dark by default." |
| D6 | **Includes** | 15 s | Edit "Staff Engineer" preamble once → show three templates that `{{> Staff Engineer}}` update in preview. Caption: *"Write your role prompt once. Every template inherits it."* | Prompt-engineering crowd |
| D7 | **CLI** | 12 s | Terminal only: `reprise cast "review" --var focus=security -c` → `✓ copied (1,204 tokens)` → paste. | Terminal purists, HN |

Record D1, D2 and D3 first; they carry the launch.

---

## 2. Timeline

### T-10 → T-3: build in public (one post a day, no link)
- T-10: the Glass · Wine screenshot. *"Building a prompt studio for people who live in Claude Code. The page gets the room, blanks fill in beside it, ⌘↩ copies. Native, dark, open source. Shipping soon."*
- T-8: D2 (Notes vs Reprise) teaser, no name: *"Why does Apple Notes do this with a 100k-char prompt?"*
- T-6: the template syntax as an image. Ask: *"What would you add?"* (engagement + feedback)
- T-4: the icon reveal + the name story (reprise = a theme that returns, with variations).
- T-3: DM 25–40 agent-native builders (people who post about Claude Code / Codex workflows, terminal tooling, herdr, Ghostty) with a TestFlight-style zip and a personal note. Ask for honest feedback, **not** a retweet. Fix what they find.

### T-0 (Tuesday or Wednesday, 8:30am PT)
1. 08:30: launch thread (below), D1 attached to tweet 1.
2. 08:35: quote-tweet yourself with D2.
3. 08:45: Show HN: *"Show HN: Reprise – native macOS prompt library with MCP, templates and a 4 MB-capable editor"*.
4. 09:00: r/ClaudeAI, r/ChatGPTCoding, r/macapps (different copy each, lead with the problem, video first).
5. 09:00–13:00: answer **every** reply within 10 minutes. Replies drive reach more than the post itself.
6. 12:00: D3 (Harvest) as a standalone post kicking off "post your number".
7. 17:00: D4 (agents use it).
8. Product Hunt **next** Tuesday, separately, so the two launches don't split attention.

### T+1 → T+14: sustain
- Daily: one clip (D5, D6, D7, then user clips) and retweet every user's Harvest number.
- T+2: "Day 1 numbers" post (stars, countries, the funniest Harvest number). Transparency posts do well with this audience.
- T+3: ship the top 3 requested features fast and post each as *"you asked → shipped"*.
- T+7: blog post / long tweet: *"How Reprise opens a 4 MB prompt in 0.5 ms"* (TextKit 2 + FTS5 deep dive) for the engineering crowd and HN round two.
- T+10: launch **community packs** (staff-engineer review kit, security audit kit) as a second news cycle.

---

## 3. Copy

### Launch thread
**1/**
I pasted the same 600-word prompt into Codex 32 times.

So I built Reprise: a native Mac app for prompts you use again and again.

⌥⌘P from any terminal → fill the blanks → it's in Claude Code.

Open source. Native. 4.2 MB.
[D1]

**2/**
Your best prompts are templates whether you treat them that way or not:

{{file}}
{{lang = Swift}}
{{tone: terse | friendly}}
{{> Staff Engineer}}  ← includes another prompt

Write the role once. Every template inherits it.

**3/**
Apple Notes starts choking around 100k characters.

Reprise uses TextKit 2 + SQLite FTS5. With 50,000 prompts:
search: 0.1 ms
open a 4 MB prompt: 0.5 ms
save it: 53 ms
[D2]

**4/**
It's agent-native, not agent-adjacent:

claude mcp add reprise -- reprise mcp

Your agents can search, render and *save* prompts. Pinned ones become /slash commands. Templates publish to ~/.claude/commands and ~/.codex/prompts.

**5/**
My favorite part: Harvest.

It reads your Claude Code + Codex history (locally, nothing leaves your Mac) and ranks the prompts you keep retyping.

What's your number?
[D3]

**6/**
Spaces → projects → prompts, each with a name and its own color from an endless OKLCH shade pool.

Two finishes: Solid, or Liquid Glass panes floating over your desktop.
Two accents: coral or wine. Dark by default.
[D5]

**7/**
Free, MIT, no account, no telemetry.

github.com/thekeenest/reprise

If it saves you one re-paste today, a ⭐ helps a lot.

### Standalone posts (use over the first two weeks)
1. *"Run Harvest and post your number. Mine: one prompt, 32 pastes, 49,507 characters each. That's 1.6M characters of ctrl+v."* [screenshot]
2. *"The best prompt engineers I know don't write better prompts every time. They write one great prompt and reuse it 200 times."* [D6]
3. *"Apple Notes is not a prompt manager."* [D2, no other text]
4. *"Claude Code can now save its own best prompts into my library. `save_prompt` over MCP is weirdly addictive."* [D4]
5. *"Solid or Liquid Glass? I built both and can't decide. Which one would you keep?"* [two screenshots: coral / glasswine]
6. *"Things I refused to put in a prompt app: an account, a subscription, telemetry, Electron."*
7. *"Your role preamble is a dependency. Treat it like one: `{{> Staff Engineer}}`."*
8. *"⌥⌘P · bug · ↩. That's the whole UX."* [D1 cropped to 8 s]
9. *"How do you open a 4 MB prompt in 0.5 ms? Don't load it in the list. Thread 🧵"* (engineering deep dive)
10. *"v0.2: you asked for X, Y, Z. Shipped."* (repeat weekly)

### Reply templates
- *"How is this different from Raycast snippets?"* → "Raycast is a great launcher. Reprise is the library behind it: long-form editor, includes, projects, version history, MCP. Use both."
- *"Why not just a folder of .md files?"* → "Totally valid. Reprise exports to exactly that. It adds fill-in forms, search across everything, a hotkey, and MCP on top."
- *"Windows/Linux?"* → "The core and CLI are portable Swift; the app is native macOS on purpose. If this takes off, the CLI + MCP come to Linux first."

### Show HN body
> Reprise is a macOS app (Swift 6, SwiftUI, AppKit, SQLite, no dependencies, 4.2 MB) for storing and reusing long prompts for coding agents. Templates have defaults, choices and includes; a global hotkey panel fills and pastes them into your terminal; an MCP server lets Claude Code/Codex search and save prompts. I built it because Apple Notes stuttered on my 100k-character prompts and Harvest (which scans your local agent history) showed I'd pasted one prompt 32 times. Benchmarks and design notes are in the README. Happy to talk about TextKit 2, FTS5 or the template grammar.

### Reddit (r/ClaudeAI): lead with the workflow, not the app
Title: *"I scanned my Claude Code history and found I'd re-pasted the same prompt dozens of times, so I built a fix (open source)"*

---

## 4. Metrics and kill/scale rules

| Window | Target | If below → |
|---|---|---|
| Launch tweet, first 2 h | 50k impressions, 300 likes | Push D2 as the lead; it's the most universally relatable |
| Day 1 | 1k★, #1 Swift trending | Post the HN thread link to X; DM the 40 testers to share honest takes |
| Week 1 | 2k★, 50 Harvest-number replies | Run a "best Harvest number" thread and pin it |
| Day 60 | 10k★ | Community packs + brew cask + notarized build as the second wave |

Track: stars (star-history), README → release downloads, `claude mcp add reprise` mentions, Harvest-number replies (the meme's health).

## 5. Pre-flight checklist
- [ ] Notarized build (Developer ID) so the download "just works". This is the #1 friction risk.
- [ ] `brew install --cask reprise` tap
- [ ] README GIF of D1 at the top (≤ 6 MB)
- [ ] Social preview image (1280×640): Glass · Wine screenshot + wordmark
- [ ] Pinned tweet = launch thread
- [ ] GitHub topics: `prompt-engineering`, `claude-code`, `codex`, `mcp`, `macos`, `swiftui`, `macos-app`
- [ ] Issue templates + "Show us your setup" discussion
