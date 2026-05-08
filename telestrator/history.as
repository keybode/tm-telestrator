// Undo / redo / clear.
//
// Operates on g_Drawables (live canvas) and g_Redo (the redo stack), both declared in
// main.as. Every committed mutation in tool handlers calls ClearRedoStack() before
// SaveState() — a new branch in undo history invalidates the redo stack. UndoLast and
// RedoLast are the two exceptions; they shuttle between the two stacks.

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
