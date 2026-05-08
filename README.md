# Telestrator

Screen-drawing overlay [Openplanet](https://openplanet.dev) plugin for Trackmania (2020) — telestrator-style annotation for coaching, replay analysis, and streaming racing-line explanations.
Made by **Trev_TM** ([Twitch](https://www.twitch.tv/trev_tm)) and improved by me ([keybode](https://github.com/keybode)).

## Features

- **15 drawing tools** — pen, highlighter, arrow, curved arrow, line, measurement (with px length label), bracket, rect, circle, ellipse, polygon, text, numbered marker, eraser, select
- **Solid or dashed** variants on every line-based tool
- **4 labelled palette colors** (Brake / Accel / Drift / Release) plus a custom color picker
- **Edit committed drawings** — pick the Select tool, click a mark, then drag corner / endpoint / vertex handles to reshape it (or drag the body to move)
- **World-anchored marks (optional)** — toggle "World-anchor new marks" so fresh drawings stick to a point on the track instead of the screen, sliding with the camera as you scrub a replay
- **Per-color eraser locks** so e.g. brake-zone marks survive a `Clear`
- **Optional auto-fade** — old marks decay over a configurable window
- **Undo / redo / clear** with rebindable hotkeys
- **Persistence** — drawings survive plugin reloads and game restarts

## Default hotkeys

| Action | Key |
| --- | --- |
| Toggle drawing | `F7` |
| Undo | `Z` |
| Redo | `Y` |
| Clear | `C` |

All hotkeys are configurable in Openplanet's settings dialog and can be individually disabled if they collide with your TM controls.

## Modifiers

- **Shift** — constrain to 45° (line / arrow / measurement / bracket / curved arrow) or perfect square (rect / ellipse)
- **Ctrl** — draw from center (rect / ellipse)
- **Alt + drag (Select tool)** — adjust a world-anchored mark's altitude, useful for fixing marks placed on ramps or loops
- **Enter / Escape** — close / cancel a polygon mid-build

## Install

Install via the Openplanet plugin manager in-game, or drop this folder into `OpenplanetNext/Plugins/`.

## License

See [LICENSE](LICENSE).
