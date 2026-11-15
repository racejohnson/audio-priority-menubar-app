# Audio Priority: round 4, app icon elevate (15 Nov 2026)

Five takes on the Peaks icon, simpler and bolder. Race picked Night, with a fifth level, and it now ships. `index.html` is a self-contained page (light and dark, no external requests) showing each option large, on the system shape, at every size, pixel for pixel, in the Dock and in a Finder list, and all five side by side with today's Peaks.

## How we got here

A first pass drew five elaborate options (a hardware meter, glass prisms, a stack of slabs, a capsule, a selector knob). Race rejected them all: "the app icon should stay in the style of peaks. be simple and elegant." The bar he set is Claude, Journal, Spotify, Time Machine and Tailscale: one big glyph, one or two colours, flat shapes, state by plain opacity. All five options below keep Peaks' two columns of horizontal segments (output left, input right) and are held to that bar.

Each option was drawn, critiqued against the reference icons rendered as macOS 26 shows them, refined, and judged side by side (an Opus 5.5 workflow). One option, Ramp, came out a near-twin of Bold and was replaced by Blend.

## Options

| Option | What it is |
|---|---|
| Bold (recommended before the pick) | Today's Peaks distilled: four chunky flat segments a side instead of six thin glassy ones, unlit ones dimmed, on today's blue tile, filling 60% of it |
| **Night** (Race's pick) | Bright blue output (full) and violet input on a black tile; the best read at 16 px. Picked with one more level: five segments a side, input lit three of five. The small cut stays at three a side |
| Blend | The colour moves to the tile: a blue-to-violet sweep with a plain white meter on top |
| Daylight | Blue and violet pills on a white tile, in the spirit of Time Machine |
| Duo | Three wide segments a side in blue and violet on today's navy |

## One finding

On macOS 26 the installed app's icon comes from `Assets.car`, which `build-icon.sh` makes from the full-bleed file, and the system scales that art down to every size, 16 px included. The separate small cut only feeds the `.icns` fallback. So the main art itself must read at 16 px; today's six thin rows don't. The page shows every size as macOS 26 draws it.

## Files

| Path | What |
|---|---|
| `index.html` | The page |
| `svg/<slug>/` | Each option's `<slug>.svg` (1024 master), `-small.svg` (16/32 cut) and `-bleed.svg` (full bleed), the same three files as `Icon/` |
| `source/icons/<slug>.mjs` | Each option's drawing |
| `source/shape.mjs` | The shared tile and the master/bleed/small wrappers |
| `source/render.mjs` | Writes `svg/` and review PNGs: `node render.mjs <slug> --out DIR`, or `--sheet` for all of them |
| `source/build.mjs`, `template.html`, `notes.json`, `assets/` | Build the page; `notes.json` holds the order, verdicts and decision; `assets/` holds the family icons for the Dock mock-ups and `peaks/`, the Peaks drawings as they shipped before this round |

Rebuild: `node docs/4-icon-elevate-2026-11-15/source/build.mjs` (needs `rsvg-convert`).

To ship one: copy its three files over `Icon/AppIcon.svg`, `Icon/AppIcon-small.svg` and `Icon/AppIcon-bleed.svg`, then `make icon` and `make install`.

## Decision

| # | Decision | Recommended | Race's choice |
|---|---|---|---|
| 1 | App icon | Bold | **Night, with a fifth level** (shipped to `Icon/`) |
