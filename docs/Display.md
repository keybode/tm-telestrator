Source: https://openplanet.dev/docs/api/Display

# Display

Game render-target dimensions (not the OS window). Used in
[util/projection.as](../util/projection.as) to convert mouse pixel coordinates to NDC for
inverse projection.

```
vec2 Display::GetSize()
int Display::GetWidth()
int Display::GetHeight()
```

The camera plugin's `Main.as` (https://raw.githubusercontent.com/openplanet-nl/camera/master/Main.as)
uses `Display::GetSize()` as the canonical viewport-pixels source, then crops by the active
camera's `DrawRectMin`/`DrawRectMax` for split-screen / letterbox correctness. Telestrator
does not handle split-screen and assumes the full display is the draw rect.
