# Audio Priority: round 3 (15 Nov 2026)

The settled choices are locked in and polished; the decided options are gone from the prototype. This round asks three things: how the device in use is marked, how rows are grabbed to re-rank them, and how devices are hidden and found again. `index.html` is a self-contained, clickable page (light and dark, no external requests). Nothing native has been built.

Settled choices and the fork-or-rebuild reasoning are in [round 2's README](../2-refine-2026-11-15/README.md).

## Files

| Path | What |
|---|---|
| `index.html` | The page: prototype, the three sets of options, the settled pieces, decisions |
| `svg/dji/` | The DJI Mic Mini glyph (Solid + clip): `dji-mic-mini.svg`, `-small` cut, `-grid` versions |
| `svg/menubar/` | `capsule-<combo>.svg` (Soft). These embed Apple's symbols as PNG masks: mock-ups, not app assets |
| `svg/app-icon/` | `peaks.svg` (1024), `-dark`, `-tinted`, and `peaks-small*.svg` (the 16/32 px drawing) |
| `source/` | `art.mjs` (drawings), `base.css`, `template.html`, `build.mjs`, `sf-export.swift`, `assets/` |

Rebuild: `swift docs/3-polish-2026-11-15/source/sf-export.swift` (only when the symbol list changes), then `node docs/3-polish-2026-11-15/source/build.mjs`.

## 1. Selected state

Output is blue (#2f6fe4, dark #4b8dff), input is violet (#6a4fd8, dark #9479f0).

| Option | What it is |
|---|---|
| Badge | Round 2: only the device in use gets a filled circle |
| Circles | Every device in a grey circle; the one in use fills with colour, as Control Center lists Wi-Fi and Bluetooth |
| Tinted row | Circles, plus a wash of the list's colour across the row in use (13% light, 26% dark). How DayNight marks its active mode |
| Tinted + check | Tinted row with a `checkmark` at the right edge |
| **Filled row** (Race's pick) | The whole row fills with colour and the text turns white, like a selected menu item |

## 2. Drag handle

Option-Up/Down and Move Up / Move Down in the row's menu work with all of them.

| Option | What it is |
|---|---|
| Hover, leading | Round 2: the rank number turns into `line.3.horizontal` under the pointer |
| Hover, trailing | `line.3.horizontal` at the right edge, only on the row under the pointer; the rank stays put |
| Always, trailing | The same handle on every row, as in an iOS list in Edit mode |
| Chevrons | `chevron.up.chevron.down` on hover, the mark on macOS pop-up buttons |
| **No handle** (Race's pick) | Nothing drawn; drag the row itself, as System Settings does |
| Edit mode | An Edit button in each heading reveals iOS handles and red `minus.circle.fill` buttons to hide; Done puts them away. Rows drag only while editing |

No system symbol exists for a dot-grid grabber (`circle.grid.2x3.fill` is missing on macOS 27.2), so none is offered.

## 3. Hiding devices

A hidden device leaves its list and is never picked automatically. It keeps its rank, so Show puts it back where it was. Hiding the device in use moves audio to the next one. Output and input are hidden separately, so the AirPods microphone can be hidden while AirPods stay an output. This is camguillory's Hide; his separate "Never Auto-Select" and "Forget" are not carried over.

**How you hide** (the right-click menu exists in every option):

| Option | What it is |
|---|---|
| Right-click only | Right-click or Control-click a row: Use, Connect/Disconnect, Move Up, Move Down, Hide |
| **⋯ on hover** (Race's pick) | An `ellipsis` button on the row under the pointer opens the same menu |
| Eye on hover | An `eye.slash` button on the row under the pointer hides it in one click |

**Where hidden devices go:**

| Option | What it is |
|---|---|
| Per list | Each list ends with an "N hidden" disclosure; open it for that list's hidden devices, dimmed, each with Show |
| **Footer link** (Race's pick) | The footer reads "1 output · 3 inputs · 1 hidden"; click the count and every hidden device appears in place |
| Hidden section | One collapsed "Hidden" heading under both lists holds every hidden device |

## 4. Polish

- Rows glide to their new place when the order changes or a device is hidden or shown; off with Reduce Motion.
- Switches are system blue, as in DayNight, not green.
- The drop line takes the list's colour.
- Long device names truncate inside the sliders; the sliders show a focus ring.
- Every control has a focus ring; menus open from the keyboard and take arrow keys; Escape closes the menu, then Edit mode, then the panel.
- The panel is a little more opaque, closer to DayNight's.
- Peaks icon: a soft top-light on each lit segment, the input channel at four of six, a hairline rim on the tile.
- DJI glyph and capsule are single settled drawings; the unused variants are gone from `art.mjs`.

## Decisions

| # | Decision | Race's choice (15 Nov 2026) |
|---|---|---|
| 1 | Selected state | **Filled row** |
| 2 | Drag handle | **No handle**: drag the row itself |
| 3 | Hide control | **⋯ on hover**, plus the right-click menu |
| 4 | Hidden devices | **Footer link** |
| 5 | Lists in the panel | **Plain** |
| 6 | AirPods glyph | **`airpods.gen4`**, for "Race’s AirPods 4"; the app picks the symbol from the connected model |
| 7 | AirPods battery | **`L 80% R 81%`**: no "Buds" label and no case level (macOS reports the case only while a bud sits in it) |

Nothing is open. Device names in the mock are the ones macOS reports on Race's Mac (15 Nov 2026): Race’s AirPods 4, Wireless Mic Rx, MacBook Pro Speakers, MacBook Pro Microphone, Race’s iPhone 17 Pro Microphone.
