
void RenderToolbar() {
    g_BlockDrawingThisFrame = false;

    UI::SetNextWindowSize(360, 0, UI::Cond::FirstUseEver);

    int flags =
        UI::WindowFlags::AlwaysAutoResize
        | UI::WindowFlags::NoCollapse;

    if (!UI::Begin("Telestrator", g_WindowVisible, flags)) {
        g_BlockDrawingThisFrame = true;
        UI::End();
        return;
    }

    if (!IsInMap()) {
        UI::Text("\\$888Enter a map to start drawing");
        UI::End();
        return;
    }

    g_BlockDrawingThisFrame = false;

    UI::Text(g_DrawingEnabled ? "\\$0f0Enabled" : "\\$f80Disabled");
    UI::SameLine();

    if (UI::Button(g_DrawingEnabled ? "Disable##toggle" : "Enable##toggle")) {
        g_DrawingEnabled = !g_DrawingEnabled;
    }

    UI::Separator();
    UI::Text("Tool");
    RenderToolSelector();

    UI::Separator();
    UI::Text("Brush");
    S_BrushThickness = UI::SliderFloat("Thickness", S_BrushThickness, 1.0f, 16.0f);
    S_MinPointDistance = UI::SliderFloat("Point spacing", S_MinPointDistance, 1.0f, 20.0f);
    S_EraserRadius = UI::SliderFloat("Eraser radius", S_EraserRadius, 4.0f, 40.0f);
    S_TextSize = UI::SliderFloat("Text size", S_TextSize, 12.0f, 64.0f);
    S_AutoFadeSeconds = UI::SliderFloat("Auto-fade (s)", S_AutoFadeSeconds, 0.0f, 60.0f);
    S_Dashed = UI::Checkbox("Dashed lines", S_Dashed);
    S_PolygonFill = UI::Checkbox("Polygon fill (translucent)", S_PolygonFill);
    if (g_WorldAnchorFeatureEnabled) {
        S_WorldAnchor = UI::Checkbox("World-anchor new marks", S_WorldAnchor);
        if (UI::BeginItemTooltip()) {
            UI::Text("New marks stick to the world point under the cursor (at car altitude)");
            UI::Text("instead of staying glued to the screen. Existing marks are unchanged.");
            UI::EndTooltip();
        }
    }

    UI::Separator();
    UI::Text("Palette");
    RenderPalette();

    UI::Separator();

    if (UI::Button("Undo##undo")) {
        UndoLast();
    }
    UI::SameLine();
    if (UI::Button("Redo##redo")) {
        RedoLast();
    }
    UI::SameLine();
    if (UI::Button("Clear##clear")) {
        ClearAll();
    }

    RenderSelectionEditor();

    UI::Separator();
    UI::Text("Behavior");
    S_AutoOpenOnLoad = UI::Checkbox("Open this window on startup", S_AutoOpenOnLoad);

    UI::Separator();
    UI::Text("Hotkeys");
    S_HotkeyToggle = UI::Checkbox(HotkeyKeyName(S_HotkeyToggleKey) + ": toggle drawing", S_HotkeyToggle);
    S_HotkeyUndo = UI::Checkbox(HotkeyKeyName(S_HotkeyUndoKey) + ": undo", S_HotkeyUndo);
    S_HotkeyRedo = UI::Checkbox(HotkeyKeyName(S_HotkeyRedoKey) + ": redo", S_HotkeyRedo);
    S_HotkeyClear = UI::Checkbox(HotkeyKeyName(S_HotkeyClearKey) + ": clear", S_HotkeyClear);
    UI::Text("\\$888Rebind keys in Openplanet > Settings > Telestrator > Hotkeys");
    if (UI::BeginItemTooltip()) {
        UI::Text("Hotkeys fire whenever Trackmania has focus, including while driving.");
        UI::Text("Avoid binding to keys used by your TM controls (W/A/S/D, throttle, etc.).");
        UI::EndTooltip();
    }
    UI::Separator();
    UI::Text("Modifiers (hold while drawing)");
    UI::Text("- Shift: arrow/line/measure/bracket/curve snap to 45 degrees; rect/ellipse become square/circle");
    UI::Text("- Ctrl:  rect/ellipse draw from center instead of corner");
    if (g_WorldAnchorFeatureEnabled) {
        UI::Text("- Alt + drag (Select tool): adjust a world-anchored mark's altitude");
    }
    UI::Text("- Delete (Select tool): remove the selected mark");
    UI::Text("Multi-step tools");
    UI::Text("- Polygon: click to add vertex, click first vertex (or Enter) to close, Esc to cancel");
    UI::Text("- Curve:   drag to set start+end, then move mouse to bend, click to commit, Esc to cancel");
    UI::End();
}

void RenderSelectionEditor() {
    if (g_SelectedDrawable is null) return;

    TextLabel@ selText = cast<TextLabel>(g_SelectedDrawable);
    if (selText !is null) {
        UI::Separator();
        UI::Text("Selected text");
        selText.Size = UI::SliderFloat("Size##sel-text", selText.Size, 12.0f, 64.0f);
        if (UI::IsItemDeactivated()) {
            ClearRedoStack();
            SaveState();
        }
    }
}

void RenderToolSelector() {
    if (UI::RadioButton("Pen##tool", g_CurrentTool == Tool::Pen)) {
        SetTool(Tool::Pen);
    }
    UI::SameLine();
    if (UI::RadioButton("Highlight##tool", g_CurrentTool == Tool::Highlighter)) {
        SetTool(Tool::Highlighter);
    }
    UI::SameLine();
    if (UI::RadioButton("Arrow##tool", g_CurrentTool == Tool::Arrow)) {
        SetTool(Tool::Arrow);
    }
    UI::SameLine();
    if (UI::RadioButton("Line##tool", g_CurrentTool == Tool::Line)) {
        SetTool(Tool::Line);
    }

    if (UI::RadioButton("Rect##tool", g_CurrentTool == Tool::Rect)) {
        SetTool(Tool::Rect);
    }
    UI::SameLine();
    if (UI::RadioButton("Circle##tool", g_CurrentTool == Tool::Circle)) {
        SetTool(Tool::Circle);
    }
    UI::SameLine();
    if (UI::RadioButton("Ellipse##tool", g_CurrentTool == Tool::Ellipse)) {
        SetTool(Tool::Ellipse);
    }

    if (UI::RadioButton("Text##tool", g_CurrentTool == Tool::Text)) {
        SetTool(Tool::Text);
    }
    UI::SameLine();
    if (UI::RadioButton("Marker##tool", g_CurrentTool == Tool::Marker)) {
        SetTool(Tool::Marker);
    }

    if (UI::RadioButton("Measure##tool", g_CurrentTool == Tool::Measurement)) {
        SetTool(Tool::Measurement);
    }
    UI::SameLine();
    if (UI::RadioButton("Bracket##tool", g_CurrentTool == Tool::Bracket)) {
        SetTool(Tool::Bracket);
    }
    UI::SameLine();
    if (UI::RadioButton("Curve##tool", g_CurrentTool == Tool::CurvedArrow)) {
        SetTool(Tool::CurvedArrow);
    }
    UI::SameLine();
    if (UI::RadioButton("Polygon##tool", g_CurrentTool == Tool::Polygon)) {
        SetTool(Tool::Polygon);
    }

    if (UI::RadioButton("Eraser##tool", g_CurrentTool == Tool::Eraser)) {
        SetTool(Tool::Eraser);
    }
    UI::SameLine();
    if (UI::RadioButton("Select##tool", g_CurrentTool == Tool::Select)) {
        SetTool(Tool::Select);
    }
}

void SetTool(Tool t) {
    if (g_CurrentTool == t) return;
    @g_ActiveStroke = null;
    @g_Pending = null;
    @g_DraggedDrawable = null;
    g_DraggedHandleIndex = -1;
    g_DragMoved = false;
    g_DragYAxis = false;
    if (t != Tool::Select) @g_SelectedDrawable = null;
    g_CurrentTool = t;
}

void RenderPalette() {
    int picked = RenderPaletteRow("", "Custom (use the picker below)", g_CurrentColor);
    if (picked >= 0) {
        g_CurrentColor = (picked < int(g_Palette.Length)) ? g_Palette[picked].Color : S_CustomColor;
        SaveState();
    }

    vec4 newCustom = UI::InputColor4("Custom##picker", S_CustomColor);
    if (!ColorsEqual(newCustom, S_CustomColor)) {
        if (ColorsEqual(g_CurrentColor, S_CustomColor)) {
            g_CurrentColor = newCustom;
        }
        S_CustomColor = newCustom;
    }

    UI::Text("Lock from eraser:");
    S_LockRed = UI::Checkbox("R##lock", S_LockRed);
    UI::SameLine();
    S_LockGreen = UI::Checkbox("G##lock", S_LockGreen);
    UI::SameLine();
    S_LockBlue = UI::Checkbox("B##lock", S_LockBlue);
    UI::SameLine();
    S_LockYellow = UI::Checkbox("Y##lock", S_LockYellow);
    UI::SameLine();
    S_LockCustom = UI::Checkbox("C##lock", S_LockCustom);
}

int RenderPaletteRow(const string &in idSuffix, const string &in customLabel, const vec4 &in current) {
    int picked = -1;
    for (uint i = 0; i < g_Palette.Length; i++) {
        if (RenderColorSwatch(g_Palette[i].Id + idSuffix, g_Palette[i].Label, g_Palette[i].Color, current)) {
            picked = int(i);
        }
        UI::SameLine();
    }
    if (RenderColorSwatch("custom" + idSuffix, customLabel, S_CustomColor, current)) {
        picked = int(g_Palette.Length);
    }
    return picked;
}

bool RenderColorSwatch(const string &in id, const string &in label, const vec4 &in color, const vec4 &in current) {
    bool isSelected = ColorsEqual(current, color);

    UI::PushStyleColor(UI::Col::Button, color);
    UI::PushStyleColor(UI::Col::ButtonHovered, color);
    UI::PushStyleColor(UI::Col::ButtonActive, color);

    vec2 size = isSelected ? vec2(30, 30) : vec2(24, 24);
    bool clicked = UI::Button("##" + id, size);

    UI::PopStyleColor(3);

    if (UI::BeginItemTooltip()) {
        UI::Text(label);
        UI::EndTooltip();
    }

    return clicked;
}

void RenderTextInput() {
    if (!g_TextInputOpen) return;
    TextLabel@ pending = cast<TextLabel>(g_Pending);
    if (pending is null) {
        CloseTextInput();
        return;
    }

    g_BlockDrawingThisFrame = true;

    UI::SetNextWindowPos(int(pending.Position.x), int(pending.Position.y), UI::Cond::Appearing);

    int flags =
        UI::WindowFlags::AlwaysAutoResize
        | UI::WindowFlags::NoCollapse
        | UI::WindowFlags::NoTitleBar
        | UI::WindowFlags::NoSavedSettings;

    bool stillOpen = true;
    if (UI::Begin("Telestrator##text", stillOpen, flags)) {
        if (g_TextInputNeedsFocus) {
            UI::SetKeyboardFocusHere();
            g_TextInputNeedsFocus = false;
        }
        g_TextInputBuffer = UI::InputText("##textinput", g_TextInputBuffer);

        pending.Size = UI::SliderFloat("Size##new-text", pending.Size, 12.0f, 64.0f);
        int pickedTx = RenderPaletteRow("-tx", "Custom", pending.Color);
        if (pickedTx >= 0) {
            pending.Color = (pickedTx < int(g_Palette.Length)) ? g_Palette[pickedTx].Color : S_CustomColor;
        }

        bool commit = UI::IsKeyPressed(UI::Key::Enter);
        bool cancel = UI::IsKeyPressed(UI::Key::Escape);

        if (UI::Button("Add")) commit = true;
        UI::SameLine();
        if (UI::Button("Cancel")) cancel = true;

        UI::End();

        if (cancel) {
            CloseTextInput();
            return;
        }
        if (commit) {
            CommitTextInput();
            return;
        }
    } else {
        UI::End();
    }

    if (!stillOpen) {
        CloseTextInput();
    }
}

void CommitTextInput() {
    TextLabel@ t = cast<TextLabel>(g_Pending);
    if (t !is null && g_TextInputBuffer.Length > 0) {
        t.Text = g_TextInputBuffer;
        CommitPending(t);
    } else {
        @g_Pending = null;
    }
    CloseTextInput();
}

void CloseTextInput() {
    g_TextInputOpen = false;
    g_TextInputNeedsFocus = false;
    g_TextInputBuffer = "";
    if (cast<TextLabel>(g_Pending) !is null) @g_Pending = null;
    if (g_CurrentTool == Tool::Text) g_CurrentTool = Tool::Pen;
}
