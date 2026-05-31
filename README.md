# Telestrator

Screen-drawing overlay [Openplanet](https://openplanet.dev) plugin for Trackmania (2020) — telestrator-style annotation for coaching, replay analysis, and streaming racing-line explanations.  
Made by **Trev_TM** ([Twitch](https://www.twitch.tv/trev_tm)) and improved by me ([keybode](https://github.com/keybode)).

## Features

- **15 drawing tools** — pen, highlighter, arrow, curved arrow, line, measurement (with px length label), bracket, rect, circle, ellipse, polygon, text, numbered marker, eraser, select
- **Solid or dashed** variants on every line-based tool
- **4 labelled palette colors** (Brake / Accel / Drift / Release) plus a custom color picker
- **Edit committed drawings** — pick the Select tool, click a mark, then drag corner / endpoint / vertex handles to reshape it (or drag the body to move)
- **Per-color eraser locks** so e.g. brake-zone marks survive a `Clear`
- **Optional auto-fade** — old marks decay over a configurable window
- **Undo / redo / clear** with rebindable hotkeys
- **Persistence** — drawings survive plugin reloads and game restarts

## Default hotkeys

| *action* 		    | *Key* |
| Toggle drawing  | `F7` 	|
| Undo 			      | `Z` 	|
| Redo 			      | `Y` 	|
| Clear 		      | `C`	  |

All hotkeys are configurable in Openplanet's settings dialog and can be individually disabled if they collide with your TM controls.

## Modifiers

- **Shift** — constrain to 45° (line / arrow / measurement / bracket / curved arrow) or perfect square (rect / ellipse)
- **Ctrl** — draw from center (rect / ellipse)
- **Delete (Select tool)** — remove the selected mark
- **Enter / Escape** — close / cancel a polygon mid-build


## License

See [LICENSE](LICENSE).
