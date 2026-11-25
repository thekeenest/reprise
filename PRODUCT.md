# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos (native SwiftUI + AppKit, macOS 26+; Apple HIG conventions apply)

## Users

Agent-native builders: senior engineers, indie hackers and technical founders on macOS who run several coding agents a day (Claude Code, Codex CLI, Cursor, OpenCode, Pi) from a terminal. They write long, structured prompts (role preambles, task specs, review checklists, often thousands of words with XML-style sections) and reuse them with small variations.

## Product Purpose

Reprise is where those prompts are written, refined and kept, and from where they are fired into agents. **The main window exists for writing and refining prompts** (confirmed by the user): the editor is the primary surface and the library is a quiet index around it. Fast retrieval lives in the ⌥⌘P Quick Panel, the CLI and the MCP server. Success: a user moves their working prompt set out of Apple Notes and shell history, and reaches for Reprise every time they start an agent task.

## Positioning

The only prompt tool that is simultaneously (1) a serious long-form editor that stays instant at multi-megabyte sizes, (2) agent-native through an MCP server with read *and* save, slash-command publishing and a CLI, (3) built on a plain-text template language with includes, and (4) open source and local-first.

## Operating Context

- Used beside a terminal (Ghostty, iTerm, tmux, herdr) running agents; often on a laptop screen next to a terminal split.
- Prompts are pasted into terminals, so paths for images and files matter more than inline media.
- Users already know Raycast, Linear, Things and Ghostty; that is the craft bar.

## Capabilities and Constraints

- Hierarchy: Spaces → Projects → Prompts. Every space, project and prompt has a required name; projects and spaces carry a color.
- Templates: `{{var}}`, `{{var = default}}`, `{{var: a | b}}`, built-ins (`{{@date}}`, `{{@clipboard}}`…), includes (`{{> Prompt}}`).
- Attachments (images, files, links), version history (50 per prompt), Harvest from Claude Code / Codex history, Markdown import/export.
- Storage: one SQLite file (WAL + FTS5) in Application Support; no network, no accounts.
- Performance budget: search < 50 ms on 50k prompts; editing a 4 MB prompt must not stutter.

## Brand Commitments

- Name: **Reprise** ("prompts you play again"); the musical repeat sign is the mark.
- Voice: plain, exact, a little dry. No hype words.
- User's explicit design constraints: premium, clean, minimal; must **not** read as a notes app, as generic "vibe-coded" UI, as a terminal/dev costume, or as marketing gloss (gradients, glows, mesh auras, bouncy effects). Color only as tiny accents for identity or state. Must not be sparse or slow: dense enough to work in, few clicks to act.
- Liquid Glass was the user's initial direction ("approximate"); whether it survives, and where, is delegated to the designer.

## Evidence on Hand

- Benchmark results (M4, 50k prompts + one 4 MB prompt) from `swift run -c release reprise-bench`, recorded in README.
- Harvest finding on the author's machine: one prompt pasted 32 times (49,507 chars). The author's own data; publish only as aggregate numbers.
- No users, testimonials, press or download numbers exist yet; do not invent them.

## Product Principles

1. The prompt is the interface. Text gets the space, the light and the best typography; everything else recedes.
2. Speed is a feature you can feel: no spinners, no waiting, no layout jank at any library size.
3. Keyboard first, mouse welcome. Every action has a shortcut, and the shortcut is visible where it matters.
4. Plain text, local, portable. Nothing locks the user in.
5. Quiet by default, precise in detail: color and motion only where they carry meaning.
