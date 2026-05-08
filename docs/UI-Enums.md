Source: https://openplanet.dev/docs/api/UI

# UI enums (members used by Telestrator only)

Only the members `main.as` references are listed. The full enums are larger upstream.

## UI::Cond

Source: https://openplanet.dev/docs/api/UI/Cond

Conditions for `UI::SetNextWindowSize` / `UI::SetNextWindowPos`.

| Member | Value |
| --- | --- |
| `UI::Cond::FirstUseEver` | 4 |
| `UI::Cond::Appearing` | 8 |

## UI::WindowFlags

Source: https://openplanet.dev/docs/api/UI/WindowFlags

Bitwise-OR'd into the `flags` parameter of `UI::Begin`.

| Member | Value |
| --- | --- |
| `UI::WindowFlags::NoTitleBar` | 1 |
| `UI::WindowFlags::NoCollapse` | 32 |
| `UI::WindowFlags::AlwaysAutoResize` | 64 |
| `UI::WindowFlags::NoSavedSettings` | 256 |

## UI::Col

Source: https://openplanet.dev/docs/api/UI/Col

Color slots passed to `UI::PushStyleColor(Col idx, const vec4&in col)`.

| Member | Value |
| --- | --- |
| `UI::Col::Button` | 21 |
| `UI::Col::ButtonHovered` | 22 |
| `UI::Col::ButtonActive` | 23 |

## UI::Key

Source: https://openplanet.dev/docs/api/UI/Key

Keys passed to `UI::IsKeyPressed(Key key)` and `UI::IsKeyDown(Key key)`.

| Member | Value |
| --- | --- |
| `UI::Key::Enter` | 525 |
| `UI::Key::Escape` | 526 |
| `UI::Key::LeftCtrl` | 527 |
| `UI::Key::LeftShift` | 528 |
| `UI::Key::LeftAlt` | 529 |
| `UI::Key::RightCtrl` | 531 |
| `UI::Key::RightShift` | 532 |
| `UI::Key::RightAlt` | 533 |
| `UI::Key::N0` | 536 |
| `UI::Key::N1` | 537 |
| `UI::Key::N2` | 538 |
| `UI::Key::N3` | 539 |
| `UI::Key::N4` | 540 |
| `UI::Key::N5` | 541 |
| `UI::Key::N6` | 542 |
| `UI::Key::N7` | 543 |
| `UI::Key::N8` | 544 |
| `UI::Key::N9` | 545 |
| `UI::Key::A` | 546 |
| `UI::Key::B` | 547 |
| `UI::Key::C` | 548 |
| `UI::Key::D` | 549 |
| `UI::Key::E` | 550 |
| `UI::Key::F` | 551 |
| `UI::Key::G` | 552 |
| `UI::Key::H` | 553 |
| `UI::Key::I` | 554 |
| `UI::Key::J` | 555 |
| `UI::Key::K` | 556 |
| `UI::Key::L` | 557 |
| `UI::Key::M` | 558 |
| `UI::Key::N` | 559 |
| `UI::Key::O` | 560 |
| `UI::Key::P` | 561 |
| `UI::Key::Q` | 562 |
| `UI::Key::R` | 563 |
| `UI::Key::S` | 564 |
| `UI::Key::T` | 565 |
| `UI::Key::U` | 566 |
| `UI::Key::V` | 567 |
| `UI::Key::W` | 568 |
| `UI::Key::X` | 569 |
| `UI::Key::Y` | 570 |
| `UI::Key::Z` | 571 |
| `UI::Key::F1` | 572 |
| `UI::Key::F2` | 573 |
| `UI::Key::F3` | 574 |
| `UI::Key::F4` | 575 |
| `UI::Key::F5` | 576 |
| `UI::Key::F6` | 577 |
| `UI::Key::F7` | 578 |
| `UI::Key::F8` | 579 |
| `UI::Key::F9` | 580 |
| `UI::Key::F10` | 581 |
| `UI::Key::F11` | 582 |
| `UI::Key::F12` | 583 |

There is no plain `Shift` / `Ctrl` member — check both Left and Right (see `IsShiftDown` / `IsCtrlDown` in [util/helpers.as](../util/helpers.as)). The docs also expose `ModShift = 8192`, `ModCtrl = 4096`, `ModAlt = 16384` for "any of left or right" semantics, but Telestrator currently uses the explicit Left+Right form.

## UI::MouseButton

Source: https://openplanet.dev/docs/api/UI/MouseButton

Buttons passed to `UI::IsMouseDown(MouseButton button = UI::MouseButton::Left)`.

| Member | Value |
| --- | --- |
| `UI::MouseButton::Left` | 0 |
