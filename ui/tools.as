// Per-tool input handlers.
//
// Each tool follows a press-drag-release contract driven by HandleDrawingInput in ui/input.as:
// streaming tools (Pen, Highlighter) mutate g_ActiveStroke; bounding-shape tools (Arrow, Line,
// Rect, Circle, Ellipse) mutate g_Pending and only commit on release if non-degenerate;
// one-shot tools (Text, Marker) insert directly on press; Eraser and Select have their own flows.

// Endpoint snap for two-point shapes (Arrow, Line). Shift = 45-degree increments.
vec2 SnapEndpoint(const vec2 &in start, const vec2 &in mousePos) {
    if (IsShiftDown()) {
        return ConstrainAngle(start, mousePos, Math::PI * 0.25f);
    }
    return mousePos;
}

// Sets the world anchor on a freshly-created drawable when S_WorldAnchor is on and we can
// resolve a world point from the press. Called from each tool's "press" branch right after
// the drawable is constructed; silently no-ops on failure so the mark stays screen-anchored.
void AttachWorldAnchor(Drawable@ d, const vec2 &in pressPos) {
    if (!S_WorldAnchor) return;
    vec3 world;
    if (!ComputeWorldAnchor(pressPos, world)) return;
    d.WorldAnchored = true;
    d.WorldAnchor = world;
    d.ScreenAnchorAtCommit = pressPos;
}

// Resolves a press-drag bounding-box shape (Rect, Ellipse) into its (corner1, corner2) pair,
// honoring Shift = square and Ctrl = from-center. `anchor` is the original press position.
void ResolveBoxCorners(const vec2 &in anchor, const vec2 &in mousePos, vec2 &out c1, vec2 &out c2) {
    vec2 endPos = IsShiftDown() ? ConstrainSquare(anchor, mousePos) : mousePos;
    if (IsCtrlDown()) {
        c1 = vec2(2.0f * anchor.x - endPos.x, 2.0f * anchor.y - endPos.y);
        c2 = endPos;
    } else {
        c1 = anchor;
        c2 = endPos;
    }
}

void HandlePen(const vec2 &in mousePos, bool mouseDown, bool pressed, bool released) {
    if (pressed) {
        StartStroke(mousePos, false);
    } else if (mouseDown && g_ActiveStroke !is null) {
        AppendPointToActiveStroke(mousePos);
    } else if (released) {
        FinishStroke();
    }
}

void HandleHighlighter(const vec2 &in mousePos, bool mouseDown, bool pressed, bool released) {
    if (pressed) {
        StartStroke(mousePos, true);
    } else if (mouseDown && g_ActiveStroke !is null) {
        AppendPointToActiveStroke(mousePos);
    } else if (released) {
        FinishStroke();
    }
}

void HandleArrow(const vec2 &in mousePos, bool mouseDown, bool pressed, bool released) {
    if (pressed) {
        Arrow@ a = Arrow();
        a.Color = g_CurrentColor;
        a.Thickness = S_BrushThickness;
        a.Dashed = S_Dashed;
        a.Start = mousePos;
        a.End = mousePos;
        AttachWorldAnchor(a, mousePos);
        g_PendingAnchor = mousePos;
        @g_Pending = a;
    } else if (mouseDown && g_Pending !is null) {
        Arrow@ a = cast<Arrow>(g_Pending);
        if (a !is null) a.End = SnapEndpoint(a.Start, ToStoredFrame(a, mousePos));
    } else if (released && g_Pending !is null) {
        Arrow@ a = cast<Arrow>(g_Pending);
        if (a !is null && Distance(a.Start, a.End) >= 4.0f) {
            CommitPending(a);
        } else {
            @g_Pending = null;
        }
    }
}

void HandleLine(const vec2 &in mousePos, bool mouseDown, bool pressed, bool released) {
    if (pressed) {
        LineSeg@ l = LineSeg();
        l.Color = g_CurrentColor;
        l.Thickness = S_BrushThickness;
        l.Dashed = S_Dashed;
        l.Start = mousePos;
        l.End = mousePos;
        AttachWorldAnchor(l, mousePos);
        g_PendingAnchor = mousePos;
        @g_Pending = l;
    } else if (mouseDown && g_Pending !is null) {
        LineSeg@ l = cast<LineSeg>(g_Pending);
        if (l !is null) l.End = SnapEndpoint(l.Start, ToStoredFrame(l, mousePos));
    } else if (released && g_Pending !is null) {
        LineSeg@ l = cast<LineSeg>(g_Pending);
        if (l !is null && Distance(l.Start, l.End) >= 4.0f) {
            CommitPending(l);
        } else {
            @g_Pending = null;
        }
    }
}

void HandleRect(const vec2 &in mousePos, bool mouseDown, bool pressed, bool released) {
    if (pressed) {
        RectShape@ r = RectShape();
        r.Color = g_CurrentColor;
        r.Thickness = S_BrushThickness;
        r.Corner1 = mousePos;
        r.Corner2 = mousePos;
        AttachWorldAnchor(r, mousePos);
        g_PendingAnchor = mousePos;
        @g_Pending = r;
    } else if (mouseDown && g_Pending !is null) {
        RectShape@ r = cast<RectShape>(g_Pending);
        if (r !is null) ResolveBoxCorners(g_PendingAnchor, ToStoredFrame(r, mousePos), r.Corner1, r.Corner2);
    } else if (released && g_Pending !is null) {
        RectShape@ r = cast<RectShape>(g_Pending);
        if (r !is null && Distance(r.Corner1, r.Corner2) >= 4.0f) {
            CommitPending(r);
        } else {
            @g_Pending = null;
        }
    }
}

void HandleCircle(const vec2 &in mousePos, bool mouseDown, bool pressed, bool released) {
    if (pressed) {
        CircleShape@ ci = CircleShape();
        ci.Color = g_CurrentColor;
        ci.Thickness = S_BrushThickness;
        ci.Center = mousePos;
        ci.Radius = 0.0f;
        AttachWorldAnchor(ci, mousePos);
        g_PendingAnchor = mousePos;
        @g_Pending = ci;
    } else if (mouseDown && g_Pending !is null) {
        CircleShape@ ci = cast<CircleShape>(g_Pending);
        if (ci !is null) ci.Radius = Distance(ci.Center, ToStoredFrame(ci, mousePos));
    } else if (released && g_Pending !is null) {
        CircleShape@ ci = cast<CircleShape>(g_Pending);
        if (ci !is null && ci.Radius >= 4.0f) {
            CommitPending(ci);
        } else {
            @g_Pending = null;
        }
    }
}

void HandleEllipse(const vec2 &in mousePos, bool mouseDown, bool pressed, bool released) {
    if (pressed) {
        EllipseShape@ e = EllipseShape();
        e.Color = g_CurrentColor;
        e.Thickness = S_BrushThickness;
        e.Corner1 = mousePos;
        e.Corner2 = mousePos;
        AttachWorldAnchor(e, mousePos);
        g_PendingAnchor = mousePos;
        @g_Pending = e;
    } else if (mouseDown && g_Pending !is null) {
        EllipseShape@ e = cast<EllipseShape>(g_Pending);
        if (e !is null) ResolveBoxCorners(g_PendingAnchor, ToStoredFrame(e, mousePos), e.Corner1, e.Corner2);
    } else if (released && g_Pending !is null) {
        EllipseShape@ e = cast<EllipseShape>(g_Pending);
        if (e !is null && Distance(e.Corner1, e.Corner2) >= 4.0f) {
            CommitPending(e);
        } else {
            @g_Pending = null;
        }
    }
}

void HandleMeasurement(const vec2 &in mousePos, bool mouseDown, bool pressed, bool released) {
    if (pressed) {
        Measurement@ m = Measurement();
        m.Color = g_CurrentColor;
        m.Thickness = S_BrushThickness;
        m.Dashed = S_Dashed;
        m.Start = mousePos;
        m.End = mousePos;
        AttachWorldAnchor(m, mousePos);
        g_PendingAnchor = mousePos;
        @g_Pending = m;
    } else if (mouseDown && g_Pending !is null) {
        Measurement@ m = cast<Measurement>(g_Pending);
        if (m !is null) m.End = SnapEndpoint(m.Start, ToStoredFrame(m, mousePos));
    } else if (released && g_Pending !is null) {
        Measurement@ m = cast<Measurement>(g_Pending);
        if (m !is null && Distance(m.Start, m.End) >= 4.0f) {
            CommitPending(m);
        } else {
            @g_Pending = null;
        }
    }
}

void HandleBracket(const vec2 &in mousePos, bool mouseDown, bool pressed, bool released) {
    if (pressed) {
        Bracket@ b = Bracket();
        b.Color = g_CurrentColor;
        b.Thickness = S_BrushThickness;
        b.Dashed = S_Dashed;
        b.Start = mousePos;
        b.End = mousePos;
        AttachWorldAnchor(b, mousePos);
        g_PendingAnchor = mousePos;
        @g_Pending = b;
    } else if (mouseDown && g_Pending !is null) {
        Bracket@ b = cast<Bracket>(g_Pending);
        if (b !is null) b.End = SnapEndpoint(b.Start, ToStoredFrame(b, mousePos));
    } else if (released && g_Pending !is null) {
        Bracket@ b = cast<Bracket>(g_Pending);
        if (b !is null && Distance(b.Start, b.End) >= 4.0f) {
            CommitPending(b);
        } else {
            @g_Pending = null;
        }
    }
}

// Polygon breaks the press-drag-release contract of the other shape tools: each click adds a
// vertex, click near the first vertex (or press Enter) closes, Escape cancels. The pending
// polygon lives in g_Pending across multiple clicks until commit/cancel.
void HandlePolygon(const vec2 &in mousePos, bool pressed) {
    Polygon@ p = (g_Pending !is null) ? cast<Polygon>(g_Pending) : null;

    if (p !is null) {
        if (UI::IsKeyPressed(UI::Key::Enter)) {
            if (p.Vertices.Length >= 3) {
                CommitPending(p);
            } else {
                @g_Pending = null;
            }
            return;
        }
        if (UI::IsKeyPressed(UI::Key::Escape)) {
            @g_Pending = null;
            return;
        }
    }

    if (!pressed) return;

    if (p is null) {
        Polygon@ np = Polygon();
        np.Color = g_CurrentColor;
        np.Thickness = S_BrushThickness;
        np.Dashed = S_Dashed;
        np.Filled = S_PolygonFill;
        np.Vertices.InsertLast(mousePos);
        // Polygon anchors on the first click; subsequent vertex clicks add screen-space points.
        AttachWorldAnchor(np, mousePos);
        @g_Pending = np;
        return;
    }

    // Click near the first vertex closes the polygon (need 3+ vertices for a triangle minimum).
    vec2 storedMouse = ToStoredFrame(p, mousePos);
    if (p.Vertices.Length >= 3 && Distance(storedMouse, p.Vertices[0]) <= 8.0f) {
        CommitPending(p);
        return;
    }
    p.Vertices.InsertLast(storedMouse);
}

// Two-stage gesture: stage 1 is press-drag-release to set Start+End (Control = midpoint).
// Stage 2 (AwaitingBend) tracks the mouse to position Control; the next click commits.
// Escape cancels at either stage.
void HandleCurvedArrow(const vec2 &in mousePos, bool mouseDown, bool pressed, bool released) {
    CurvedArrow@ ca = (g_Pending !is null) ? cast<CurvedArrow>(g_Pending) : null;

    if (ca !is null && ca.AwaitingBend) {
        ca.Control = ToStoredFrame(ca, mousePos);
        if (UI::IsKeyPressed(UI::Key::Escape)) {
            @g_Pending = null;
            return;
        }
        if (pressed) {
            ca.AwaitingBend = false;
            CommitPending(ca);
        }
        return;
    }

    if (pressed) {
        CurvedArrow@ nca = CurvedArrow();
        nca.Color = g_CurrentColor;
        nca.Thickness = S_BrushThickness;
        nca.Dashed = S_Dashed;
        nca.Start = mousePos;
        nca.End = mousePos;
        nca.Control = mousePos;
        AttachWorldAnchor(nca, mousePos);
        g_PendingAnchor = mousePos;
        @g_Pending = nca;
    } else if (mouseDown && ca !is null) {
        ca.End = SnapEndpoint(ca.Start, ToStoredFrame(ca, mousePos));
        ca.Control = (ca.Start + ca.End) * 0.5f;
    } else if (released && ca !is null) {
        if (Distance(ca.Start, ca.End) >= 4.0f) {
            ca.AwaitingBend = true;
            ca.Control = (ca.Start + ca.End) * 0.5f;
        } else {
            @g_Pending = null;
        }
    }
}

void HandleEraser(const vec2 &in mousePos, bool mouseDown, bool released) {
    if (mouseDown) {
        // Iterate top-down so the most recent drawable goes first.
        // One removal per frame to avoid wiping a whole cluster on a single click.
        for (int i = int(g_Drawables.Length) - 1; i >= 0; i--) {
            Drawable@ d = g_Drawables[i];
            if (IsColorLocked(d.Color)) continue;
            if (d.HitTest(mousePos - GetDrawableOffset(d), S_EraserRadius)) {
                if (g_SelectedDrawable !is null && d is g_SelectedDrawable) {
                    @g_SelectedDrawable = null;
                    g_DraggedHandleIndex = -1;
                }
                g_Drawables.RemoveAt(uint(i));
                g_EraseDirty = true;
                break;
            }
        }
    } else if (released && g_EraseDirty) {
        ClearRedoStack();
        SaveState();
        g_EraseDirty = false;
    }
}

void HandleText(const vec2 &in mousePos, bool pressed) {
    if (pressed && !g_TextInputOpen) {
        g_TextInputPos = mousePos;
        g_TextInputBuffer = "";
        g_TextInputNeedsFocus = true;
        g_TextInputOpen = true;
        // Capture the world anchor at press time; the TextLabel is constructed later in
        // CommitTextInput, by which point the camera may have shifted.
        g_TextInputWorldAnchored = false;
        if (S_WorldAnchor) {
            vec3 world;
            if (ComputeWorldAnchor(mousePos, world)) {
                g_TextInputWorldAnchor = world;
                g_TextInputWorldAnchored = true;
            }
        }
    }
}

void HandleMarker(const vec2 &in mousePos, bool pressed) {
    if (!pressed) return;
    NumberMarker@ m = NumberMarker();
    m.Color = g_CurrentColor;
    m.Position = mousePos;
    m.Number = g_NextMarkerNumber++;
    m.Size = Math::Max(S_TextSize * 1.5f, 24.0f);
    AttachWorldAnchor(m, mousePos);
    g_Drawables.InsertLast(m);
    ClearRedoStack();
    SaveState();
}

// Press priority: (1) handle of the persistently-selected drawable, (2) any drawable body —
// which both selects and starts a body drag, (3) empty space, which deselects. Selection
// persists across mouse-up so the user can grab the same drawable's handles repeatedly.
void HandleSelect(const vec2 &in mousePos, bool mouseDown, bool pressed, bool released) {
    if (pressed) {
        if (g_SelectedDrawable !is null) {
            vec2 selOff = GetDrawableOffset(g_SelectedDrawable);
            array<vec2> handles = g_SelectedDrawable.GetHandles();
            for (uint i = 0; i < handles.Length; i++) {
                if (Distance(mousePos, handles[i] + selOff) <= 8.0f) {
                    g_DraggedHandleIndex = int(i);
                    g_DragLastPos = mousePos;
                    g_DragMoved = false;
                    return;
                }
            }
        }
        for (int i = int(g_Drawables.Length) - 1; i >= 0; i--) {
            Drawable@ candidate = g_Drawables[i];
            if (candidate.HitTest(mousePos - GetDrawableOffset(candidate), 6.0f)) {
                @g_SelectedDrawable = candidate;
                @g_DraggedDrawable = candidate;
                g_DragLastPos = mousePos;
                g_DragMoved = false;
                return;
            }
        }
        @g_SelectedDrawable = null;
    } else if (mouseDown) {
        if (g_DraggedHandleIndex >= 0 && g_SelectedDrawable !is null) {
            // Stored handle position is in the un-offset frame, so subtract the live offset.
            g_SelectedDrawable.MoveHandle(g_DraggedHandleIndex, mousePos - GetDrawableOffset(g_SelectedDrawable));
            g_DragLastPos = mousePos;
            g_DragMoved = true;
        } else if (g_DraggedDrawable !is null) {
            vec2 delta = mousePos - g_DragLastPos;
            if (delta.x != 0.0f || delta.y != 0.0f) {
                // Body drag: pure cursor delta carries through to stored coords. If the
                // camera also moves between frames mid-drag the drawable will visually
                // overshoot by Δoffset; in practice users drag while the camera is paused
                // (replay scrubber), so we don't track a baseline offset.
                g_DraggedDrawable.Translate(delta);
                g_DragLastPos = mousePos;
                g_DragMoved = true;
            }
        }
    } else if (released) {
        if (g_DragMoved) {
            ClearRedoStack();
            SaveState();
        }
        @g_DraggedDrawable = null;
        g_DraggedHandleIndex = -1;
        g_DragMoved = false;
    }
}
