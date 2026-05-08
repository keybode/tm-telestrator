Sources:
- https://openplanet.dev/docs/api/mat4 (mat4 namespace, static factories)
- https://openplanet.dev/docs/api/global/mat4 (mat4 class)
- https://openplanet.dev/docs/api/global/mat4/opMul (mat4 multiplication overloads)
- https://openplanet.dev/docs/api/mat4/Perspective (mat4::Perspective signature)
- https://openplanet.dev/docs/api/global/vec4 (vec4 class)
- https://openplanet.dev/docs/api/global/iso4 (iso4 class)

# mat4, vec4, iso4

Used in [util/projection.as](../util/projection.as) to rebuild the camera view-projection
matrix and invert it for screen → world raycasting.

## mat4 statics (namespace)

```
mat4 mat4::Identity()
mat4 mat4::Translate(const vec3 &in v)
mat4 mat4::Rotate(float angle, const vec3 &in dir)
mat4 mat4::Scale(const vec3 &in scale)
mat4 mat4::Scale(float scale)
mat4 mat4::Perspective(float yFov, float aspect, float nearZ, float farZ)
mat4 mat4::Inverse(const mat4 &in)
```

## mat4 instance

Constructors used: `mat4()`, `mat4(const iso4 &in)` (lossless: missing column becomes
`(0,0,0,1)`).

Multiplication overloads (https://openplanet.dev/docs/api/global/mat4/opMul):

```
mat4 opMul(const mat4 &in) const          // mat4 * mat4 -> mat4
vec4 opMul(const vec3 &in) const          // mat4 * vec3 -> vec4 (implicit w = 1)
vec4 opMul(const vec4 &in) const          // mat4 * vec4 -> vec4
```

16 element accessors as `float` getters: `xx xy xz xw  yx yy yz yw  zx zy zz zw  tx ty tz tw`.

## vec4

Fields: `float x, y, z, w`.

Constructors: `vec4()`, `vec4(float scalar)`, `vec4(float x, float y, float z, float w)`,
`vec4(const vec3 &in xyz, float w)`, `vec4(const vec2 &in xy, const vec2 &in zw)`.

Operators with `vec4`: `opAdd opSub opMul opDiv` (componentwise, return `vec4`). Same with
`float` operand. Swizzles `.xy`, `.xyz` are used in the camera plugin's published source
and are supported by precedent (the doc only lists the four scalar fields).

## iso4

Described as "a matrix with 4 rows and 3 columns" (rigid motion: 3×3 basis + 3-vector
translation). Properties (all `float` getters): `xx xy xz  yx yy yz  zx zy zz  tx ty tz`.

Constructors: `iso4()`, `iso4(const mat4 &in)`. Methods: `opEquals`, `Translate(float, float, float)`.

In Telestrator we read `iso4.tx/ty/tz` for camera position and pass the iso4 to
`mat4(iso4)` for the rotation+translation conversion (see the camera plugin's recipe in
its `Impl.as`).
