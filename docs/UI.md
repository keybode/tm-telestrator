Source: https://openplanet.dev/docs/api/UI

# UI namespace

Functions used by `main.as`. Each function links to its own page upstream (e.g. `https://openplanet.dev/docs/api/UI/Begin`).

## Draw lists

```
DrawList@ UI::GetBackgroundDrawList()
```
Get background draw list. (Note: You might want to prefer using the Nvg API!) See [UI-DrawList.md](UI-DrawList.md) for the methods on the returned handle.

## Windows

```
bool UI::Begin(const string&in title, int flags = UI::GetDefaultWindowFlags())
bool UI::Begin(const string&in title, bool&out open, int flags = UI::GetDefaultWindowFlags())
```
Begins an imgui window. The 2-arg form takes a `bool&out open` so the user can close the window via the title-bar X.

```
void UI::End()
```
Ends an imgui window. Must always be called even if `Begin` returns false.

```
void UI::SetNextWindowSize(int w, int h, Cond cond = UI::Cond::Appearing)
```
Sets the size for the next window created with `UI::Begin()`.

```
void UI::SetNextWindowPos(int x, int y, Cond cond = UI::Cond::Appearing, float pivotx = 0.0f, float pivoty = 0.0f)
```
Sets the position for the next window created with `UI::Begin()`.

## Layout and basic widgets

```
void UI::Text(const string&in text, int length = -1)
```
Simple text label with an optional length. Supports inline `\$RGB` color tags in the string (e.g. `"\\$0f0Enabled"`).

```
bool UI::Button(const string&in label, const vec2&in size = vec2())
```
Clickable button that returns true if clicked.

```
bool UI::MenuItem(const string&in label, const string&in shortcut = "", bool selected = false, bool enabled = true)
```
Clickable menu item that returns true when activated.

```
void UI::SameLine(float offset_from_start_x = 0.0f, float spacing = -1.0f)
```
Marks the next control to be drawn on the same line as the last one.

```
void UI::Separator()
void UI::Separator(int flags, float thickness = 1.0f)
```
Separator line.

```
bool UI::RadioButton(const string&in label, bool active)
```
Radio button that returns true if pressed.

```
float UI::SliderFloat(const string&in label, float num, float min, float max, const string&in format = "%.3f", int flags = UI::SliderFlags::None)
```
Slider for floats that returns the new value.

```
bool UI::Checkbox(const string&in label, bool value)
```
Checkbox. For value, pass the current value. The return value is the new value.

```
vec4 UI::InputColor4(const string&in label, const vec4&in color, int flags = UI::ColorEditFlags::None)
```
Input color. Returns the new value.

## Input text

```
string UI::InputText(const string&in label, string str, int flags = UI::InputTextFlags::None, InputTextCallback@ callback = null)
string UI::InputText(const string&in label, string str, bool&out changed, int flags = UI::InputTextFlags::None, InputTextCallback@ callback = null)
```
Input text that returns the new value.

```
void UI::SetKeyboardFocusHere(int offset = 0)
```
Sets the keyboard focus on the next widget. Call before the widget you want to focus.

## Style stack

```
void UI::PushStyleColor(Col idx, const vec4&in col)
```
Temporarily pushes a color change for the next widgets. See `UI::Col` in [UI-Enums.md](UI-Enums.md).

```
void UI::PopStyleColor(int count = 1)
```
Pops one or more temporary color changes.

## Tooltips

```
bool UI::BeginItemTooltip()
```
Begins a tooltip when the last item has been hovered.

```
void UI::EndTooltip()
```
Ends a tooltip dialog.

## Input state

```
bool UI::IsKeyPressed(Key key)
```
Returns true if the given key was pressed. See `UI::Key` in [UI-Enums.md](UI-Enums.md).

```
bool UI::IsKeyDown(Key key)
```
Returns true if the given key is currently held. Use this for modifier-key checks during a drag (Shift / Ctrl), not `IsKeyPressed` which only fires on the transition.

```
bool UI::IsMouseDown(MouseButton button = UI::MouseButton::Left)
```
Returns true if the given mouse button is down.

```
vec2 UI::GetMousePos()
```
Get the current position of the mouse relative to the top-left corner of the window.

```
bool UI::WantCaptureMouse()
```
Returns true when ImGui will consume the mouse input — e.g., the cursor is over any ImGui window (this plugin's, another plugin's, or Openplanet's own UI) or an ImGui widget is active. Use this in input gates to suppress canvas/world-side handling so a click on a UI panel doesn't also fire the underlying tool.

## Text measurement

```
vec2 UI::MeasureString(const string&in str, Font@ font = null, float size = 0.0f, float wrapWidth = 0.0f)
```
Calculates the size that a string will be drawn at.
