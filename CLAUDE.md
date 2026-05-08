# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Telestrator is an [Openplanet](https://openplanet.dev) plugin for Trackmania, written in AngelScript. It's a screen-drawing overlay used for coaching, replay analysis, and streaming racing-line explanations.

There is no build, lint, or test tooling — Openplanet loads `.as` source files directly at runtime. To "run" it, the folder is placed in `OpenplanetNext/Plugins/` (or zipped as `.op`) and reloaded from inside Trackmania via Openplanet's developer menu.

### Source layout

Openplanet loads `.as` files recursively from the plugin folder, so subfolders are purely organizational. There are no imports or namespaces — every global, setting, class, and function is visible across files regardless of folder. Split is by concern:

- [telestrator/main.as](telestrator/main.as) — runtime: globals, OP callbacks (`Main`, `Render`, `RenderMenu`, `OnDestroyed`, `OnDisabled`), stroke lifecycle, drawable management, canvas rendering.
- [state/settings.as](state/settings.as) — `[Setting ...]`-decorated variables (`S_BrushThickness`, `S_Dashed`, `S_HotkeyToggle`, `S_LockRed`, `S_CustomColor`, ...) auto-persisted by Openplanet.
- [ui/toolbar.as](ui/toolbar.as) — `RenderToolbar`, `RenderToolSelector`, `SetTool`, `RenderPalette`, `RenderColorSwatch`, and the floating `RenderTextInput` / `CommitTextInput` / `CloseTextInput` popup.
- [ui/input.as](ui/input.as) — `HandleHotkeys`, `HandleDrawingInput` (mouse routing into per-tool handlers), `CanDraw`, `CancelInFlight`.
- [ui/tools.as](ui/tools.as) — per-tool input handlers (`HandlePen`, `HandleArrow`, `HandleRect`, `HandleEraser`, `HandleSelect`, ...) and the `SnapEndpoint` / `ResolveBoxCorners` shape helpers.
- [ui/drawables.as](ui/drawables.as) — `Drawable` base class and subclasses (`Stroke`, `Arrow`, `LineSeg`, `RectShape`, `CircleShape`, `EllipseShape`, `TextLabel`, `NumberMarker`) plus `PaletteColor`.
- [state/persistence.as](state/persistence.as) — `SaveState` / `LoadState` and the JSON (de)serialization helpers.
- [util/helpers.as](util/helpers.as) — math (`Distance`, `PointToSegmentDistance`, `ConstrainAngle`, `ConstrainSquare`), modifier-key checks (`IsShiftDown`, `IsCtrlDown`), `IsColorLocked`, `IsInMap`, `ColorsEqual` / `ColorsEqualRGB`, and the dashed-line helper.

## API reference

Local minimal copy of the Openplanet API docs lives in [docs/](docs/), scoped to only what this plugin uses. Check there before guessing a signature; each file links back to its upstream URL on https://openplanet.dev/docs/api for re-verification. Start at [docs/README.md](docs/README.md).

**Keep `docs/` in sync with the code.** Whenever you add a new Openplanet API call (function, method, enum member) that isn't already covered, also add an entry to the appropriate file under `docs/`. Fetch the upstream page via the URL pattern above and quote the signature verbatim — don't paraphrase or invent. Add a new namespace file and link it from [docs/README.md](docs/README.md) if needed.

## Runtime model (the part that isn't obvious from one file)

Openplanet calls these top-level functions every frame; everything else hangs off them:

- `RenderMenu()` — adds the entry to Openplanet's main menu bar.
- `Render()` — the per-frame entry point. Order matters: `HandleHotkeys()` → `DrawAll()` → optional `RenderToolbar()` → `RenderTextInput()` → `HandleDrawingInput()` → `DrawCursorPreview()`. Drawables are drawn *before* input is sampled so the freshly-finished mark shows up the same frame.
- `OnDestroyed()` / `OnDisabled()` — both call `SaveState()` so the plugin doesn't lose work on reload.

Drawing happens on `UI::GetBackgroundDrawList()` so marks paint across the whole screen, beneath ImGui windows but above the game.

### In-flight state has two parallel slots

Committed marks live in `g_Drawables` (an `array<Drawable@>`). In-flight state — the thing the user is actively making — lives in one of two parallel slots:

- `g_ActiveStroke` is a *handle into* `g_Drawables` (mutated as points stream in for pen / highlighter). `UndoLast` has to null this handle if it pops the active stroke, otherwise the dangling `@`-reference points into freed memory.
- `g_Pending` lives *outside* `g_Drawables` until release; only committed via `CommitPending` if non-degenerate (≥ 4 px drag distance). This avoids ever leaving a zero-length arrow / line / rect / circle / ellipse visible.

`g_PendingAnchor` stores the original press point for shape tools, separate from the shape's own `Corner1`. Needed because Ctrl-from-center mutates `Corner1` mid-drag, so the press point can't be recovered from the shape itself.

### The `g_BlockDrawingThisFrame` flag

This is the one piece of state that's easy to misunderstand. It exists to prevent strokes from being created while the user is interacting with the toolbar window. `RenderToolbar()` clears it on entry, sets it true if the window is collapsed/closed, and `CanDraw()` consults it in `HandleDrawingInput()`. If you add new UI windows, replicate this pattern or drawing will fire through them.

### Persistence has two paths

- **Settings.** Variables decorated with `[Setting name="..."]` (e.g. `S_BrushThickness`, `S_Dashed`, `S_CustomColor`) are auto-persisted by Openplanet across sessions and surface in the Openplanet settings dialog. The `[Setting name="..." color]` attribute on a `vec4` renders a color picker. New entries are appended (never reordered), and live in [state/settings.as](state/settings.as).
- **Drawing state.** `g_CurrentColor`, `g_DrawingEnabled`, `g_CurrentTool`, `g_NextMarkerNumber`, and the entire `g_Drawables` array are persisted manually by `SaveState` / `LoadState` ([state/persistence.as](state/persistence.as)) into `state.json` under `IO::FromStorageFolder(...)`. `SaveState` is called at every committed mutation point (`FinishStroke`, `CommitPending`, eraser release, drag release, `ClearAll`, `UndoLast`, `RedoLast`) and from `OnDestroyed` / `OnDisabled`. New `Drawable` subclasses must add a `"type"` branch to both `Serialize()` and `DeserializeDrawable()`.

### Map guard

`IsInMap()` checks `GetApp().CurrentPlayground !is null`. The toolbar early-returns when not in a map and the drawing state is gated through `CanDraw()`. New features that touch game state should go through the same guard.

## Conventions

- Globals are `g_PascalCase`, settings are `S_PascalCase`, parameters are `camelCase`. Filenames are lowercase (`main.as`, not `Main.as`).
- The `Tool` enum is **append-only**. Persisted state (`state.json`) stores the current tool as `int(g_CurrentTool)`; reordering existing members would silently re-map old saves.
- Mutations to `g_Drawables` go through `StartStroke` / `AppendPointToActiveStroke` / `FinishStroke` for streaming pen/highlighter strokes, or `CommitPending` for press-drag-release shapes. Single-shot inserts (text, marker) go directly through the handler. `UndoLast` / `RedoLast` / `ClearAll` are the only paths that pop or wipe.
- After any committed mutation, call `ClearRedoStack()` *before* `SaveState()` — a new branch in undo history invalidates the redo stack. `UndoLast` and `RedoLast` are the two exceptions; they shuttle between the two stacks.
- Pen strokes only append a new point when it's at least `S_MinPointDistance` pixels from the previous one (in `AppendPointToActiveStroke`). This is what keeps the stroke arrays from exploding on slow mouse drags.
- The `Drawable.Draw` signature takes a `float alphaMul` — multiply it into `Color.w` so the auto-fade timer works. Subclasses that ignore it will not fade.

## Versioning

Bump `version` in `info.toml` when shipping changes — Openplanet's plugin manager uses it for update detection.
