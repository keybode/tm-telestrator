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
    - telestrator/main.as ....... runtime: globals, OP callbacks, stroke lifecycle
    - telestrator/canvas.as ..... per-frame DrawAll / DrawCursorPreview + world-anchor offset helpers
    - telestrator/history.as .... UndoLast / RedoLast / ClearRedoStack / ClearAll
    - state/settings.as ......... [Setting]-decorated variables auto-persisted by Openplanet
    - state/persistence.as ...... SaveState / LoadState / (de)serialization helpers
    - ui/toolbar.as ............. toolbar window, tool selector, palette, floating text-input popup
    - ui/input.as ............... hotkeys, mouse routing, CanDraw / CancelInFlight gates
    - ui/tools.as ............... per-tool input handlers (Pen, Arrow, Rect, Eraser, Select, ...) + shape helpers
    - ui/drawables.as ........... Drawable class hierarchy + PaletteColor
    - util/helpers.as ........... math + dashed-line helper + IsInMap + ColorsEqual
    - util/projection.as ........ world-anchor screen<->world helpers (depends on Camera + VehicleState)
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
// True for the duration of a Select-tool body drag launched with Alt held on a
// world-anchored drawable: vertical cursor motion mutates WorldAnchor.y instead of
// translating the drawable's stored coords. Latched at press time so toggling Alt
// mid-drag doesn't switch modes.
bool g_DragYAxis = false;
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

// Canvas rendering lives in [canvas.as](canvas.as) — DrawAll, DrawCursorPreview, and
// the world-anchor offset helpers (GetDrawableOffset, ToStoredFrame).
