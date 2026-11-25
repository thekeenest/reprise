---
name: Reprise
description: A native Mac prompt studio in three structurally different designs, dark by default.
colors:
  # Console (the default build, Reprise.app), dark theme. Board and Studio are documented below
  # and live in Sources/RepriseApp/Theme.swift.
  ground: "#111113"
  ground-deep: "#0B0B0C"
  raised: "#18181B"
  ink: "#EDEDEF"
  slate: "#9A9AA3"
  ash: "#5C5C63"
  signal: "#FF7452"
  fill: "#FF6A45"
  on-fill: "#160B07"
  light-ground: "#F7F7F8"
  light-ink: "#18181B"
  light-signal: "#E5532F"
typography:
  title:
    fontFamily: "SF Pro Display, system-ui, sans-serif"
    fontSize: "22px"
    fontWeight: 600
    letterSpacing: "-0.014em"
  search:
    fontFamily: "SF Pro Text, system-ui, sans-serif"
    fontSize: "18px"
    fontWeight: 400
  row:
    fontFamily: "SF Pro Text, system-ui, sans-serif"
    fontSize: "13.5px"
    fontWeight: 400
  body:
    fontFamily: "SF Pro Text, system-ui, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.5
  caption:
    fontFamily: "SF Pro Text, system-ui, sans-serif"
    fontSize: "11.5px"
    fontWeight: 500
  placeholder:
    fontFamily: "SF Mono, ui-monospace, monospace"
    fontSize: "13px"
    fontWeight: 600
rounded:
  control: "8px"
  card: "14px"
spacing:
  row: "7px"
  gutter: "20px"
  panel: "28px"
  bar: "60px"
components:
  button-primary:
    backgroundColor: "{colors.fill}"
    textColor: "{colors.on-fill}"
    rounded: "{rounded.control}"
    height: "30px"
  button-copy:
    backgroundColor: "{colors.fill}"
    textColor: "{colors.on-fill}"
    rounded: "{rounded.control}"
    height: "38px"
  button-ghost:
    backgroundColor: "{colors.ground}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    height: "28px"
  field:
    backgroundColor: "{colors.raised}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "7px 10px"
  result-row-selected:
    backgroundColor: "{colors.raised}"
    textColor: "{colors.ink}"
    typography: "{typography.row}"
    rounded: "{rounded.control}"
---

# Design System: Reprise

## Overview

Reprise is where agent-native builders keep the prompts they run again and again. The design problem was that a prompt library drifts toward the notes-app skeleton (sidebar, list, editor), and that skeleton reads as "another notes app" however it's styled. Recoloring it didn't help: three palettes on one layout still looked like one notes app.

So Reprise ships **three designs with three different structures**. Each is its own build, and all three share one library:

| Design | Build | Structure | Reference class |
|---|---|---|---|
| **Console** (default) | `Reprise.app` | Launcher-first: one search field, results, a run panel, an action bar. No sidebar. | Raycast, Superhuman |
| **Board** | `Reprise Board.app` | Spatial: spaces as tabs, projects as columns, prompts as tiles. Run and edit in focused cards over the board. | Linear's board view |
| **Studio** | `Reprise Studio.app` | Editor-first: prompts in tabs, the library as a ⌘P palette, a run inspector beside the page. | Zed, iA Writer |

Three rules hold in every design:

1. **One way out.** The only primary action is **Copy Prompt** (⌘↩): blanks filled, includes expanded, file paths appended. "Copy template source" is a secondary menu item, never a toolbar button.
2. **New Prompt is always visible.** It is the filled button at the top right of every design. New Project and New Space live where projects and spaces are shown.
3. **Dark by default.** Theme is a setting (Dark, Light, Match System) in every design. There is no tinted glass.

## Colors

Each design has one ground ramp (ground, deep, raised), one ink ramp (ink, slate, ash) and one signal color. The signal appears only on blanks, the caret, the primary button and the selected tab. Project colors are 6–8pt square keys and never tint a surface.

| Role | Console | Board | Studio |
|---|---|---|---|
| ground (dark / light) | `#111113` / `#F7F7F8` | `#0E0F10` / `#FBFBFA` | `#161514` / `#F3F1EB` |
| deep | `#0B0B0C` / `#EEEEF0` | `#08090A` / `#F2F2F0` | `#0F0E0D` / `#EAE7DF` |
| raised (fields, tiles, cards) | `#18181B` / `#FFFFFF` | `#161719` / `#FFFFFF` | `#1D1C1A` / `#FBFAF6` |
| ink | `#EDEDEF` / `#18181B` | `#F2F3F3` / `#141516` | `#ECE9E1` / `#1B1A18` |
| slate | `#9A9AA3` / `#5E5E66` | `#8B9097` / `#62666D` | `#A6A39B` / `#5F5D57` |
| ash | `#5C5C63` / `#A1A1AA` | `#565A60` / `#A3A7AD` | `#6F6C65` / `#98958C` |
| signal (blanks, caret) | coral `#FF7452` / `#E5532F` | mint `#5EE0A8` / `#0F8F5F` | vermilion `#EF6A52` / `#B8321F` |
| primary fill / label | coral `#FF6A45` / near-black | **ink** (white in dark, black in light) / ground | vermilion `#E85A40` / white |

Rules are ink at 8–16% alpha; washes are ink at 3.5–5%.

### Named Rules
- **One signal.** If something is colored and isn't a blank, the caret, the primary button or the selected tab, it's wrong.
- **Board's primary is ink, not color.** Its white-on-black button keeps the board monochrome; mint marks only templates and blanks.

## Typography

| Role | Console | Board | Studio |
|---|---|---|---|
| Title | SF Pro 22 semibold, −0.3 | SF Pro 24 semibold, −0.5 | New York 28 regular |
| Captions | sentence case 11.5 medium | uppercase 9.5 semibold, +0.8 | small caps 10.5 medium, +0.8 |
| Editor default | SF Pro 14 / 1.5 | SF Pro 14.5 / 1.55 | New York 15 / 1.45 |
| Blank keys | numbered caps 1 2 3 | letters A B C | serif letters A B C |

Placeholders in the editor are SF Mono semibold in the signal color, underlined. The editor's face and size can be overridden in Settings → Appearance → Editor text.

## Layout

- **Console:** 60pt command bar (search, scope menu, New Prompt), 340pt results column on the deep ground, run panel (max 760pt) on the ground, 38pt action bar with clickable shortcut hints. Edit mode replaces the run panel with the page plus a 260pt details column.
- **Board:** 54pt bar (space tabs, filter, New Prompt), then horizontally scrolling 296pt columns with 8pt-gapped tiles. Run card 820×520; edit card up to 1180pt wide.
- **Studio:** 46pt tab bar (Library ⌘P, tabs, actions, inspector toggle, New Prompt), page on a reading measure (font size × 44), 330pt inspector with Run and Details tabs, 28pt status bar.
- All windows use a hidden title bar; the traffic lights sit in a quiet strip above the bar.

## Elevation & Depth

Flat surfaces separated by hairlines and by the ground → raised step. Only the overlays float: Board's run and edit cards and Studio's palette sit on a 35–50% black scrim with one soft shadow (radius 30–40, y 14–20).

## Shapes

Console radius 8; Board 10 (tiles, columns); Studio 4. Cards and the palette use 12–14. The Studio tab marks the selected tab with a 2pt signal rule on its top edge.

## Components

### Run panel (shared)
Blank fields (key and name above a raised field; choices are a field-styled menu), then **What gets copied** (the exact clipboard payload with a token count), then **Copy Prompt ⌘↩**. Board lays it out side by side; Console and Studio stack it.

### Buttons
- **Filled:** New Prompt and Copy Prompt only.
- **Ghost:** Edit, Done, Library, scope menu. Hairline border, wash on hover.
- **Icon:** actions (⋯), inspector toggle, column +. Slate glyph, ink on hover.

### Actions menu (⋯)
Pin, Duplicate, Move to, Shuffle Color, Copy Template Source, Publish as Slash Command, Earlier Versions, Move to Trash.

### Details (shared)
Includes, Files & links, Agents (slash-command publishing), Record. Shown in Console's edit mode, in Board's edit card, and in Studio's Details tab.

## Do's and Don'ts

### Do:
- Keep one filled button per surface region, and name it by what it does.
- Show the exact output before the copy.
- Keep New Prompt in the top bar of every design.
- Check every change in all three designs and in both Dark and Light.

### Don't:
- Don't reintroduce the sidebar-list-editor skeleton into Console or Board.
- Don't put two copy-like buttons next to each other.
- Don't add gradients, glows, tinted glass, side stripes, or eyebrow labels.
- Don't color surfaces with project colors.
- Don't make Light the default.
