// Plugin settings

[Setting name="Brush thickness" min=1 max=16]
float S_BrushThickness = 4.0f;

[Setting name="Minimum point spacing" min=1 max=20]
float S_MinPointDistance = 3.0f;

[Setting name="Eraser radius" min=4 max=40]
float S_EraserRadius = 12.0f;

[Setting name="Text size" min=12 max=64]
float S_TextSize = 24.0f;

[Setting name="Auto-fade seconds (0 = off)" min=0 max=60]
float S_AutoFadeSeconds = 0.0f;

[Setting name="Dashed lines (pen / arrow / line)"]
bool S_Dashed = false;

[Setting name="Polygon fill (translucent)"]
bool S_PolygonFill = false;

[Setting name="World-anchor new marks"]
bool S_WorldAnchor = false;

[Setting name="Open toolbar automatically on startup"]
bool S_AutoOpenOnLoad = false;

[Setting name="Custom palette color" color]
vec4 S_CustomColor = vec4(0.85f, 0.55f, 0.95f, 1.0f);

enum HotkeyKey {
    F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12,
    A, B, C, D, E, F, G, H, I, J, K, L, M,
    N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
    N0, N1, N2, N3, N4, N5, N6, N7, N8, N9
}

[Setting category="Hotkeys" name="Toggle drawing — enabled"]
bool S_HotkeyToggle = true;
[Setting category="Hotkeys" name="Toggle drawing — key" description="Fires whenever Trackmania has focus, including while driving. Avoid keys used by your TM controls (W/A/S/D, throttle, etc.)."]
HotkeyKey S_HotkeyToggleKey = HotkeyKey::F7;

[Setting category="Hotkeys" name="Undo — enabled"]
bool S_HotkeyUndo = true;
[Setting category="Hotkeys" name="Undo — key" description="Fires whenever Trackmania has focus, including while driving. Avoid keys used by your TM controls (W/A/S/D, throttle, etc.)."]
HotkeyKey S_HotkeyUndoKey = HotkeyKey::Z;

[Setting category="Hotkeys" name="Redo — enabled"]
bool S_HotkeyRedo = true;
[Setting category="Hotkeys" name="Redo — key" description="Fires whenever Trackmania has focus, including while driving. Avoid keys used by your TM controls (W/A/S/D, throttle, etc.)."]
HotkeyKey S_HotkeyRedoKey = HotkeyKey::Y;

[Setting category="Hotkeys" name="Clear — enabled"]
bool S_HotkeyClear = true;
[Setting category="Hotkeys" name="Clear — key" description="Fires whenever Trackmania has focus, including while driving. Avoid keys used by your TM controls (W/A/S/D, throttle, etc.)."]
HotkeyKey S_HotkeyClearKey = HotkeyKey::C;

[Setting name="Lock Brake (red) from eraser"]
bool S_LockRed = false;
[Setting name="Lock Accel (green) from eraser"]
bool S_LockGreen = false;
[Setting name="Lock Drift (blue) from eraser"]
bool S_LockBlue = false;
[Setting name="Lock Release (yellow) from eraser"]
bool S_LockYellow = false;
[Setting name="Lock Custom from eraser"]
bool S_LockCustom = false;
