Source: https://openplanet.dev/docs/reference/settings

# [Setting] attribute

Persistent plugin settings are declared as global variables decorated with a `[Setting ...]` attribute. Openplanet auto-saves them across sessions and renders them in the plugin's Settings dialog.

## Basic syntax

```
[Setting name="Something"]
bool Setting_Something;
```

## Supported types

`bool`, `int` (incl. `int8` / `int16` / `int32`), `uint` (incl. `uint8` / `uint16` / `uint32`), `float`, `double`, `string`, `vec2`, `vec3`, `vec4`, `int2`, `int3`, `nat2`, `nat3`, `quat`, and any user-defined `enum`.

## Universal attributes (any type)

| Attribute | Purpose |
| --- | --- |
| `name` | Display label in the settings dialog. |
| `description` | Tooltip text shown via the question-mark icon. |
| `category` | Groups settings into tabs. |
| `hidden` | Takes no value. Marks the setting so it will not be displayed in the Openplanet settings dialog. |
| `if` | Runtime conditional expression for visibility. |
| `enableif` | Runtime conditional expression for enabled state. |
| `onchange` | Callback function invoked when the value changes. |
| `beforerender` / `afterrender` | Render-lifecycle callbacks. |

## Numeric attributes (`int`, `uint`, `float`, `double`)

| Attribute | Purpose |
| --- | --- |
| `min`, `max` | Range constraints. Specifying both produces a slider UI. |
| `drag` | Enables a draggable input instead of plain text entry. |
| `step` | Increment size for drag/input fields. |

## String-specific attributes

| Attribute | Purpose |
| --- | --- |
| `max` | Maximum character length. |
| `multiline` | Enable multi-line input field. |
| `password` | Mask characters with asterisks. |

## Vector-specific attributes (`vec3`, `vec4`)

| Attribute | Purpose |
| --- | --- |
| `color` | Renders a color picker instead of numeric inputs. |

## Examples (as used by Telestrator)

```
[Setting name="Brush thickness" min=1 max=16]
float S_BrushThickness = 4.0f;

[Setting name="Auto-fade seconds (0 = off)" min=0 max=60]
float S_AutoFadeSeconds = 0.0f;
```

Default values are not persisted while unchanged from their declared default.
