
vec2 SnapEndpoint(const vec2 &in start, const vec2 &in mousePos) {
    if (IsShiftDown()) {
        return ConstrainAngle(start, mousePos, Math::PI * 0.25f);
    }
    return mousePos;
}

void AttachWorldAnchor(Drawable@ d, const vec2 &in pressPos) {
    if (!g_WorldAnchorFeatureEnabled) return;
    if (!S_WorldAnchor) return;
    vec3 world;
    if (!ComputeWorldAnchor(pressPos, world)) return;
    d.WorldAnchored = true;
    d.WorldAnchor = world;
    d.ScreenAnchorAtCommit = pressPos;
}

void CommitOrCancelPending() {
    if (g_Pending is null) return;
    if (g_Pending.IsNonDegenerate()) CommitPending(g_Pending);
    else @g_Pending = null;
}

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
        if (a !is null) a.End = SnapEndpoint(a.Start, a.ToStored(mousePos));
    } else if (released) {
        CommitOrCancelPending();
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
        if (l !is null) l.End = SnapEndpoint(l.Start, l.ToStored(mousePos));
    } else if (released) {
        CommitOrCancelPending();
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
        if (r !is null) ResolveBoxCorners(g_PendingAnchor, r.ToStored(mousePos), r.Corner1, r.Corner2);
    } else if (released) {
        CommitOrCancelPending();
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
        if (ci !is null) ci.Radius = Distance(ci.Center, ci.ToStored(mousePos));
    } else if (released) {
        CommitOrCancelPending();
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
        if (e !is null) ResolveBoxCorners(g_PendingAnchor, e.ToStored(mousePos), e.Corner1, e.Corner2);
    } else if (released) {
        CommitOrCancelPending();
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
        if (m !is null) m.End = SnapEndpoint(m.Start, m.ToStored(mousePos));
    } else if (released) {
        CommitOrCancelPending();
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
        if (b !is null) b.End = SnapEndpoint(b.Start, b.ToStored(mousePos));
    } else if (released) {
        CommitOrCancelPending();
    }
}

void HandlePolygon(const vec2 &in mousePos, bool pressed) {
    Polygon@ p = (g_Pending !is null) ? cast<Polygon>(g_Pending) : null;

    if (p !is null) {
        if (UI::IsKeyPressed(UI::Key::Enter)) {
            CommitOrCancelPending();
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
        AttachWorldAnchor(np, mousePos);
        @g_Pending = np;
        return;
    }

    vec2 storedMouse = p.ToStored(mousePos);
    if (p.Vertices.Length >= 3 && Distance(storedMouse, p.Vertices[0]) <= 8.0f) {
        CommitPending(p);
        return;
    }
    p.Vertices.InsertLast(storedMouse);
}

void HandleCurvedArrow(const vec2 &in mousePos, bool mouseDown, bool pressed, bool released) {
    CurvedArrow@ ca = (g_Pending !is null) ? cast<CurvedArrow>(g_Pending) : null;

    if (ca !is null && ca.AwaitingBend) {
        ca.Control = ca.ToStored(mousePos);
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
        ca.End = SnapEndpoint(ca.Start, ca.ToStored(mousePos));
        ca.Control = (ca.Start + ca.End) * 0.5f;
    } else if (released && ca !is null) {
        if (ca.IsNonDegenerate()) {
            ca.AwaitingBend = true;
            ca.Control = (ca.Start + ca.End) * 0.5f;
        } else {
            @g_Pending = null;
        }
    }
}

void HandleEraser(const vec2 &in mousePos, bool mouseDown, bool released) {
    if (mouseDown) {
        for (int i = int(g_Drawables.Length) - 1; i >= 0; i--) {
            Drawable@ d = g_Drawables[i];
            if (IsColorLocked(d.Color)) continue;
            if (d.HitTestScreen(mousePos, S_EraserRadius)) {
                if (g_SelectedDrawable !is null && d is g_SelectedDrawable) {
                    @g_SelectedDrawable = null;
                    g_DraggedHandleIndex = -1;
                }
                g_Drawables.RemoveAt(uint(i));
                ForgetHistoryFor(d);
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
        TextLabel@ t = TextLabel();
        t.Color = g_CurrentColor;
        t.Position = mousePos;
        t.Text = "";
        t.Size = S_TextSize;
        AttachWorldAnchor(t, mousePos);
        @g_Pending = t;
        g_TextInputBuffer = "";
        g_TextInputNeedsFocus = true;
        g_TextInputOpen = true;
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
    g_UndoStack.InsertLast(HistoryOp(HOP_Create, m, -1));
    ClearRedoStack();
    SaveState();
}

void HandleSelect(const vec2 &in mousePos, bool mouseDown, bool pressed, bool released) {
    if (pressed) {
        if (g_SelectedDrawable !is null) {
            array<vec2> handles = g_SelectedDrawable.GetHandlesScreen();
            for (uint i = 0; i < handles.Length; i++) {
                if (Distance(mousePos, handles[i]) <= 8.0f) {
                    g_DraggedHandleIndex = int(i);
                    g_DragLastPos = mousePos;
                    g_DragMoved = false;
                    return;
                }
            }
        }
        for (int i = int(g_Drawables.Length) - 1; i >= 0; i--) {
            Drawable@ candidate = g_Drawables[i];
            if (candidate.HitTestScreen(mousePos, 6.0f)) {
                @g_SelectedDrawable = candidate;
                @g_DraggedDrawable = candidate;
                g_DragLastPos = mousePos;
                g_DragMoved = false;
                g_DragYAxis = candidate.WorldAnchored && IsAltDown();
                return;
            }
        }
        @g_SelectedDrawable = null;
    } else if (mouseDown) {
        if (g_DraggedHandleIndex >= 0 && g_SelectedDrawable !is null) {
            g_SelectedDrawable.MoveHandleScreen(g_DraggedHandleIndex, mousePos);
            g_DragLastPos = mousePos;
            g_DragMoved = true;
        } else if (g_DraggedDrawable !is null) {
            vec2 delta = mousePos - g_DragLastPos;
            if (delta.x != 0.0f || delta.y != 0.0f) {
                if (g_DragYAxis) {
                    float mpp = WorldYPerScreenPixel(g_DraggedDrawable.WorldAnchor);
                    if (mpp != 0.0f) {
                        g_DraggedDrawable.WorldAnchor.y -= delta.y * mpp;
                        g_DragMoved = true;
                    }
                } else {
                    g_DraggedDrawable.Translate(delta);
                    g_DragMoved = true;
                }
                g_DragLastPos = mousePos;
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
        g_DragYAxis = false;
    }
}
