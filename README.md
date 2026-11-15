# Audio Priority

A small macOS menu-bar app that keeps your audio on the devices you rank first. You order your outputs and your microphones once; it switches to the top one that is connected, and takes the microphone back when AirPods or macOS grab it.

Private app for one Mac: no update channel, no notarisation. macOS 26 or later.

## What it does

- **Ranked lists.** One for output (headphones always rank above speakers) and one for input. Drag a row to re-rank it.
- **Auto Switch.** Each list uses its first connected device. A device you click stays until it disconnects or a higher-ranked one connects.
- **AirPods handling.** When AirPods or macOS move the output on their own, it is switched back once; if macOS takes it again within 30 seconds it is left there, because each round trip is a gap in the sound. The microphone is always taken back, so a call never ends up on the AirPods microphone. Only if another app retakes it within a second, three times in a row, does the app pause for 30 seconds.
- **Auto off.** Devices stay where you put them. A device you connect may take the output; the microphone is still held. The capsule fills solid.
- **The capsule.** The menu-bar item shows the output device on the left and the input device on the right, using macOS's own symbols (and one custom glyph for the DJI Mic Mini, which macOS calls "Wireless Mic Rx").
- **Hide.** Hover a row and use ⋯ (or right-click) to hide a device. A hidden device is never chosen automatically and keeps its rank. The footer's "N hidden" link shows hidden devices so you can bring one back.
- **Bluetooth.** Paired devices the app has seen stay listed while they are off; click one, or Connect, to connect and use it. AirPods show each bud's battery.
- **Levels.** Two sliders set the output volume and the input level of the devices in use.

Not included, on purpose: profiles, a mute hotkey, Shortcuts, URL commands, notifications, Jabra support, an update checker.

## Install

```bash
make install
```

That builds the app, copies it to `/Applications/Audio Priority.app` and opens it. Needs Xcode's command-line tools.

On first launch the devices in use go to the top of their lists, so starting the app changes as little as possible. Open at Login is on by default; turn it off in the panel. The first time you connect or disconnect a Bluetooth device from the panel, macOS asks to let the app use Bluetooth.

## Working on it

| Command | What it does |
|---|---|
| `make test` | Runs the unit tests for the ranking and switching rules |
| `make dry-run` | Runs the app reading your real devices, but never switches, changes volume, connects, saves settings or touches the login item. It logs what it would have switched |
| `make snapshot` | Writes pictures of the panel and capsule to `.build/snapshots`, as a dry run |
| `make selftest` | Opens the real panel and drives it with synthetic clicks (a row, a drag, the slider), as a dry run. Keep your hands off for five seconds |
| `make icon` | Rebuilds `AppResources/AppIcon.icns` and `Assets.car` from `Icon/` (needs `rsvg-convert`) |

Layout:

| Path | What |
|---|---|
| `Sources/AudioPriorityCore/` | No CoreAudio here. `SwitchEngine` decides what each role should be on; `PriorityStore` keeps the ranked lists, hidden devices and switches; `DeviceGlyph` maps a device to its symbol |
| `Sources/AudioPriority/` | The app: `AudioSystem` (CoreAudio), `Bluetooth`, `AppModel`, the capsule (`StatusItemController`, `Glyphs`) and the panel (`PanelController`, `PanelView`) |
| `Tests/AudioPriorityTests/` | The rules as tests: start here to see what the app promises |
| `Icon/` | The Peaks app icon's drawings and build script |
| `docs/` | The three design rounds that led here, each a clickable page |

Settings live in the app's defaults (`defaults read com.racejohnson.audio-priority`). Deleting that domain resets the lists.

## Credits and licence

GPL-3.0; see `LICENSE`.

The switching rules, the headphone keyword list and the Control Center check are from [Audio Priority Bar](https://github.com/camguillory/Audio-Priority-Bar) by Camille Guillory, itself a continuation of [AudioPriorityBar](https://github.com/tobi/AudioPriorityBar) by Tobias Lütke, both GPL-3.0. This app is a smaller rewrite of those rules, not a fork: the code here is new, and the files that carry their logic say so. `PanelController.swift` and `LaunchAtLogin.swift` are from DayNight, by the same author as this app.

The app icon's direction came from the equalizer icon of [audio-priority](https://github.com/mateusbadalotti/audio-priority) by Mateus Badalotti; the drawing is new.
