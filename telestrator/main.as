// Telestrator
// screen drawing overlay
// TODO:
// - special tools for replay (deferred)
// - ability to draw on 3d surface

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

const bool g_WorldAnchorFeatureEnabled = false;

bool g_WindowVisible = false;
bool g_DrawingEnabled = false;
bool g_BlockDrawingThisFrame = false;
Tool g_CurrentTool = Tool::Pen;

bool g_TextInputOpen = false;
bool g_TextInputNeedsFocus = false;
string g_TextInputBuffer;

bool g_EraseDirty = false;

int g_NextMarkerNumber = 1;

array<Drawable@> g_Drawables;

enum HistoryOpKind {
    HOP_Create,
    HOP_Delete
}

class HistoryOp {
    HistoryOpKind Kind;
    Drawable@ Target;
    int Index;

    HistoryOp() {}
    HistoryOp(HistoryOpKind k, Drawable@ d, int i) {
        Kind = k;
        @Target = d;
        Index = i;
    }
}

array<HistoryOp@> g_UndoStack;
array<HistoryOp@> g_RedoStack;

Stroke@ g_ActiveStroke = null;
Drawable@ g_Pending = null;
vec2 g_PendingAnchor;
Drawable@ g_DraggedDrawable = null;
vec2 g_DragLastPos;
bool g_DragMoved = false;
bool g_DragYAxis = false;
Drawable@ g_SelectedDrawable = null;
int g_DraggedHandleIndex = -1;

bool g_LastMouseDown = false;
vec4 g_CurrentColor = vec4(1.0f, 0.2f, 0.2f, 1.0f);

uint64 g_FrameCounter = 0;

array<PaletteColor@> g_Palette = {
    PaletteColor("red",    "Brake",   vec4(1.0f, 0.2f, 0.2f, 1.0f)),
    PaletteColor("green",  "Accel",   vec4(0.2f, 1.0f, 0.2f, 1.0f)),
    PaletteColor("blue",   "Drift",   vec4(0.2f, 0.6f, 1.0f, 1.0f)),
    PaletteColor("yellow", "Release", vec4(1.0f, 0.95f, 0.2f, 1.0f)),
};

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
    g_FrameCounter++;
    HandleHotkeys();
    DrawAll();

    if (g_WindowVisible) {
        RenderToolbar();
    }

    RenderTextInput();
    HandleDrawingInput();
    DrawCursorPreview();
}

void StartStroke(const vec2 &in startPos, bool highlighter) {
    Stroke@ s = Stroke();
    if (highlighter) {
        s.Color = vec4(g_CurrentColor.x, g_CurrentColor.y, g_CurrentColor.z, g_CurrentColor.w * 0.35f);
        s.Thickness = Math::Max(S_BrushThickness * 4.0f, 12.0f);
        s.Dashed = false;
        s.Highlighter = true;
    } else {
        s.Color = g_CurrentColor;
        s.Thickness = S_BrushThickness;
        s.Dashed = S_Dashed;
    }
    s.Points.InsertLast(startPos);
    AttachWorldAnchor(s, startPos);
    g_Drawables.InsertLast(s);
    g_UndoStack.InsertLast(HistoryOp(HOP_Create, s, -1));
    @g_ActiveStroke = s;
}

void AppendPointToActiveStroke(const vec2 &in pos) {
    if (g_ActiveStroke is null) return;
    vec2 storedPos = g_ActiveStroke.ToStored(pos);
    if (g_ActiveStroke.Points.Length == 0) {
        g_ActiveStroke.Points.InsertLast(storedPos);
        g_ActiveStroke.MeshDirty = true;
        return;
    }
    vec2 lastPoint = g_ActiveStroke.Points[g_ActiveStroke.Points.Length - 1];
    if (Distance(lastPoint, storedPos) >= S_MinPointDistance) {
        g_ActiveStroke.Points.InsertLast(storedPos);
        g_ActiveStroke.MeshDirty = true;
    }
}

void FinishStroke() {
    if (g_ActiveStroke !is null) {
        g_ActiveStroke.RebuildMesh();
        @g_ActiveStroke = null;
        ClearRedoStack();
        SaveState();
    }
}

void CommitPending(Drawable@ d) {
    g_Drawables.InsertLast(d);
    g_UndoStack.InsertLast(HistoryOp(HOP_Create, d, -1));
    @g_Pending = null;
    ClearRedoStack();
    SaveState();
}

