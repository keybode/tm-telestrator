// Undo / redo / clear / delete-selected.
//
// The undo system is an explicit operation stack: every committed mutation pushes a
// HistoryOp onto g_UndoStack (declared in main.as) describing what changed. UndoLast
// pops from there and reverses the op; RedoLast pops g_RedoStack and re-applies. This
// replaces the older "g_Drawables order = chronological order" model and lets a Delete
// of a mark in the middle of the array be undoable.
//
// Every mutation that should appear in undo history pushes a HistoryOp:
//   - StartStroke / CommitPending / HandleMarker push HOP_Create.
//   - DeleteSelected pushes HOP_Delete with the original array index.
// Mutations that should NOT appear (eraser, fade-prune) call ForgetHistoryFor instead,
// which scrubs any matching ops from both stacks so undo doesn't try to operate on a
// drawable that's already been silently removed.
//
// After any committed mutation, callers also call ClearRedoStack() before SaveState() —
// a new branch in undo history invalidates the redo stack. UndoLast and RedoLast are the
// two exceptions; they shuttle ops between the two stacks.

void UndoLast() {
    if (g_UndoStack.Length == 0) return;
    HistoryOp@ op = g_UndoStack[g_UndoStack.Length - 1];
    g_UndoStack.RemoveLast();

    if (op.Kind == HOP_Create) {
        // Undo a creation: remove the drawable from g_Drawables.
        int idx = -1;
        for (uint i = 0; i < g_Drawables.Length; i++) {
            if (g_Drawables[i] is op.Target) { idx = int(i); break; }
        }
        if (idx >= 0) {
            // Drop any handle pointing at this drawable so dangling refs don't survive.
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
        // HOP_Delete: re-insert the target at the original index. Reset CreatedAt so a
        // restored mark doesn't immediately re-fade.
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
        // Redo a creation: re-add at the end. Reset CreatedAt so the redone drawable
        // doesn't immediately re-fade.
        op.Target.CreatedAt = Time::Now;
        g_Drawables.InsertLast(op.Target);
    } else {
        // HOP_Delete: remove the target from g_Drawables.
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

// Removes the currently selected drawable, recording the deletion on the undo stack so
// it can be reversed via UndoLast.
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

// Removes any history ops referencing `d`, called when the eraser or fade-prune silently
// drops a drawable. Without this, a later UndoLast would try to operate on a target that
// no longer exists in g_Drawables (HOP_Create) or was already removed (HOP_Delete).
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
