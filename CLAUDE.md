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
- [util/projection.as](util/projection.as) — world-anchor support: `ComputeWorldAnchor` (screen → world via inverted view-projection through the car's Y plane), `GetAnchorOffset` (per-frame screen translate for an anchored drawable), `TryGetCarY`, `ProjectWorldToScreen`. Depends on the `Camera` and `VehicleState` plugins (declared in [info.toml](info.toml)).

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

### World anchoring

When `S_WorldAnchor` is on, fresh marks capture a world-space anchor at press time so they slide with the camera instead of staying glued to the screen. The anchor lives on the `Drawable` base class as three fields: `WorldAnchored` (bool), `WorldAnchor` (vec3), `ScreenAnchorAtCommit` (vec2 — the screen position the anchor projected to at commit time). Per-tool press handlers set these via `AttachWorldAnchor` in [ui/tools.as](ui/tools.as).

The renderer applies the anchor as a **rigid screen-space translate** in `DrawWithAnchor` ([telestrator/main.as](telestrator/main.as)): each frame, `offset = projectWorld(WorldAnchor) - ScreenAnchorAtCommit` is added to all stored screen coords via `Translate(offset)` / `Translate(-offset)` around `Draw`. Shape geometry is otherwise untouched — no perspective deformation. If the anchor is currently behind the camera, the drawable is skipped entirely (reappears once back in front).

Because the renderer offsets stored coords, **any input path that reads stored geometry must subtract `GetDrawableOffset(d)` from `mousePos` before hit-testing** — see `HandleSelect` / `HandleEraser` and `DrawCursorPreview`'s hover hint. Likewise, `DrawSelectionHighlight` / `DrawSelectionHandles` add the offset back to `Bounds` / `GetHandles` output.

Inverse projection (screen → world at a given Y) is in `ScreenToWorldAtY` ([util/projection.as](util/projection.as)). It rebuilds the camera's view-projection matrix from `Camera::GetCurrent()` using the same composition the camera plugin uses internally, inverts it, and intersects the resulting clip-space ray with the Y plane. If anything fails (no camera, ray parallel, intersection behind near plane) it returns false and the mark stays plain screen-anchored. The Y plane defaults to the controlled car's altitude at click time, sampled via `VehicleState::ViewingPlayerState().Position.y` — fine for ground-level marks; elevated track sections (ramps, loops) will drift.

The anchor fields are persisted via the base `Drawable.Serialize()` (only when `WorldAnchored` is true) and restored after the per-type cast in `DeserializeDrawable`. Subclasses don't need to know about anchoring — it's all on the base class.

**Adjusting altitude after the fact.** With the Select tool, holding Alt while body-dragging an anchored drawable mutates `WorldAnchor.y` instead of translating stored screen coords. The mode is latched in `g_DragYAxis` at press time so toggling Alt mid-drag doesn't switch behavior. The screen-pixel-to-world-meter ratio is camera-aware via `WorldYPerScreenPixel(anchor)` in [util/projection.as](util/projection.as) — it projects the anchor and the anchor +1m and uses the screen-Y delta as the conversion, so the felt response stays constant across replay zoom levels. This is how users fix marks placed on the wrong altitude (ramps, loops) without redrawing.

## Conventions

- Globals are `g_PascalCase`, settings are `S_PascalCase`, parameters are `camelCase`. Filenames are lowercase (`main.as`, not `Main.as`).
- The `Tool` enum is **append-only**. Persisted state (`state.json`) stores the current tool as `int(g_CurrentTool)`; reordering existing members would silently re-map old saves.
- Mutations to `g_Drawables` go through `StartStroke` / `AppendPointToActiveStroke` / `FinishStroke` for streaming pen/highlighter strokes, or `CommitPending` for press-drag-release shapes. Single-shot inserts (text, marker) go directly through the handler. `UndoLast` / `RedoLast` / `ClearAll` are the only paths that pop or wipe.
- After any committed mutation, call `ClearRedoStack()` *before* `SaveState()` — a new branch in undo history invalidates the redo stack. `UndoLast` and `RedoLast` are the two exceptions; they shuttle between the two stacks.
- Pen strokes only append a new point when it's at least `S_MinPointDistance` pixels from the previous one (in `AppendPointToActiveStroke`). This is what keeps the stroke arrays from exploding on slow mouse drags.
- The `Drawable.Draw` signature takes a `float alphaMul` — multiply it into `Color.w` so the auto-fade timer works. Subclasses that ignore it will not fade.

## Versioning

Bump `version` in `info.toml` when shipping changes — Openplanet's plugin manager uses it for update detection.
