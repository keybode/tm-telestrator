Source: https://openplanet.dev/docs/api/UI/DrawList

# UI::DrawList

Handle returned by `UI::GetBackgroundDrawList()` (and other draw-list getters). Drawing happens in screen space.

## Methods used by Telestrator

```
void AddLine(const vec2&in a, const vec2&in b, const vec4&in color, float thickness = 1.0f)
```
Draws a line between `a` and `b`.

```
void AddText(const vec2&in pos, const vec4&in color, const string&in str, UI::Font@ font = null, float size = 0.0f, float wrapWidth = 0.0f)
```
Draws text at `pos`. Pass `null` for `font` to use the default font; `size = 0.0f` uses the font's default size.

```
void AddCircle(const vec2&in pos, float radius, const vec4&in color, int segments = 0, float thickness = 1.0f)
```
Draws a border circle (outline only). `segments = 0` lets imgui auto-pick a segment count.

```
void AddCircleFilled(const vec2&in pos, float radius, const vec4&in color, int segments = 0)
```
Draws a filled circle.

```
void AddQuadFilled(const vec2&in topLeft, const vec2&in topRight, const vec2&in bottomRight, const vec2&in bottomLeft, const vec4&in color)
```
Draws a filled quad.

```
void AddQuadFilled(const vec2&in p1, const vec2&in p2, const vec2&in p3, const vec4&in color)
```
Draws a filled triangle. The 3-point overload is the only filled-triangle primitive Openplanet exposes — there is no `AddTriangleFilled` or `AddConvexPolyFilled` in the binding (verified by 404 on those URLs). For arbitrary convex-polygon fill, fan-triangulate from one vertex and call this per triangle.
