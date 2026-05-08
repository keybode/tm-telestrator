Source: https://openplanet.dev/docs/api

# Telestrator local Openplanet API reference

Minimal reference for the Openplanet API surface used by `main.as`. This is *not* a mirror of the upstream docs — only the namespaces, types, functions, and enum members the plugin actually touches are listed here. Each file links back to its upstream URL at the top.

## Contents

| File | Covers |
| --- | --- |
| [UI.md](UI.md) | `UI::` window, widget, input, and layout functions |
| [UI-DrawList.md](UI-DrawList.md) | `UI::DrawList@` methods (`AddLine`, `AddText`, `AddCircle`, `AddCircleFilled`) |
| [UI-Enums.md](UI-Enums.md) | `UI::Cond`, `UI::WindowFlags`, `UI::Col`, `UI::Key`, `UI::MouseButton` (used members only) |
| [Json.md](Json.md) | `Json::Object`, `Json::Array`, `Json::ToFile`, `Json::FromFile`, `Json::Value`, `Json::Type` |
| [IO.md](IO.md) | `IO::FromStorageFolder`, `IO::FileExists`, `IO::FolderExists`, `IO::CreateFolder` |
| [Math.md](Math.md) | `Math::Min`, `Math::Max`, `Math::Abs`, `Math::Clamp`, `Math::Sqrt` |
| [Time.md](Time.md) | `Time::Now` |
| [Game.md](Game.md) | `GetApp()` and the `CurrentPlayground` in-map guard |
| [Settings.md](Settings.md) | `[Setting]` attribute syntax for persisted plugin variables |
