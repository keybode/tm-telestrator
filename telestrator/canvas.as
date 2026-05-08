// Canvas rendering. The per-frame Render() callback in main.as calls DrawAll() before
// HandleDrawingInput() so a freshly-finished mark shows up the same frame, and
// DrawCursorPreview() last so the cursor sits on top of everything.
//
// Drawing happens on UI::GetBackgroundDrawList(), which paints across the whole screen,
// beneath ImGui windows but above the game.

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

// Renders a drawable, applying its world anchor as a rigid screen-space translate. The
// translate-then-untranslate is mutate-and-restore (vs. passing offset into Draw), which
// is safe because per-frame Render calls DrawAll fully before HandleDrawingInput observes
// any state. Subpixel float-rounding is the residual cost; visually irrelevant.
void DrawWithAnchor(Drawable@ d, UI::DrawList@ drawList, float alpha) {
    if (!d.WorldAnchored) {
        d.Draw(drawList, alpha);
        return;
    }
    if (!d.IsAnchorVisible()) return;
    vec2 offset = d.CurrentOffset();
    if (offset.x == 0.0f && offset.y == 0.0f) {
        d.Draw(drawList, alpha);
        return;
    }
    d.Translate(offset);
    d.Draw(drawList, alpha);
    d.Translate(vec2(-offset.x, -offset.y));
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
                if (g_Drawables[i].HitTestScreen(mousePos, 6.0f)) {
                    @hover = g_Drawables[i];
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
    array<vec2> handles = d.GetHandlesScreen();
    if (handles.Length == 0) return;
    vec4 fill = vec4(1.0f, 1.0f, 1.0f, 0.95f);
    vec4 border = vec4(0.05f, 0.05f, 0.05f, 0.9f);
    for (uint i = 0; i < handles.Length; i++) {
        drawList.AddCircleFilled(handles[i], 5.0f, fill);
        drawList.AddCircle(handles[i], 5.5f, border, 0, 1.5f);
    }
}

void DrawSelectionHighlight(UI::DrawList@ drawList, Drawable@ d) {
    vec2 boundsMin, boundsMax;
    d.BoundsScreen(boundsMin, boundsMax);
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
