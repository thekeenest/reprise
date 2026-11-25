---
version: 1
slug: "sources-repriseapp"
primary_target: "Sources/RepriseApp"
related_targets: []
---

# Main window (Operate)

Scope: Reprise's main window in three structures (Console, Board, Studio), plus the Quick Panel, sheets and Settings that inherit it. Visitor mode: Operate. Users write and refine long agent prompts here; retrieval lives in the Quick Panel.

## Direction contract

THESIS: A prompt library must not look like a notes app, and the notes-app tell is structural (sidebar, list, editor), not chromatic. Reprise therefore ships three designs with three different structures, each its own build, all on one library and one rule set: one primary action (Copy Prompt, ⌘↩, with the exact payload shown above it), New Prompt always in the top bar, dark by default.

OWN-WORLD: Console is cool graphite (#111113) with one coral signal (#FF7452), SF Pro, 8 pt radius. Board is near-black monochrome (#0E0F10) whose primary button is ink (white), with mint (#5EE0A8) only on blanks and templates, 10 pt tiles. Studio is warm iron (#161514) with bone ink and vermilion (#EF6A52), New York titles and small caps, the Edition's heir. Each has a Light theme; Dark is the default. No tinted glass, no gradients.

STORY: Console: type, arrow, ⌘↩. Board: see every project at once, click a tile, fill, copy, drag tiles between projects. Studio: open prompts in tabs, write, and test the template in the inspector beside the page.

FIRST VIEWPORT: Console opens on a large search field, a results column with Pinned on top, and the selected prompt's blanks, payload and Copy button. Board opens on space tabs and project columns of tiles. Studio opens on the last tabs, the page, and the Run inspector.

FORM: Three structural designs (user request, 2026-11-25: "totally different designs, not just different color palettes"). They replace the earlier palette-only variants of the Annotated Edition (challenger rw-centre-rail-reference-setting; seed:39be0b7ef1750db5), whose type and vermilion survive in Studio. Signature moves: Console's action bar, Board's run card, Studio's tabs plus Run inspector.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
