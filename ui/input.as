
void HandleHotkeys() {
    if (g_TextInputOpen) return;

    if (S_HotkeyToggle && UI::IsKeyPressed(HotkeyKeyToUIKey(S_HotkeyToggleKey))) {
        g_DrawingEnabled = !g_DrawingEnabled;
    }
    if (S_HotkeyUndo && UI::IsKeyPressed(HotkeyKeyToUIKey(S_HotkeyUndoKey))) {
        UndoLast();
    }
    if (S_HotkeyRedo && UI::IsKeyPressed(HotkeyKeyToUIKey(S_HotkeyRedoKey))) {
        RedoLast();
    }
    if (S_HotkeyClear && UI::IsKeyPressed(HotkeyKeyToUIKey(S_HotkeyClearKey))) {
        ClearAll();
    }
    if (g_SelectedDrawable !is null && UI::IsKeyPressed(UI::Key::Delete)) {
        DeleteSelected();
    }
}

void HandleDrawingInput() {
    bool mouseDown = UI::IsMouseDown(UI::MouseButton::Left);
    vec2 mousePos = UI::GetMousePos();

    if (!CanDraw()) {
        if (!mouseDown) {
            CancelInFlight();
        }
        g_LastMouseDown = mouseDown;
        return;
    }

    bool mousePressed = mouseDown && !g_LastMouseDown;
    bool mouseReleased = !mouseDown && g_LastMouseDown;

    switch (g_CurrentTool) {
        case Tool::Pen:
            HandlePen(mousePos, mouseDown, mousePressed, mouseReleased);
            break;
        case Tool::Highlighter:
            HandleHighlighter(mousePos, mouseDown, mousePressed, mouseReleased);
            break;
        case Tool::Arrow:
            HandleArrow(mousePos, mouseDown, mousePressed, mouseReleased);
            break;
        case Tool::Line:
            HandleLine(mousePos, mouseDown, mousePressed, mouseReleased);
            break;
        case Tool::Rect:
            HandleRect(mousePos, mouseDown, mousePressed, mouseReleased);
            break;
        case Tool::Circle:
            HandleCircle(mousePos, mouseDown, mousePressed, mouseReleased);
            break;
        case Tool::Ellipse:
            HandleEllipse(mousePos, mouseDown, mousePressed, mouseReleased);
            break;
        case Tool::Measurement:
            HandleMeasurement(mousePos, mouseDown, mousePressed, mouseReleased);
            break;
        case Tool::Bracket:
            HandleBracket(mousePos, mouseDown, mousePressed, mouseReleased);
            break;
        case Tool::Polygon:
            HandlePolygon(mousePos, mousePressed);
            break;
        case Tool::CurvedArrow:
            HandleCurvedArrow(mousePos, mouseDown, mousePressed, mouseReleased);
            break;
        case Tool::Eraser:
            HandleEraser(mousePos, mouseDown, mouseReleased);
            break;
        case Tool::Text:
            HandleText(mousePos, mousePressed);
            break;
        case Tool::Marker:
            HandleMarker(mousePos, mousePressed);
            break;
        case Tool::Select:
            HandleSelect(mousePos, mouseDown, mousePressed, mouseReleased);
            break;
    }

    g_LastMouseDown = mouseDown;
}

void CancelInFlight() {
    if (g_TextInputOpen) return;
    @g_ActiveStroke = null;
    @g_Pending = null;
    @g_DraggedDrawable = null;
    g_DraggedHandleIndex = -1;
    g_DragMoved = false;
    g_DragYAxis = false;
}

bool CanDraw() {
    if (!g_DrawingEnabled) return false;
    if (g_BlockDrawingThisFrame) return false;
    if (UI::WantCaptureMouse()) return false;
    return true;
}
