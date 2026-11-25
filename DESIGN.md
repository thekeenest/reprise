---
name: Reprise
description: A native Mac prompt studio, set like a book page, in three designs.
colors:
  # Edition (default build). Machined and Quiet are documented below and live in Theme.swift.
  paper: "#F3F1EB"
  paper-deep: "#EAE7DF"
  ink: "#1B1A18"
  slate: "#5F5D57"
  ash: "#98958C"
  rubric: "#B8321F"
  iron-paper: "#151514"
  iron-paper-deep: "#1C1C1A"
  iron-ink: "#ECE9E1"
  iron-slate: "#A6A39B"
  iron-ash: "#6F6C65"
  iron-rubric: "#EF6A52"
typography:
  title:
    fontFamily: "New York, ui-serif, Georgia, serif"
    fontSize: "30px"
    fontWeight: 400
    lineHeight: 1.15
    letterSpacing: "0em"
  page:
    fontFamily: "New York, ui-serif, Georgia, serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.42
  entry:
    fontFamily: "New York, ui-serif, Georgia, serif"
    fontSize: "14.5px"
    fontWeight: 400
    lineHeight: 1.25
  apparatus:
    fontFamily: "SF Pro Text, system-ui, sans-serif"
    fontSize: "10.5px"
    fontWeight: 500
    letterSpacing: "0.09em"
  placeholder:
    fontFamily: "SF Mono, ui-monospace, monospace"
    fontSize: "13px"
    fontWeight: 600
rounded:
  none: "0px"
  panel: "14px"
spacing:
  hair: "1px"
  key: "8px"
  row: "9px"
  gutter: "16px"
  inset: "44px"
  margin: "268px"
components:
  button-use:
    backgroundColor: "{colors.rubric}"
    textColor: "#FFFFFF"
    rounded: "{rounded.panel}"
  button-copy-filled:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.rubric}"
    rounded: "{rounded.none}"
    padding: "8px 18px"
  index-row:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    typography: "{typography.entry}"
    padding: "9px 16px"
  index-row-selected:
    backgroundColor: "{colors.paper-deep}"
    textColor: "{colors.ink}"
  blank-key:
    textColor: "{colors.rubric}"
    typography: "{typography.page}"
    width: "16px"
  caption:
    textColor: "{colors.slate}"
    typography: "{typography.apparatus}"
---

# Design System: Reprise

## Overview

Reprise is where agent-native builders write and refine the prompts they use again and again. The main window is a working page, not a feed of notes. The design question was how to make a prompt library feel like an instrument and not like Apple Notes in costume. The answer is the **apparatus**: a prompt is set like a page of an annotated edition, and everything *about* the prompt (its blanks, includes, files, agent commands and record) sits in a margin beside it, the way a scholarly edition keeps notes beside the text.

Color is almost absent. The page is ink on paper. One accent marks only what you act on: the blanks, the caret, the Use button. Project colors appear as small square keys and nowhere else. No gradients, no auras, no tinted glass.

Reprise ships three **worlds** (designs) built from one token set (`Style` in `Sources/RepriseApp/Theme.swift`). Each world lends the app its type, palette, density and one signature move. Native macOS controls, menus, toolbar glass and keyboard behaviour stay the same across all three. Each world has three **looks**: light, dark, and a glass look where the desktop shows through.

| World | Thesis | Signature move | Looks |
|---|---|---|---|
| **Edition** (default) | A well-set book page | Rubric blanks keyed A B C in serif; the detent rule under the title | Bone · Iron · Vellum |
| **Machined** | A precision instrument | Numbered orange key caps; orange only on keys and the two actions (Use, Copy filled) | Aluminum · Graphite · Glass |
| **Quiet** | A gallery wall | Light 34pt titles, wide-tracked captions, ink-blue italic roman keys | Day · Night · Haze |

**Key characteristics**
- Three columns: library, index, page plus margin. The margin is 268pt and toggles with ⌥⌘0.
- The page has a fixed reading measure (about 44 characters × font size) and a 44pt inset, so long prompts read like text, not like a log.
- The index is a table of contents: one title per entry, a tabular token count, and a caption line. No snippets, no cards.
- Hairlines are exactly one device pixel.

## Colors

All colors resolve at draw time through `NSColor(name:dynamicProvider:)`, so a world or look switch repaints without relaunching.

### Primary
- **Rubric** (Edition `#B8321F` / `#EF6A52`; Machined `#E5470E` / `#FF6A2B`; Quiet `#2D5A8A` / `#86AEDB`). The only chromatic UI color. It is used for blanks in the text, blank keys, the caret, the Use button, and the "editing" state. Filled controls always use the light-mode value with white text, so contrast holds in dark looks.

### Neutral
| Role | Edition | Machined | Quiet |
|---|---|---|---|
| paper | `#F3F1EB` / `#151514` | `#EBEBE8` / `#18181A` | `#ECEAE5` / `#1A1A19` |
| paper-deep (library column) | `#EAE7DF` / `#1C1C1A` | `#E0E0DC` / `#111113` | `#E3E0DA` / `#141413` |
| ink (text) | `#1B1A18` / `#ECE9E1` | `#141416` / `#EEEEEB` | `#232321` / `#E6E4DF` |
| slate (secondary text, captions) | `#5F5D57` / `#A6A39B` | `#5A5A5F` / `#A0A0A5` | `#6B6862` / `#9D9A93` |
| ash (syntax marks, placeholders) | `#98958C` / `#6F6C65` | `#9B9BA0` / `#66666B` | `#A3A098` / `#64625D` |
| rule (ink at alpha) | 0.24 / 0.20 | 0.13 | 0.14 |
| wash (code background, ink at alpha) | 0.045 / 0.055 | 0.06 / 0.07 | 0.04 / 0.05 |

Text selection is the rubric at 16% (light) and 28% (dark). Placeholder underlines are the rubric at 35–40%.

### Named Rules
- **One accent.** If something is colored and it is not a blank, the caret, or the primary action, it is wrong.
- **Project color is a key, not a fill.** Project and prompt colors appear as 6–8pt squares. They never tint a background, a row or a glass surface.
- **Warm paper, never cream.** Paper grounds stay within a few degrees of neutral. They read as paper, not as beige.

## Typography

| Role | Edition | Machined | Quiet |
|---|---|---|---|
| Title | New York 30 regular | SF Pro 27 semibold, −0.5 | SF Pro 34 light, −0.3 |
| Page text | New York 15, 1.42 | SF Pro 14, 1.40 | SF Pro 14.5, 1.55 |
| Index entry | New York 14.5 regular | SF Pro 14.5 medium | SF Pro 14.5 regular |
| Captions | SF small caps, medium, +0.9 | SF uppercase, semibold, +1.1 | SF uppercase, regular, +1.7 |
| Placeholders | SF Mono semibold, rubric, underlined | same | same |

### Hierarchy
Title → apparatus line (place / tokens · blanks · played · saved) → page. The apparatus line sits under the title's rule. On a narrow page the measurements drop to a second line instead of wrapping mid-phrase.

### Named Rules
- **Captions carry the apparatus.** Every label about the prompt (counts, dates, section names) is a caption. Body type is only for the prompt and for values the user typed.
- **The editor's typeface is the user's.** Settings → Appearance → Text overrides the world's face (Serif, Sans, Mono) and size. The world only supplies the default.

## Layout

- Window: default 1440×880, minimum 980×580.
- Library column 200–300 (ideal 228). Index column 260–440 (ideal 310).
- Page inset 44pt. Measure = font size × 44 (× 50 for mono). The margin (268pt) shows when the page is at least 640pt wide.
- Index rows have 9pt vertical padding and a hairline inset 36pt from the leading edge, so separators start under the title, not under the color key.

## Elevation & Depth

Flat. The only depth is native: the macOS 26 toolbar glass and the window shadow. The glass looks (Vellum, Glass, Haze) put paper at 42% over a behind-window blur. The Quick Panel uses `.glassEffect` only in the glass look. In light and dark looks it is solid paper, because glass over paper turns the paper muddy.

## Shapes

| | Edition | Machined | Quiet |
|---|---|---|---|
| Control radius | 0 | 6 | 2 |
| Selection | 1px bracket on paper-deep | filled paper-deep | rubric title only |
| Blank key | serif capital letter | 16pt filled rounded number cap | italic serif lowercase roman |
| Title rule | detent: hairline with a 4pt rubric square | hairline | hairline |

## Components

### Buttons
- **Use** (toolbar): native `.glassProminent`, tinted with the world's fill accent. One per window.
- **Copy filled** (margin, ⌘↩): Edition and Quiet draw a 1px rubric outline with rubric text; Machined fills it with the accent and white text. It dims while pressed and does not scale.
- Everything else is a native toolbar button, a plain text button, or a menu.

### Inputs / Fields
Blank fields in the margin are plain text with a hairline underline that turns rubric when focused. Choice blanks (`{{a | b | c}}`) are a native menu picker.

### Navigation
The library is a native sidebar `List` with monochrome SF Symbols in slate. Space headers are captions with a "+" menu that appears on hover.

### The margin (signature component)
Sections, in order: **Blanks** (count), **Includes**, **Files & links** (+), **Agents** (publish as slash command, with the Claude Code and Codex command names), **Record** (written, edited, played, earlier versions). Each section heading is a caption over a hairline.

## Do's and Don'ts

### Do:
- Keep color to the one accent, plus project keys.
- Use captions for metadata and body type for content.
- Use native controls, and let the world change only type, palette, density and the signature move.
- Check every change in all three worlds and all three looks.

### Don't:
- Don't add gradients, gradient text, colored side stripes, glows, or tinted glass.
- Don't add eyebrow kickers or pill badges. Use a caption.
- Don't dress the app as a terminal. Mono is for placeholders and commands only, unless the user picks it.
- Don't show prompt snippets in the index. The page is one click away.
- Don't add a new color for a new state. Use ink, slate, ash or the rubric.
