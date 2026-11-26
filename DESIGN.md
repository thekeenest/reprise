---
name: Reprise
description: A native Mac prompt studio. One structure, two finishes (Solid, Glass), two accents (Coral, Wine), dark by default.
colors:
  # Solid finish, dark theme, Coral accent: the default build (Reprise.app).
  ground: "#161514"
  ground-mid: "#131211"
  ground-deep: "#0F0E0D"
  raised: "#1F1E1C"
  ink: "#ECE9E1"
  slate: "#A6A39B"
  ash: "#6F6C65"
  coral: "#EF6A52"
  coral-fill: "#E85A40"
  wine: "#D0566B"
  wine-fill: "#8E2236"
  on-fill: "#FFFFFF"
  light-ground: "#F7F5F0"
  light-ink: "#1B1A18"
  light-coral: "#B8321F"
  light-wine: "#8E1F38"
typography:
  title:
    fontFamily: "New York, ui-serif, serif"
    fontSize: "28px"
    fontWeight: 400
  page:
    fontFamily: "New York, ui-serif, serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.45
  entry:
    fontFamily: "New York, ui-serif, serif"
    fontSize: "14.5px"
    fontWeight: 400
  control:
    fontFamily: "SF Pro Text, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
  caption:
    fontFamily: "SF Pro Text, system-ui, sans-serif"
    fontSize: "10.5px"
    fontWeight: 500
    letterSpacing: "0.08em"
  placeholder:
    fontFamily: "SF Mono, ui-monospace, monospace"
    fontSize: "13px"
    fontWeight: 600
rounded:
  control: "8px"
  row: "7px"
  field: "7px"
  glass-control: "999px"
  glass-pane: "18px"
spacing:
  pane-gap-glass: "8px"
  toolbar: "52px"
  sidebar: "228px"
  outline: "286px"
  list: "292px"
  inspector: "286px"
components:
  button-primary:
    backgroundColor: "{colors.coral-fill}"
    textColor: "{colors.on-fill}"
    rounded: "{rounded.control}"
    height: "30px"
  button-copy:
    backgroundColor: "{colors.coral-fill}"
    textColor: "{colors.on-fill}"
    rounded: "{rounded.control}"
    height: "32px"
  button-ghost:
    backgroundColor: "{colors.ground}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    height: "28px"
  field:
    backgroundColor: "{colors.raised}"
    textColor: "{colors.ink}"
    rounded: "{rounded.field}"
    padding: "7px 10px"
---

# Design System: Reprise

## Overview

Reprise is where agent-native builders write and keep the prompts they run again and again. After three rounds of exploration (an annotated book page, three structural apps, and the user's notes on each), the design settled on one structure built from the parts the user kept:

- From the Studio round: **the page**. It gets the most room, uses New York text, highlights placeholders in color, and shows the token count and save state on the line under the title.
- From the 0.2 Edition: **the Notes-style library**. Spaces and projects sit in a sidebar, with a list of prompts top to bottom.
- From the 0.2 margin: **a narrow inspector** that keeps the blanks first and folds everything else away.
- From the Liquid Glass reference: **a glass finish** with floating gradient panes, lit edges and capsule controls.

Three things vary between builds, and Settings switches each of them live:

| | Options | Default |
|---|---|---|
| Finish | Solid, Glass | Solid |
| Accent | Coral, Wine | Coral |
| Library | Two columns (sidebar + list), One column (outline) | Two columns |
| Theme | Dark, Light, Match System | **Dark** |

## Rules

1. **Buttons hug their content.** No button stretches to the width of the field above it. Copy Prompt is about as wide as its words.
2. **Every corner is rounded.** Solid uses 7–8 pt radii on controls and rows. Glass uses capsules for controls and 18 pt for panes. Nothing is square.
3. **One way out.** Copy Prompt (⌘↩) is the only primary action on a prompt, and it lives directly under the blanks. Copy Template Source lives in the ⋯ menu.
4. **New Prompt is always visible**, as the filled button at the top right of the page.
5. **The hierarchy belongs to the user.** Spaces and projects are created, renamed (double-click), recolored, moved and deleted in the sidebar. The place line under the title is a menu of all projects, plus New Project and New Space. Deleting a container never deletes prompts.
6. **Quiet by default.** The inspector shows the blanks. Includes, files, agents and record are folded into one line each, with a summary on the right.
7. **Main buttons respond visibly to hover.** The fill brightens, the button grows 3%, an accent glow appears beneath it, and a sheen sweeps across once. New Prompt's plus turns a quarter. Ghost buttons take an accent edge; icon buttons get a soft circle.

## Colors

Neutrals are warm iron in dark and bone in light. There is one accent at a time.

| Role | Dark | Light |
|---|---|---|
| ground (page) | `#161514` | `#F7F5F0` |
| mid (list) | `#131211` | `#F1EEE8` |
| deep (sidebar, inspector) | `#0F0E0D` | `#EAE7E0` |
| raised (fields, menus) | `#1F1E1C` | `#FFFFFF` |
| ink / slate / ash | `#ECE9E1` / `#A6A39B` / `#6F6C65` | `#1B1A18` / `#5F5D57` / `#98958C` |

| Accent | Text and highlight (dark / light) | Fill (dark / light) |
|---|---|---|
| Coral | `#EF6A52` / `#B8321F` | `#E85A40` / `#C2381F` |
| Wine | `#D0566B` / `#8E1F38` | `#8E2236` / `#7D1A2E` |

Burgundy proper (`#800020`) is below 2:1 contrast on near-black, so Wine uses it as a fill under white text and lifts it to `#D0566B` for text-level highlights on dark grounds.

Accent appears on placeholders, the caret, the selection marker, the two filled buttons, focused fields, and the title detent. Project colors appear only as 7–8 pt rounded keys.

### Glass

Glass places each region on its own pane, with an 8 pt gap between panes and from the window edge. The panes sit on the desktop, which is blurred with the HUD material and toned down.

- **Ground (dark):** the blur, a black wash at 42–62%, one accent glow (22%) from the bottom-left corner, and a faint white glow from the top-right.
- **Pane fill:** a white gradient, 6.5–8.5% at the top falling to 2–3.5% at the bottom. In light, it runs 48–62% falling to 30–42%.
- **Pane edge:** a 1 pt gradient stroke, white 22% at the top to 4% at the bottom.
- **Pane shadow:** black 28%, radius 18, y 8.
- **Fields:** a darker well (black 22%) without a border until focused.

## Typography

- **Page and titles:** New York. Titles are 28 regular; the page is 15 at 1.45 line height, with a reading measure of 44 × the font size.
- **Prompt list titles:** New York 14.5.
- **Controls:** SF Pro 12.5–13.
- **Captions:** SF small caps 10.5, tracked +0.8. Used for the place line, stats, section names and list metadata.
- **Placeholders:** SF Mono semibold in the accent, underlined. Includes are slate and underlined. Markdown markers are dimmed.

## Layout

| Region | Two columns | One column |
|---|---|---|
| Sidebar | 228 pt: search (⌘K), Library, Spaces → Projects, Trash, Harvest | 286 pt: search, filter chips (All, Pinned, Templates, Recent), Spaces → Projects → Prompts |
| List | 292 pt: scope title, count, sort; New York rows with tokens and age | — |
| Page | Toolbar (⋯, inspector toggle, New Prompt), then title, detent rule, place and stats line, and the editor | same |
| Inspector | 286 pt: Blanks, Copy Prompt, folded sections | same |

⌃⌘S hides the sidebar and ⌥⌘0 hides the inspector. When the inspector is hidden, Copy Prompt moves into the toolbar.

## Components

- **Filled button** (New Prompt, Copy Prompt, Create): accent fill and a white label. Rounded 8 pt in Solid, a capsule in Glass. Hover behaves as in rule 7.
- **Ghost button** (Harvest, Add Files, New Space…): an ink wash and a hairline that turns accent on hover.
- **Icon button** (⋯, sidebar toggles, sort, +): slate glyph; a soft circle on hover.
- **Blank field:** the name in SF 12 slate above a raised field. Choices use a field-styled menu. There are no key letters or numbers.
- **Fold:** a chevron, a small-caps title and a right-aligned summary ("1", "none", "off", "never played"), separated by hairlines.
- **Sidebar rows:** 28 pt tall, rounded 7 pt; selected rows get ink at 10%. Space rows are SF 13 semibold with a chevron, and on hover show + and ⋯. Project rows have a color key, a name and a count, accept dropped prompts, and get an accent outline while a drag is over them.
- **Selected prompt:** a 3 pt accent capsule at the left edge, plus a soft fill.

## Do's and Don'ts

### Do:
- Give the page the room. Any new chrome comes out of the sidebar or inspector widths, never the page's.
- Name both levels of the hierarchy in UI copy: "Space" and "Project".
- Check every change in Solid and Glass, Coral and Wine, Dark and Light.

### Don't:
- Don't stretch buttons to full width.
- Don't mix square and rounded corners.
- Don't show the expanded payload in a box. The page is the source of truth, and the token count lives in the stats line.
- Don't put colored key letters or numbers beside field names.
- Don't use browser-style tabs.
- Don't make Light the default.
