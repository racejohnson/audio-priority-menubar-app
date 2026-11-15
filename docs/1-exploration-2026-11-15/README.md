# Audio Priority: exploration (15 Nov 2026)

Working name **Audio Priority** (the folder is renamed once Race picks a name). This folder holds the exploration only. `index.html` is a self-contained, clickable page (light and dark, no external requests); this README explains the options and records the choices. Nothing native has been built.

## What it is

A lean, private macOS menu-bar app that switches audio to Race's top-ranked connected output and input. It rebuilds the switching behaviour of camguillory/Audio-Priority-Bar (GPL-3.0, so this app is GPL-3.0 too, crediting camguillory and tobi) in Race's stack and in DayNight's design, keeping only the AirPods handling:

- Ranked lists for output (headphones above speakers) and input; Auto picks the first connected device in each.
- A device you click stays until it disconnects or a higher-ranked one connects.
- Switch back when AirPods or macOS take the output on their own. The microphone is held, so AirPods connecting never take it from the DJI mic.
- AirPods bud and case battery; one-click connect and disconnect of paired Bluetooth devices.
- Dropped: profiles, the mute hotkey, Shortcuts/App Intents, URL commands, switch notices, Jabra, the update checker.

Stack for the build: Swift package, Swift 6.2, strict concurrency, macOS 26+, no Xcode project, `LSUIElement`, `make install`, private (git clone, no update channel).

## Files

| Path | What |
|---|---|
| `index.html` | The page: panel prototype (3 directions), menu-bar glyphs, DJI symbols, app icons, names, open decisions |
| `svg/devices/` | The device glyphs used in the mock-ups (stand-ins for SF Symbols) |
| `svg/dji/` | DJI Mic Mini symbols `dji-puck`, `dji-clip`, `dji-fuzzy`, `dji-rx`, each plain and on the 18 pt grid (`-grid`) |
| `svg/menubar/` | Every glyph option in the four combos: `<option>-{desk,airpods,studio,manual}.svg` |
| `svg/app-icon/` | Every icon option: `<id>.svg` (1024), `-dark`, `-tinted`, and `<id>-small*.svg` (the 16/32 px drawing) |
| `source/` | `art.mjs` (all drawings), `template.html`, `build.mjs`, `assets/` (Race's family icons). Rebuild with `node docs/1-exploration-2026-11-15/source/build.mjs` |

## 1. Panel (all in DayNight's look: Liquid Glass popover, ~312 pt, system colours, SF Symbols)

Every direction has the output list, input list, both level sliders, AirPods battery, Bluetooth Connect/Disconnect, Auto Switch, Open at Login and Quit. In the page you can click a device to use it, drag a row (or Option-Up/Down) to re-rank it, connect the AirPods, flip Auto, and load four setups.

- **A · Cards (recommended).** DayNight's preset cards become an Output card (blue) and an Input card (violet). Each has a header badge with the device in use in the card's colour, its level slider, and its ranked list (Headphones, then Speakers; Microphones). Closest to the family; the tallest panel.
- **B · Quiet list.** Control Center's Sound module on top: two thick sliders that carry the current device's glyph and name. Below, plain ranked rows with a check on the one in use. Most native, least colour.
- **C · Tiles.** Two tiles, OUT and IN, mirror the menu-bar glyph and carry battery and level; one list at a time behind an Output | Input switch. Shortest panel, but ranking the other list takes a click.

Recommendation: **A**. It reads as DayNight's sibling, and the two coloured badges teach the in/out split that the menu-bar glyph shows.

## 2. Menu-bar glyph (shows the output and input together)

All are template images (one ink). Width is the status item's cost in the menu bar; for scale, Wi-Fi is about 17 pt and a single SF Symbol item about 18 pt. Manual mode (Auto off) adds a 2.2 pt dot top right with a clear ring (`Capsule` fills instead).

| Option | Width | What it is |
|---|---|---|
| Pair | 39 pt | Output then input, both 18 pt, 3 pt apart. Reads like two separate items |
| Divided | 43 pt | Same with a hairline between, so they never read as one device |
| Badge | 20 pt | Output at 16 pt, input as a 9 pt badge at bottom right with a clear ring |
| **Lead** (recommended) | 32 pt (18 when one device does both) | Output at 18 pt, input at 12 pt beside it. AirPods out + AirPods mic in collapses to one glyph |
| Capsule | 44 pt | Both at 12 pt inside an outlined capsule; manual mode fills the capsule |
| Stack | 10 pt (14 manual) | Output over input at 9 pt each; cheapest, hard to read |

Recommendation: **Lead**. The output is what you check most, so it stays full size; the input is readable at 12 pt; it costs less than two items; and the AirPods case gets one glyph instead of a pair of AirPods next to one AirPod. Reserve the 32 pt width in the build so the status item doesn't jump when it collapses (camguillory reserves the widest icon the same way). If the mic should read as loudly as the output, pick **Pair**.

Glyph mapping for the build: built-in speakers `laptopcomputer`, built-in mic `mic` (the menu bar shows the Mac's own mic by role, as camguillory does), Studio Display `display`, AirPods output `airpods` / `airpodspro`, AirPods input `airpod.right`, iPhone `iphone`, Wireless Mic Rx the custom DJI symbol, anything else `speaker.wave.2` or `mic`.

## 3. DJI Mic Mini symbol

macOS shows the receiver as a USB input named "Wireless Mic Rx". The symbols draw the transmitter, which is the thing Race thinks of as his mic. Drawn on the 18 pt SF Symbols grid at the weight of `airpods`, `hifispeaker`, `laptopcomputer` and `mic`, and shown at menu-bar size and in a panel row.

- **Puck (recommended).** The transmitter's near-square face (26.55 × 26.06 mm), the clip's tab on top, the mic port. Same footprint as the built-ins and survives 12 pt.
- **Clip.** Side view: the thick body (15.96 mm) with grille slots and the magnetic clip hooked over the back. Most literally "clip-on mic", but reads like a card holder at 12 pt.
- **Windscreen.** The face with its furry windscreen. The most recognisable silhouette, but only when the windscreen is on.
- **RX (optional).** The receiver (46.50 × 29.61 mm) with its USB-C plug, for a row's detail line or a settings list; too abstract for the menu bar.

References: DJI's spec page (dimensions above, read 15 Nov 2026) and memory of DJI's product renders. The page's text was readable but its photos weren't, so the silhouettes are not traced from photos. **Check them against the real transmitter before one ships.** For the build, export the chosen drawing as a custom symbol (SF Symbols app template, Regular weight; the 18 pt `currentColor` SVG is the starting point) and add it to the asset catalog.

## 4. App icon (mateusbadalotti's blue equalizer, in Race's family)

All use the family construction: 824 pt tile on 1024 (DayNight's tile path), one bold glyph, a separate heavier drawing for 16/32 px, dark and tinted renditions. Mock-ups only; the shipping icon is an Icon Composer document like DayNight's.

| Option | What it is |
|---|---|
| **Deep EQ** (recommended) | mateusbadalotti's five bars, the fourth lit (#a9d6ff → #3f8bff) with a soft glow, on a deep blue tile (#2459d6 → #0b1c55; dark #16337f → #040b22). The most direct adaptation, and it sits with DayNight, MediaKeys, Screenshot Pathname and Polaris |
| Ranked | Bars step down left to right, the first lit: the top-ranked device wins |
| In & Out | Two lit bars, ice (input) and blue (output) |
| List | Bars on their side as a ranked list with the top row picked |
| Bright | Pale tile and blue bar, closest to the original; breaks the family's deep tiles |
| Glow | Near-black tile, outlined bars, one glowing bar |

Recommendation: **Deep EQ**: recognisably the icon Race liked, made to belong in his Dock. Runner-up: **Ranked**, if the icon should say "priority" rather than just "audio". Icon Composer layers for Deep EQ: Fill (the tile gradient), group "Bars" (four dim bars at white 30%, specular off), group "Lit bar" (gradient bar, shadow 0.3), group "Glow" (opacity 1, dark 0.6, tinted 0).

## 5. Name

| Name | Slug / repo | Bundle id | Line |
|---|---|---|---|
| **Patchbay** (recommended) | `patchbay-menubar-app` | `com.racejohnson.patchbay` | The studio box where every input and output is routed; one word, audio-native, covers both directions |
| First Chair | `first-chair-menubar-app` | `com.racejohnson.first-chair` | The orchestra's top-ranked player; a good story, less obvious at a glance |
| Sound Order | `sound-order-menubar-app` | `com.racejohnson.sound-order` | Says what it does, like DayNight and MediaKeys; plain, a little dry |
| In & Out | `in-and-out-menubar-app` | `com.racejohnson.in-and-out` | Matches the glyph; awkward ampersand, and a burger chain owns the sound of it |
| Earmark | `earmark-menubar-app` | `com.racejohnson.earmark` | Earmark which device gets your ears; says nothing about the mic |
| Headliner | `headliner-menubar-app` | `com.racejohnson.headliner` | Top of the bill plays; reads as a news or events app |

Bundle ids are lowercase with hyphens, like `com.racejohnson.mediakeys-for-spotify`. No trademark search was run: the app is private.

## Open decisions

| # | Decision | Options | Recommended | Race's choice |
|---|---|---|---|---|
| 1 | Name | Patchbay · First Chair · Sound Order · In & Out · Earmark · Headliner | **Patchbay** (plain runner-up: Sound Order) | |
| 2 | Repo / folder | `<slug>-menubar-app` | **patchbay-menubar-app** | |
| 3 | Bundle id | `com.racejohnson.<slug>` | **com.racejohnson.patchbay** | |
| 4 | Panel direction | A Cards · B Quiet list · C Tiles | **A Cards** | |
| 5 | Menu-bar glyph | Pair · Divided · Badge · Lead · Capsule · Stack | **Lead** (Pair if the mic should be as loud as the output) | |
| 6 | DJI Mic Mini symbol | Puck · Clip · Windscreen (+ RX for detail lines) | **Puck** | |
| 7 | App icon | Deep EQ · Ranked · In & Out · List · Bright · Glow | **Deep EQ** | |

## Still unknown

- The DJI silhouettes are not checked against photos (see section 3).
- Whether `airpod.right` is the right input glyph for AirPods in the real SF Symbols set at 12 pt, or whether the glyph should simply collapse (Lead already does).
- How a 32 pt status item behaves when macOS hides menu-bar items on a notched display; camguillory's handling of a tucked icon is worth porting if it matters.
