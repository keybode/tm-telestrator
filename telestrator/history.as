
void UndoLast() {
    if (g_UndoStack.Length == 0) return;
    HistoryOp@ op = g_UndoStack[g_UndoStack.Length - 1];
    g_UndoStack.RemoveLast();

    if (op.Kind == HOP_Create) {
        int idx = -1;
        for (uint i = 0; i < g_Drawables.Length; i++) {
            if (g_Drawables[i] is op.Target) { idx = int(i); break; }
        }
        if (idx >= 0) {
            if (g_ActiveStroke !is null && g_Drawables[idx] is g_ActiveStroke) {
                @g_ActiveStroke = null;
            }
            if (g_DraggedDrawable !is null && g_Drawables[idx] is g_DraggedDrawable) {
                @g_DraggedDrawable = null;
                g_DragMoved = false;
            }
            if (g_SelectedDrawable !is null && g_Drawables[idx] is g_SelectedDrawable) {
                @g_SelectedDrawable = null;
                g_DraggedHandleIndex = -1;
            }
            g_Drawables.RemoveAt(uint(idx));
        }
    } else {
        int idx = op.Index;
        if (idx < 0) idx = 0;
        if (idx > int(g_Drawables.Length)) idx = int(g_Drawables.Length);
        g_Drawables.InsertAt(uint(idx), op.Target);
        op.Target.CreatedAt = Time::Now;
    }

    g_RedoStack.InsertLast(op);
    SaveState();
}

void RedoLast() {
    if (g_RedoStack.Length == 0) return;
    HistoryOp@ op = g_RedoStack[g_RedoStack.Length - 1];
    g_RedoStack.RemoveLast();

    if (op.Kind == HOP_Create) {
        op.Target.CreatedAt = Time::Now;
        g_Drawables.InsertLast(op.Target);
    } else {
        for (uint i = 0; i < g_Drawables.Length; i++) {
            if (g_Drawables[i] is op.Target) {
                if (g_SelectedDrawable !is null && g_Drawables[i] is g_SelectedDrawable) {
                    @g_SelectedDrawable = null;
                    g_DraggedHandleIndex = -1;
                }
                g_Drawables.RemoveAt(i);
                break;
            }
        }
    }

    g_UndoStack.InsertLast(op);
    SaveState();
}

void DeleteSelected() {
    if (g_SelectedDrawable is null) return;
    int idx = -1;
    for (uint i = 0; i < g_Drawables.Length; i++) {
        if (g_Drawables[i] is g_SelectedDrawable) {
            idx = int(i);
            break;
        }
    }
    if (idx < 0) {
        @g_SelectedDrawable = null;
        return;
    }
    Drawable@ target = g_Drawables[idx];
    if (g_ActiveStroke !is null && target is g_ActiveStroke) @g_ActiveStroke = null;
    if (g_DraggedDrawable !is null && target is g_DraggedDrawable) {
        @g_DraggedDrawable = null;
        g_DragMoved = false;
    }
    g_Drawables.RemoveAt(uint(idx));
    @g_SelectedDrawable = null;
    g_DraggedHandleIndex = -1;
    g_UndoStack.InsertLast(HistoryOp(HOP_Delete, target, idx));
    ClearRedoStack();
    SaveState();
}

void ForgetHistoryFor(Drawable@ d) {
    for (int i = int(g_UndoStack.Length) - 1; i >= 0; i--) {
        if (g_UndoStack[i].Target is d) g_UndoStack.RemoveAt(uint(i));
    }
    for (int i = int(g_RedoStack.Length) - 1; i >= 0; i--) {
        if (g_RedoStack[i].Target is d) g_RedoStack.RemoveAt(uint(i));
    }
}

void ClearRedoStack() {
    if (g_RedoStack.Length > 0) g_RedoStack.RemoveRange(0, g_RedoStack.Length);
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
    if (g_UndoStack.Length > 0) g_UndoStack.RemoveRange(0, g_UndoStack.Length);
    ClearRedoStack();
    SaveState();
}
