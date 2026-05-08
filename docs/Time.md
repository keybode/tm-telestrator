Source: https://openplanet.dev/docs/api/Time

# Time namespace

```
uint64 Time::get_Now()
```
Property exposed as `Time::Now`. Gets the time (in milliseconds) since the game started. Use it to stamp `CreatedAt` on drawables and to compute fade ages: `float(Time::Now - d.CreatedAt) / 1000.0f`.
