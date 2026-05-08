Source: https://openplanet.dev/docs/api/Math

# Math namespace

All overloads listed here are the int and float forms. The docs also expose double overloads for some of these; consult upstream if you need them.

```
int   Math::Min(int x, int y)
float Math::Min(float x, float y)
```
Returns `x` or `y`, whichever is lower.

```
int   Math::Max(int x, int y)
float Math::Max(float x, float y)
```
Returns `x` or `y`, whichever is higher.

```
int   Math::Abs(int i)
float Math::Abs(float f)
```
Returns the absolute value.

```
int   Math::Clamp(int x, int min, int max)
float Math::Clamp(float x, float min, float max)
```
Clamps the value `x` between `min` and `max`. Throws an exception when `min` is higher than `max`.

```
float Math::Sqrt(float f)
```
Returns the square root of `f`.

```
float Math::Cos(float f)
```
Returns the cosine of `f` (radians).

```
float Math::Sin(float f)
```
Returns the sine of `f` (radians).

```
float Math::Floor(float f)
```
Returns the largest integer (as a float) less than or equal to `f`.

```
float Math::PI
```
Pi as a float.

```
float Math::Atan2(float y, float x)
```
Returns the four-quadrant arctangent of `y / x` (radians, in `(-π, π]`).
