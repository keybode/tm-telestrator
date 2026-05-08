# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Telestrator is an [Openplanet](https://openplanet.dev) plugin for Trackmania, written in AngelScript. It's a screen-drawing overlay used for coaching, replay analysis, and streaming racing-line explanations.

There is no build, lint, or test tooling — Openplanet loads `.as` source files directly at runtime. To "run" it, the folder is placed in `OpenplanetNext/Plugins/` (or zipped as `.op`) and reloaded from inside Trackmania via Openplanet's developer menu.

### Source layout

Openplanet loads `.as` files recursively from the plugin folder, so subfolders are purely organizational. There are no imports or namespaces — every global, setting, class, and function is visible across files regardless of folder. Split is by concern:

- [telestrator/main.as](telestrator/main.as) — runtime: globals, OP callbacks (`Main`, `Render`, `RenderMenu`, `OnDestroyed`, `OnDisabled`), stroke lifecycle.
- [telestrator/canvas.as](telestrator/canvas.as) — per-frame rendering: `DrawAll`, `DrawWithAnchor`, `DrawCursorPreview`, `ComputeAlphaMul`, `PruneFaded`, and the selection highlight/handles drawing. Per-drawable screen-frame helpers (`HitTestScreen`, `MoveHandleScreen`, etc.) live on the `Drawable` class itself.
- [telestrator/history.as](telestrator/history.as) — `UndoLast` / `RedoLast` / `ClearRedoStack` / `ClearAll`. Operates on the `g_Drawables` and `g_Redo` globals declared in main.as.
- [state/settings.as](state/settings.as) — `[Setting ...]`-decorated variables (`S_BrushThickness`, `S_Dashed`, `S_HotkeyToggle`, `S_LockRed`, `S_CustomColor`, ...) auto-persisted by Openplanet.
- [ui/toolbar.as](ui/toolbar.as) — `RenderToolbar`, `RenderToolSelector`, `SetTool`, `RenderPalette`, `RenderColorSwatch`, and the floating `RenderTextInput` / `CommitTextInput` / `CloseTextInput` popup.
- [ui/input.as](ui/input.as) — `HandleHotkeys`, `HandleDrawingInput` (mouse routing into per-tool handlers), `CanDraw`, `CancelInFlight`.
- [ui/tools.as](ui/tools.as) — per-tool input handlers (`HandlePen`, `HandleArrow`, `HandleRect`, `HandleEraser`, `HandleSelect`, ...) and the `SnapEndpoint` / `ResolveBoxCorners` shape helpers.
- [ui/drawables.as](ui/drawables.as) — `Drawable` base class and subclasses (`Stroke`, `Arrow`, `LineSeg`, `RectShape`, `CircleShape`, `EllipseShape`, `TextLabel`, `NumberMarker`) plus `PaletteColor`.
- [state/persistence.as](state/persistence.as) — `SaveState` / `LoadState` and the JSON (de)serialization helpers.
- [util/helpers.as](util/helpers.as) — math (`Distance`, `PointToSegmentDistance`, `ConstrainAngle`, `ConstrainSquare`), modifier-key checks (`IsShiftDown`, `IsCtrlDown`), `IsColorLocked`, `IsInMap`, `ColorsEqual` / `ColorsEqualRGB`, and the dashed-line helper.
- [util/mesh.as](util/mesh.as) — translucent-fill mesh builders. `BuildStrokeUnionMesh` rasterizes a polyline's swept-disc shape; `BuildPolygonFillMesh` rasterizes a simple polygon's interior via horizontal scanline. Both run a `GreedyMeshIntoRects` pass that collapses consecutive marked cells into maximal axis-aligned filled rects. Used by `Stroke.RebuildMesh` (highlighter) and `Polygon.RebuildFillMesh` (filled polygons) to render translucent fills as a union of disjoint rects rather than overlapping triangles, sidestepping the AA-fringe alpha stacking that produces visible seams along every shared edge in ImGui's anti-aliased fill.
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

### Translucent fills via union meshes

Translucent filled shapes (highlighter strokes, filled polygons) can't render as a series of overlapping primitives without artifacts: ImGui's anti-aliased fill feathers every primitive's outer edge by ~0.5px, and where two filled primitives share an edge each fringe contributes alpha to the boundary pixels and stacks. The result is a darker stripe along every shared edge — visible as patchwork-darker self-crossings on highlighter strokes, and as thin lines along triangulation seams on filled polygons.

Workaround: render each shape as a union of disjoint axis-aligned rects. `Stroke` (highlighter) and `Polygon` (filled) each carry an `array<vec4>` mesh field — list of `(x1, y1, x2, y2)` rects whose union covers the shape. At draw time we paint each rect once with `AddQuadFilled`. Adjacent rects still share edges so AA stacking still happens at those edges, but axis-aligned shared edges at integer-grid positions tend to be visually less prominent than diagonal triangulation edges, and self-crossings within the same shape (the worse case) are eliminated entirely.

Mesh builders live in [util/mesh.as](util/mesh.as): `BuildStrokeUnionMesh` (segment stadiums + endpoint discs rasterized into a 2-pixel grid) and `BuildPolygonFillMesh` (horizontal-scanline rasterization of polygon interior). Both use the shared `GreedyMeshIntoRects` to collapse marked cells into maximal rects.

Lifecycle:
- **Stroke** rebuilds the mesh on `FinishStroke` (release of the active drag) and on `DeserializeDrawable` load. `MeshDirty` falls back to per-segment `AddLine` + a vertex-disc at every point (also closes `AddLine`'s butt-cap gaps on bends; pen strokes always use this path).
- **Polygon** rebuilds lazily in `Draw` when `FillMeshDirty` is set. Mutations that invalidate the mesh: construction, `MoveHandle` (handle drag), and load. The mesh isn't serialized — recomputed from `Vertices` on load.

`Translate` shifts both the source vertices and the cached mesh by the same delta so world-anchor offsets and Select-tool body drags don't force a rebuild. The mesh isn't serialized on either type — recomputed from source data on load so a cell-size tweak in [util/mesh.as](util/mesh.as) takes effect on existing saves without a migration.

### Map guard

`IsInMap()` checks `GetApp().CurrentPlayground !is null`. The toolbar early-returns when not in a map and the drawing state is gated through `CanDraw()`. New features that touch game state should go through the same guard.

### World anchoring

When `S_WorldAnchor` is on, fresh marks capture a world-space anchor at press time so they slide with the camera instead of staying glued to the screen. The anchor lives on the `Drawable` base class as three fields: `WorldAnchored` (bool), `WorldAnchor` (vec3), `ScreenAnchorAtCommit` (vec2 — the screen position the anchor projected to at commit time). Per-tool press handlers set these via `AttachWorldAnchor` in [ui/tools.as](ui/tools.as).

The renderer applies the anchor as a **rigid screen-space translate** in `DrawWithAnchor` ([telestrator/canvas.as](telestrator/canvas.as)): each frame, `offset = projectWorld(WorldAnchor) - ScreenAnchorAtCommit` is added to all stored screen coords via `Translate(offset)` / `Translate(-offset)` around `Draw`. Shape geometry is otherwise untouched — no perspective deformation. If the anchor is currently behind the camera, the drawable is skipped entirely (reappears once back in front).

The offset machinery lives on `Drawable` itself — call `d.HitTestScreen(mousePos, r)` / `d.MoveHandleScreen(i, mousePos)` / `d.GetHandlesScreen()` / `d.BoundsScreen(...)` / `d.ToStored(mousePos)` from any code that interacts with a drawable in screen-frame coords. The internal `CurrentOffset()` is cached per frame via `g_FrameCounter` so multiple traversals of `g_Drawables` (DrawAll, hover hint, eraser, select press) all share one camera projection per drawable per frame.

Inverse projection (screen → world at a given Y) is in `ScreenToWorldAtY` ([util/projection.as](util/projection.as)). It rebuilds the camera's view-projection matrix from `Camera::GetCurrent()` using the same composition the camera plugin uses internally, inverts it, and intersects the resulting clip-space ray with the Y plane. If anything fails (no camera, ray parallel, intersection behind near plane) it returns false and the mark stays plain screen-anchored. The Y plane defaults to the controlled car's altitude at click time, sampled via `VehicleState::ViewingPlayerState().Position.y` — fine for ground-level marks; elevated track sections (ramps, loops) will drift.

The anchor fields are persisted via the base `Drawable.Serialize()` (only when `WorldAnchored` is true) and restored after the per-type cast in `DeserializeDrawable`. Subclasses don't need to know about anchoring — it's all on the base class.

**Adjusting altitude after the fact.** With the Select tool, holding Alt while body-dragging an anchored drawable mutates `WorldAnchor.y` instead of translating stored screen coords. The mode is latched in `g_DragYAxis` at press time so toggling Alt mid-drag doesn't switch behavior. The screen-pixel-to-world-meter ratio is camera-aware via `WorldYPerScreenPixel(anchor)` in [util/projection.as](util/projection.as) — it projects the anchor and the anchor +1m and uses the screen-Y delta as the conversion, so the felt response stays constant across replay zoom levels. This is how users fix marks placed on the wrong altitude (ramps, loops) without redrawing.

## Conventions

- Globals are `g_PascalCase`, settings are `S_PascalCase`, parameters are `camelCase`. Filenames are lowercase (`main.as`, not `Main.as`).
- The `Tool` enum is **append-only**. Persisted state (`state.json`) stores the current tool as `int(g_CurrentTool)`; reordering existing members would silently re-map old saves.
- Mutations to `g_Drawables` go through `StartStroke` / `AppendPointToActiveStroke` / `FinishStroke` for streaming pen/highlighter strokes, or `CommitPending` for press-drag-release shapes (and the deferred TextLabel popup, which lives in `g_Pending` while the user is typing). The Marker tool inserts directly. `UndoLast` / `RedoLast` / `ClearAll` are the only paths that pop or wipe.
- After any committed mutation, call `ClearRedoStack()` *before* `SaveState()` — a new branch in undo history invalidates the redo stack. `UndoLast` and `RedoLast` are the two exceptions; they shuttle between the two stacks.
- Pen strokes only append a new point when it's at least `S_MinPointDistance` pixels from the previous one (in `AppendPointToActiveStroke`). This is what keeps the stroke arrays from exploding on slow mouse drags.
- The `Drawable.Draw` signature takes a `float alphaMul` — multiply it into `Color.w` so the auto-fade timer works. Subclasses that ignore it will not fade.

## Versioning

Bump `version` in `info.toml` when shipping changes — Openplanet's plugin manager uses it for update detection.
