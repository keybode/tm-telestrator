Source: https://openplanet.dev/docs/api/global

# Global game accessors

```
CGameCtnApp@ GetApp()
```
Gets the main game app object. Returns a handle to the top-level Trackmania app instance. Most game-state inspection starts here.

## CurrentPlayground (in-map guard)

`GetApp().CurrentPlayground` is non-null when the player is in a map (in-game playground), and null on menus / loading screens. Telestrator uses this as the in-map guard:

```
bool IsInMap() {
    auto app = GetApp();
    if (app is null) return false;
    return app.CurrentPlayground !is null;
}
```

The exact type and per-field documentation of `CGameCtnApp` lives under the engine class browser, not the AngelScript API namespace pages. Treat `CurrentPlayground` as "(undocumented on the API namespace page) — use `!is null` as the in-map test."
