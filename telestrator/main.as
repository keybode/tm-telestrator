/*
    Telestrator
    by Trev_TM

    Simple screen drawing overlay.

    Intended for:
    - explaining racing lines
    - replay analysis
    - coaching / streaming

    Features:
    - tools: pen, highlighter, arrow, curved arrow, line, measurement, bracket, rect, circle, ellipse, polygon, text, marker, eraser, select
    - dashed variant for pen / arrow / line / measurement / bracket / curved arrow / polygon
    - multiple colors
    - adjustable brush thickness
    - undo / redo / clear
    - optional auto-fade
    - state persists across sessions

    Source layout (Openplanet loads .as files recursively, so the folders are purely organizational):
    - telestrator/main.as ....... runtime: globals, OP callbacks, stroke lifecycle, drawable management, canvas rendering
    - state/settings.as ......... [Setting]-decorated variables auto-persisted by Openplanet
    - state/persistence.as ...... SaveState / LoadState / (de)serialization helpers
    - ui/toolbar.as ............. toolbar window, tool selector, palette, floating text-input popup
    - ui/input.as ............... hotkeys, mouse routing, CanDraw / CancelInFlight gates
    - ui/tools.as ............... per-tool input handlers (Pen, Arrow, Rect, Eraser, Select, ...) + shape helpers
    - ui/drawables.as ........... Drawable class hierarchy + PaletteColor
    - util/helpers.as ........... math + dashed-line helper + IsInMap + ColorsEqual
*/

// TODO:
// - special tools for replay (deferred)

// New entries are appended (never reordered) so persisted Tool ints stay valid across versions.
enum Tool {
    Pen,
    Arrow,
    Eraser,
    Text,
    Select,
    Highlighter,
    Line,
    Rect,
    Circle,
    Ellipse,
    Marker,
    Measurement,
    Polygon,
    Bracket,
    CurvedArrow
}

bool g_WindowVisible = false;
bool g_DrawingEnabled = false;
bool g_BlockDrawingThisFrame = false;
Tool g_CurrentTool = Tool::Pen;

bool g_TextInputOpen = false;
bool g_TextInputNeedsFocus = false;
vec2 g_TextInputPos;
string g_TextInputBuffer;
// Captured at HandleText press time (when S_WorldAnchor was on and resolved); applied to
// the TextLabel in CommitTextInput. Plain screen-space mark if the resolve failed.
bool g_TextInputWorldAnchored = false;
vec3 g_TextInputWorldAnchor = vec3(0, 0, 0);

bool g_EraseDirty = false;

int g_NextMarkerNumber = 1;

// Global state

array<Drawable@> g_Drawables;
array<Drawable@> g_Redo;
Stroke@ g_ActiveStroke = null;
Drawable@ g_Pending = null;
// Original press position for the active shape drag — needed because Ctrl-from-center mutates
// Corner1 mid-drag, so we can't recover the press point from the shape itself.
vec2 g_PendingAnchor;
Drawable@ g_DraggedDrawable = null;
vec2 g_DragLastPos;
bool g_DragMoved = false;
// Persistent selection for the Select tool: survives mouse-up so the user can grab handles
// across multiple drags. Cleared on tool switch, undo/erase of the selected drawable, ClearAll.
Drawable@ g_SelectedDrawable = null;
// Index into g_SelectedDrawable.GetHandles() while a handle drag is in flight, -1 otherwise.
int g_DraggedHandleIndex = -1;

bool g_LastMouseDown = false;
vec4 g_CurrentColor = vec4(1.0f, 0.2f, 0.2f, 1.0f);

array<PaletteColor@> g_Palette = {
    PaletteColor("red",    "Brake",   vec4(1.0f, 0.2f, 0.2f, 1.0f)),
    PaletteColor("green",  "Accel",   vec4(0.2f, 1.0f, 0.2f, 1.0f)),
    PaletteColor("blue",   "Drift",   vec4(0.2f, 0.6f, 1.0f, 1.0f)),
    PaletteColor("yellow", "Release", vec4(1.0f, 0.95f, 0.2f, 1.0f)),
};

// OP callbacks

void Main() {
    LoadState();
    if (S_AutoOpenOnLoad) g_WindowVisible = true;
}

void OnDestroyed() {
    SaveState();
}

void OnDisabled() {
    SaveState();
}

void RenderMenu() {
    if (UI::MenuItem("Telestrator", "", g_WindowVisible)) {
        g_WindowVisible = !g_WindowVisible;
    }
}

void Render() {
    HandleHotkeys();
    DrawAll();

    if (g_WindowVisible) {
        RenderToolbar();
    }

    RenderTextInput();
    HandleDrawingInput();
    DrawCursorPreview();
}

// Stroke lifecycle

void StartStroke(const vec2 &in startPos, bool highlighter) {
    Stroke@ s = Stroke();
    if (highlighter) {
        // Translucent + ~4x thicker mimics a marker pen, and lets dimmer strokes layer.
        s.Color = vec4(g_CurrentColor.x, g_CurrentColor.y, g_CurrentColor.z, g_CurrentColor.w * 0.35f);
        s.Thickness = Math::Max(S_BrushThickness * 4.0f, 12.0f);
        s.Dashed = false;
    } else {
        s.Color = g_CurrentColor;
        s.Thickness = S_BrushThickness;
        s.Dashed = S_Dashed;
    }
    s.Points.InsertLast(startPos);
    AttachWorldAnchor(s, startPos);
    g_Drawables.InsertLast(s);
    @g_ActiveStroke = s;
}

void AppendPointToActiveStroke(const vec2 &in pos) {
    if (g_ActiveStroke is null) return;
    // Convert into the stroke's stored frame so points captured across a moving camera
    // stay aligned with each other (and with already-stored points from earlier in the drag).
    vec2 storedPos = ToStoredFrame(g_ActiveStroke, pos);
    if (g_ActiveStroke.Points.Length == 0) {
        g_ActiveStroke.Points.InsertLast(storedPos);
        return;
    }
    vec2 lastPoint = g_ActiveStroke.Points[g_ActiveStroke.Points.Length - 1];
    if (Distance(lastPoint, storedPos) >= S_MinPointDistance) {
        g_ActiveStroke.Points.InsertLast(storedPos);
    }
}

void FinishStroke() {
    if (g_ActiveStroke !is null) {
        @g_ActiveStroke = null;
        ClearRedoStack();
        SaveState();
    }
}

void CommitPending(Drawable@ d) {
    g_Drawables.InsertLast(d);
    @g_Pending = null;
    ClearRedoStack();
    SaveState();
}

// Drawable management

void UndoLast() {
    if (g_Drawables.Length == 0) return;
    Drawable@ removed = g_Drawables[g_Drawables.Length - 1];
    if (g_ActiveStroke !is null && removed is g_ActiveStroke) {
        @g_ActiveStroke = null;
    }
    if (g_DraggedDrawable !is null && removed is g_DraggedDrawable) {
        @g_DraggedDrawable = null;
        g_DragMoved = false;
    }
    if (g_SelectedDrawable !is null && removed is g_SelectedDrawable) {
        @g_SelectedDrawable = null;
        g_DraggedHandleIndex = -1;
    }
    g_Drawables.RemoveLast();
    g_Redo.InsertLast(removed);
    SaveState();
}

void RedoLast() {
    if (g_Redo.Length == 0) return;
    Drawable@ d = g_Redo[g_Redo.Length - 1];
    g_Redo.RemoveLast();
    // Reset CreatedAt so a redone drawable doesn't immediately re-fade.
    d.CreatedAt = Time::Now;
    g_Drawables.InsertLast(d);
    SaveState();
}

void ClearRedoStack() {
    if (g_Redo.Length > 0) g_Redo.RemoveRange(0, g_Redo.Length);
}

void ClearAll() {
    if (g_Drawables.Length == 0 && g_Pending is null) return;
    g_Drawables.RemoveRange(0, g_Drawables.Length);
    @g_ActiveStroke = null;
    @g_Pending = null;
    @g_DraggedDrawable = null;
    @g_SelectedDrawable = null;
    g_DraggedHandleIndex = -1;
    g_DragMoved = false;
    g_NextMarkerNumber = 1;
    ClearRedoStack();
    SaveState();
}

// Rendering

void DrawAll() {
    auto drawList = UI::GetBackgroundDrawList();

    PruneFaded();

    for (uint i = 0; i < g_Drawables.Length; i++) {
        Drawable@ d = g_Drawables[i];
        if (d is null) continue;
        float alpha = ComputeAlphaMul(d);
        if (alpha > 0.0f) DrawWithAnchor(d, drawList, alpha);
    }
    if (g_Pending !is null) {
        DrawWithAnchor(g_Pending, drawList, 1.0f);
    }
}

// Draws a Drawable, applying its world anchor as a rigid screen-space translate. The
// translate-then-untranslate trick mutates Drawable state for the duration of one Draw
// call only — safe because input is sampled in HandleDrawingInput *after* DrawAll, so
// no observer sees the offset state.
void DrawWithAnchor(Drawable@ d, UI::DrawList@ drawList, float alpha) {
    if (!d.WorldAnchored) {
        d.Draw(drawList, alpha);
        return;
    }
    vec2 offset;
    if (!GetAnchorOffset(d.WorldAnchor, d.ScreenAnchorAtCommit, offset)) {
        // Anchor is behind the camera or no camera available: skip rather than draw at
        // a stale position. The mark reappears once the anchor is in front again.
        return;
    }
    if (offset.x == 0.0f && offset.y == 0.0f) {
        d.Draw(drawList, alpha);
        return;
    }
    d.Translate(offset);
    d.Draw(drawList, alpha);
    d.Translate(vec2(-offset.x, -offset.y));
}

// Current screen-space offset for an anchored drawable, or (0,0) if not anchored / not
// resolvable. Input handlers subtract this from mousePos so hit-tests and handle drags
// see the same coords the renderer used.
vec2 GetDrawableOffset(Drawable@ d) {
    if (d is null || !d.WorldAnchored) return vec2(0, 0);
    vec2 off;
    if (!GetAnchorOffset(d.WorldAnchor, d.ScreenAnchorAtCommit, off)) return vec2(0, 0);
    return off;
}

// Converts a current-frame screen position into the drawable's stored coordinate frame.
// Use when assigning live mouse coords to drawable storage during a drag; the renderer
// adds the offset back, so the visible point matches the cursor regardless of any
// camera motion mid-drag. (0,0) offset means storedFrame == screenFrame, so non-anchored
// callers see no behavior change.
vec2 ToStoredFrame(Drawable@ d, const vec2 &in screen) {
    return screen - GetDrawableOffset(d);
}

float ComputeAlphaMul(Drawable@ d) {
    if (S_AutoFadeSeconds <= 0.001f) return 1.0f;
    if (d is g_ActiveStroke) return 1.0f;
    if (d is g_DraggedDrawable) return 1.0f;
    if (d is g_SelectedDrawable) return 1.0f;
    float total = S_AutoFadeSeconds;
    float age = float(Time::Now - d.CreatedAt) / 1000.0f;
    float fadeWindow = Math::Min(1.0f, total);
    float fadeStart = total - fadeWindow;
    if (age <= fadeStart) return 1.0f;
    if (age >= total) return 0.0f;
    return 1.0f - (age - fadeStart) / fadeWindow;
}

void PruneFaded() {
    if (S_AutoFadeSeconds <= 0.001f) return;
    float total = S_AutoFadeSeconds;
    for (int i = int(g_Drawables.Length) - 1; i >= 0; i--) {
        Drawable@ d = g_Drawables[i];
        if (d is g_ActiveStroke) continue;
        if (d is g_DraggedDrawable) continue;
        if (d is g_SelectedDrawable) continue;
        float age = float(Time::Now - d.CreatedAt) / 1000.0f;
        if (age >= total) {
            g_Drawables.RemoveAt(uint(i));
        }
    }
}

void DrawCursorPreview() {
    if (!CanDraw()) return;

    vec2 mousePos = UI::GetMousePos();
    auto drawList = UI::GetBackgroundDrawList();

    if (g_CurrentTool == Tool::Pen) {
        float radius = Math::Max(S_BrushThickness * 0.5f, 1.5f);
        vec4 fill = vec4(g_CurrentColor.x, g_CurrentColor.y, g_CurrentColor.z, 0.7f);
        drawList.AddCircleFilled(mousePos, radius, fill);
        drawList.AddCircle(mousePos, radius + 1.0f, vec4(0, 0, 0, 0.6f), 0, 1.0f);
    } else if (g_CurrentTool == Tool::Highlighter) {
        float radius = Math::Max(S_BrushThickness * 2.0f, 6.0f);
        vec4 fill = vec4(g_CurrentColor.x, g_CurrentColor.y, g_CurrentColor.z, 0.35f);
        drawList.AddCircleFilled(mousePos, radius, fill);
        drawList.AddCircle(mousePos, radius + 1.0f, vec4(0, 0, 0, 0.5f), 0, 1.0f);
    } else if (g_CurrentTool == Tool::Eraser) {
        drawList.AddCircle(mousePos, S_EraserRadius, vec4(1, 1, 1, 0.9f), 0, 1.5f);
        drawList.AddCircle(mousePos, S_EraserRadius + 1.0f, vec4(0, 0, 0, 0.5f), 0, 1.0f);
    } else if (g_CurrentTool == Tool::Marker) {
        float radius = Math::Max(S_TextSize * 0.75f, 12.0f);
        vec4 fill = vec4(g_CurrentColor.x, g_CurrentColor.y, g_CurrentColor.z, 0.6f);
        drawList.AddCircle(mousePos, radius, fill, 0, 1.5f);
    } else if (g_CurrentTool == Tool::Select) {
        // Persistent selection: bbox + handles always visible while selected.
        if (g_SelectedDrawable !is null) {
            DrawSelectionHighlight(drawList, g_SelectedDrawable);
            DrawSelectionHandles(drawList, g_SelectedDrawable);
        }
        // Hover hint: only when not mid-drag and not already on the selected drawable.
        if (g_DraggedHandleIndex < 0 && g_DraggedDrawable is null) {
            Drawable@ hover = null;
            for (int i = int(g_Drawables.Length) - 1; i >= 0; i--) {
                Drawable@ candidate = g_Drawables[i];
                if (candidate.HitTest(mousePos - GetDrawableOffset(candidate), 6.0f)) {
                    @hover = candidate;
                    break;
                }
            }
            if (hover !is null && hover !is g_SelectedDrawable) {
                DrawSelectionHighlight(drawList, hover);
            }
        }
    } else {
        // Generic crosshair for the press-drag-release shape tools (Arrow, Line, Rect, Circle, Ellipse, Text).
        DrawCrosshair(drawList, mousePos, g_CurrentColor);
    }
}

void DrawCrosshair(UI::DrawList@ drawList, const vec2 &in pos, const vec4 &in color) {
    vec4 c = vec4(color.x, color.y, color.z, 0.7f);
    float r = 6.0f;
    drawList.AddLine(vec2(pos.x - r, pos.y), vec2(pos.x + r, pos.y), c, 1.0f);
    drawList.AddLine(vec2(pos.x, pos.y - r), vec2(pos.x, pos.y + r), c, 1.0f);
}

void DrawSelectionHandles(UI::DrawList@ drawList, Drawable@ d) {
    array<vec2> handles = d.GetHandles();
    if (handles.Length == 0) return;
    vec2 off = GetDrawableOffset(d);
    vec4 fill = vec4(1.0f, 1.0f, 1.0f, 0.95f);
    vec4 border = vec4(0.05f, 0.05f, 0.05f, 0.9f);
    for (uint i = 0; i < handles.Length; i++) {
        vec2 p = handles[i] + off;
        drawList.AddCircleFilled(p, 5.0f, fill);
        drawList.AddCircle(p, 5.5f, border, 0, 1.5f);
    }
}

void DrawSelectionHighlight(UI::DrawList@ drawList, Drawable@ d) {
    vec2 boundsMin, boundsMax;
    d.Bounds(boundsMin, boundsMax);
    vec2 off = GetDrawableOffset(d);
    boundsMin = boundsMin + off;
    boundsMax = boundsMax + off;
    float pad = 4.0f;
    vec2 a = vec2(boundsMin.x - pad, boundsMin.y - pad);
    vec2 b = vec2(boundsMax.x + pad, boundsMin.y - pad);
    vec2 c = vec2(boundsMax.x + pad, boundsMax.y + pad);
    vec2 e = vec2(boundsMin.x - pad, boundsMax.y + pad);
    vec4 col = vec4(1.0f, 1.0f, 1.0f, 0.85f);
    drawList.AddLine(a, b, col, 1.5f);
    drawList.AddLine(b, c, col, 1.5f);
    drawList.AddLine(c, e, col, 1.5f);
    drawList.AddLine(e, a, col, 1.5f);
}
