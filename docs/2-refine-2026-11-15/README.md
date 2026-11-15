# Audio Priority: round 2 (15 Nov 2026)

Race's picks from round 1, refined. `index.html` is a self-contained, clickable page (light and dark, no external requests). Nothing native has been built.

## Settled

| Decision | Choice | Source |
|---|---|---|
| Fork or rebuild | **Lean rebuild**, not a fork | Race, 15 Nov 2026 |
| Upstream | Port camguillory's switching rules once; check upstream release notes rarely, port only a fix that's needed | Race, 15 Nov 2026 |
| Build bar | DayNight's stack is a hard requirement: Swift package, Swift 6.2, macOS 26+, no Xcode project, `make install` | Race, 15 Nov 2026 |
| Behaviour | camguillory's rules for the kept features only (below) | Race, 15 Nov 2026 |
| Panel | B · Quiet list | Race, after round 1 |
| Menu-bar glyph | Capsule, always two glyphs (the status item never changes width) | Race, after round 1 |
| Glyphs | macOS system symbols wherever one exists; one custom glyph, the DJI Mic Mini | Race, after round 1 |
| DJI glyph | A single transmitter at every size, after Race's reference drawing (`source/assets/dji-reference.png`) | Race, 15 Nov 2026 |
| Name | Audio Priority, for now | Race, 15 Nov 2026 |

### Why a rebuild and not a fork

Measured on camguillory/Audio-Priority-Bar at `b3eb6f7` (15 Nov 2026):

- About 12,000 lines of Swift plus about 6,300 lines of tests. Roughly 2,700 lines are Jabra support alone; profiles, the mute hotkey and notices run through `AppModel.swift`, `PriorityStore.swift` and `StatusItemController.swift` rather than sitting in files that can be deleted.
- It is an Xcode project targeting macOS 14 with Sparkle and KeyboardShortcuts as dependencies. Race's bar is a Swift package for macOS 26+ with none of those.
- Upstream ships about 29 commits a month and still changes the switching rules. A fork that deletes half the app can't merge that; a fork that keeps it all isn't lean.

What to port (the part that is hard-won): `PriorityStore.swift` (ranking), `shouldSwitchBack` and `holdMicrophone` in `AppModel.swift`, `CoreAudioObserver.swift`, `CoreAudioListeners.swift`, `CoreAudioProperties.swift`, `BluetoothBattery.swift`, `HeadphoneDetection.swift`, and the matching cases from `PriorityStoreTests.swift` and `SelectionBehaviorTests.swift` as the behaviour spec. GPL-3.0, crediting camguillory and tobi.

Kept rules: headphones rank above speakers; a clicked device stays until it disconnects or a higher-ranked one connects; the output switches back when AirPods or macOS take it, and is left alone if macOS takes it again straight away; the microphone is always taken back, with a 30-second pause after three fights in a row.

## Files

| Path | What |
|---|---|
| `index.html` | The page: prototype, capsule finishes, system-glyph map, DJI glyph, app icons, decisions |
| `svg/dji/` | The DJI glyph: `dji-{solid,outline,clip}.svg`, each with a `-small` cut and `-grid` versions |
| `svg/menubar/` | `capsule-{divided,clean,soft}-<combo>.svg`. These embed Apple's symbols as PNG masks: mock-ups, not app assets |
| `svg/app-icon/` | `<id>.svg` (1024), `-dark`, `-tinted`, and `<id>-small*.svg` (the 16/32 px drawing) |
| `source/` | `art.mjs` (drawings), `template.html`, `build.mjs`, `sf-export.swift`, `assets/` |

Rebuild: `swift docs/2-refine-2026-11-15/source/sf-export.swift` (only when the symbol list changes), then `node docs/2-refine-2026-11-15/source/build.mjs`.

**How the real symbols get into a web page.** `sf-export.swift` asks macOS for each SF Symbol (10 pt semibold for the capsule, 13 pt medium for rows) and saves it as a white PNG in `assets/sf.json`; the page uses them as masks. They are Apple's artwork, fine for this private mock-up; the app asks macOS for them by name.

## 1. Panel: Quiet list

Control Center-style sliders on top, each carrying the current device's glyph and name. Below, ranked rows with one system-blue check per list; no coloured badges. Click to use, drag (or Option-Up/Down) to re-rank, Connect/Disconnect on paired Bluetooth devices, AirPods bud and case battery, Auto Switch, Open at Login, Quit.

- **Plain (recommended).** Lists sit straight on the glass with hairlines between sections.
- **Inset.** Each list on a DayNight-style card.

## 2. Capsule

Output left, input right, one template image. With Auto off the capsule fills and the glyphs are cut out of it.

| Finish | Width | What it is |
|---|---|---|
| **Divided** (recommended) | 48 pt | Outline with a hairline between the halves |
| Clean | 45 pt | Outline only, halves 2 pt closer |
| Soft | 48 pt | No outline, a 16% fill; goes solid in manual |

**Input side.** Two rules for the right-hand glyph:

- **Mic when shared (recommended).** When one device does both jobs (AirPods out and AirPods mic; MacBook speakers and MacBook mic) the right side shows `mic`. Otherwise it shows the device that owns the mic. So `airpods.pro | mic` means the AirPods mic, and `airpods.pro | laptopcomputer` means AirPods out with the MacBook mic. No two setups look the same.
- **Always the device.** The right side always shows the owning device, so AirPods for both reads `airpods.pro | airpods.pro`.

## 3. System glyphs

`laptopcomputer`, `display`, `airpods.pro`, `airpods`, `airpods.max`, `headphones`, `iphone`, `hifispeaker.fill`, `homepod.fill`, `tv`, `mic`, `speaker.wave.2.fill`; panel chrome `checkmark`, `mic.fill`, `line.3.horizontal`. The page has the full device-to-symbol table. All exist on macOS 27.2.

## 4. DJI Mic Mini glyph

One transmitter, proportions measured from the front unit of Race's reference: corner radius 27% of the width, three slots centred 20% down. Two cuts each, as SF Symbols have: regular (16 pt and up) and small (wider slots, for the capsule).

- **Solid (recommended).** Filled body, three slots cut out. Closest to the reference.
- **Outline.** The same body as a 1.4 pt outline with solid slots; matches `laptopcomputer`, `display` and `mic`.
- **Solid + clip.** Solid, with a sliver of the back unit as the magnetic clip. Less like an app tile; busier at 12 pt.

For the build: export the chosen SVG as a custom symbol (SF Symbols app template) into the asset catalog. Not checked against the physical transmitter.

## 5. App icon

Five fresh drawings with an audio-level feel, none the five-bar equalizer. Family construction: 824 pt tile on 1024, one bold glyph, a heavier 16/32 px drawing, dark and tinted. Mock-ups; the shipping icon is an Icon Composer document.

| Option | What it is |
|---|---|
| **Selector** (recommended) | A source-selector knob pointing at the lit top position: pick the first available |
| Faders | Two channel strips, output blue and input ice |
| Needle | A VU meter: lit scale, needle, hub |
| Capsule | The menu-bar capsule, speaker left and mic right |
| Peaks | A segmented stereo meter; closest in spirit to mateusbadalotti's, but its own drawing |

## Open decisions

| # | Decision | Options | Recommended | Race's choice |
|---|---|---|---|---|
| 1 | Capsule finish | Divided · Clean · Soft | **Divided** | |
| 2 | Input side of the capsule | Mic when shared · Always the device | **Mic when shared** | |
| 3 | DJI Mic Mini glyph | Solid · Outline · Solid + clip | **Solid** | |
| 4 | Lists in the panel | Plain · Inset | **Plain** | |
| 5 | App icon | Selector · Faders · Needle · Capsule · Peaks | **Selector** | |

## Still unknown

- The DJI glyph follows Race's drawing, not the physical transmitter.
- How a 48 pt status item behaves when macOS hides items beside the notch.
- Which AirPods model Race uses (`airpods.pro` is assumed); the app can pick the symbol from the model.
