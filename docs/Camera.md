Source: https://openplanet.dev/docs/reference/camera

# Camera dependency plugin

Provided by `openplanet-nl/camera` (https://github.com/openplanet-nl/camera). Marked
`essential = true` in its info.toml so it ships with Openplanet — no bundling, just declare
in `info.toml`:

```
[script]
dependencies = [ "Camera" ]
```

Telestrator uses this for forward projection (world → screen) and rebuilds the camera's
view-projection matrix from `GetCurrent()` to invert it for the screen → world direction.

## Functions used

```
import vec2 ToScreenSpace(const vec3 &in pos) from "Camera";
```
Projects a 3D world point to screen-space pixels using the current camera. Behavior at
points behind the camera is undefined — guard with `IsBehind`.

```
import bool IsBehind(const vec3 &in pos) from "Camera";
```
True if `pos` is behind the camera. Use this before calling `ToScreenSpace` if the point
might be behind.

```
import CHmsCamera@ GetCurrent() from "Camera";
```
Returns the active camera or null. Properties Telestrator reads off the result:
`Fov` (radians), `Width_Height` (aspect ratio), `NearZ`, `FarZ`, `Location` (iso4 — the
camera's world transform).

The plugin's own `Impl.as` (https://raw.githubusercontent.com/openplanet-nl/camera/master/Impl.as)
shows how `ToScreenSpace` is composed; Telestrator replicates that composition in
[util/projection.as](../util/projection.as) so it can invert it.

## Reference page

https://openplanet.dev/docs/reference/camera additionally documents:

```
import vec3 ToScreen(const vec3 &in pos) from "Camera";
import mat4 GetProjectionMatrix() from "Camera";
```

Not currently used by Telestrator. The reference page also lists `GetCurrentPosition()`,
`FindCurrent()`, `SetEditorOrbitalTarget()` — see upstream for signatures.
