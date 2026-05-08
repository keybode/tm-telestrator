// Dashed-line helper. `phase` is the starting dash offset; the returned value is the offset
// after this segment, so callers drawing multi-segment paths can chain it call-to-call and
// avoid resetting the dash pattern at every vertex. AngelScript doesn't permit `&inout` on
// primitive types, hence the return-value plumbing.
float DrawDashedSegment(UI::DrawList@ drawList, const vec2 &in a, const vec2 &in b, const vec4 &in c, float thickness, float phase) {
    float dashLen = Math::Max(thickness * 3.0f, 6.0f);
    float gapLen = dashLen * 0.6f;
    float cycle = dashLen + gapLen;

    vec2 d = b - a;
    float len = Math::Sqrt(d.x * d.x + d.y * d.y);
    if (len < 0.01f) return phase;
    vec2 unit = vec2(d.x / len, d.y / len);

    float traveled = 0.0f;
    while (traveled < len) {
        float pos = phase + traveled;
        float withinCycle = pos - Math::Floor(pos / cycle) * cycle;
        bool inDash = withinCycle < dashLen;
        float remaining = (inDash ? dashLen : cycle) - withinCycle;
        float step = Math::Min(remaining, len - traveled);
        if (inDash) {
            vec2 p1 = a + unit * traveled;
            vec2 p2 = a + unit * (traveled + step);
            drawList.AddLine(p1, p2, c, thickness);
        }
        traveled += step;
    }
    return phase + len;
}

float Distance(const vec2 &in a, const vec2 &in b) {
    vec2 d = b - a;
    return Math::Sqrt(d.x * d.x + d.y * d.y);
}

float PointToSegmentDistance(const vec2 &in p, const vec2 &in a, const vec2 &in b) {
    vec2 ab = b - a;
    float lenSq = ab.x * ab.x + ab.y * ab.y;
    if (lenSq < 0.0001f) return Distance(p, a);
    float t = ((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / lenSq;
    t = Math::Clamp(t, 0.0f, 1.0f);
    vec2 proj = vec2(a.x + ab.x * t, a.y + ab.y * t);
    return Distance(p, proj);
}

bool IsInMap() {
    auto app = GetApp();
    if (app is null) return false;
    return app.CurrentPlayground !is null;
}

bool ColorsEqual(const vec4 &in a, const vec4 &in b) {
    return Math::Abs(a.x - b.x) < 0.001f
        && Math::Abs(a.y - b.y) < 0.001f
        && Math::Abs(a.z - b.z) < 0.001f
        && Math::Abs(a.w - b.w) < 0.001f;
}

// RGB-only equality. Used for layer-lock matching so highlighter strokes (which dim the alpha
// of the current color) still match against their source palette entry.
bool ColorsEqualRGB(const vec4 &in a, const vec4 &in b) {
    return Math::Abs(a.x - b.x) < 0.001f
        && Math::Abs(a.y - b.y) < 0.001f
        && Math::Abs(a.z - b.z) < 0.001f;
}

bool IsShiftDown() {
    return UI::IsKeyDown(UI::Key::LeftShift) || UI::IsKeyDown(UI::Key::RightShift);
}

bool IsCtrlDown() {
    return UI::IsKeyDown(UI::Key::LeftCtrl) || UI::IsKeyDown(UI::Key::RightCtrl);
}

bool IsAltDown() {
    return UI::IsKeyDown(UI::Key::LeftAlt) || UI::IsKeyDown(UI::Key::RightAlt);
}

// Snaps the line `origin -> target` to the nearest multiple of `angleStep` radians,
// preserving the original distance from origin.
vec2 ConstrainAngle(const vec2 &in origin, const vec2 &in target, float angleStep) {
    vec2 d = target - origin;
    float len = Math::Sqrt(d.x * d.x + d.y * d.y);
    if (len < 0.01f) return target;
    float angle = Math::Atan2(d.y, d.x);
    float snapped = Math::Floor((angle / angleStep) + 0.5f) * angleStep;
    return vec2(origin.x + Math::Cos(snapped) * len, origin.y + Math::Sin(snapped) * len);
}

// Returns `target` snapped so the bounding box from `anchor` is square (equal width/height).
// The longer drag axis wins; the shorter axis grows to match it. Sign is preserved per axis.
vec2 ConstrainSquare(const vec2 &in anchor, const vec2 &in target) {
    float dx = target.x - anchor.x;
    float dy = target.y - anchor.y;
    float m = Math::Max(Math::Abs(dx), Math::Abs(dy));
    float sx = dx >= 0.0f ? 1.0f : -1.0f;
    float sy = dy >= 0.0f ? 1.0f : -1.0f;
    return vec2(anchor.x + sx * m, anchor.y + sy * m);
}

// Draws an arrowhead V at `tip` pointing along `unit` (the unit vector from base to tip).
// Shared by Arrow and CurvedArrow so the head geometry stays consistent.
void DrawArrowhead(UI::DrawList@ drawList, const vec2 &in tip, const vec2 &in unit, float thickness, const vec4 &in c) {
    vec2 perp = vec2(-unit.y, unit.x);
    float headSize = Math::Max(10.0f, thickness * 3.0f);
    vec2 base = tip - unit * headSize;
    vec2 left = base + perp * headSize * 0.5f;
    vec2 right = base - perp * headSize * 0.5f;
    drawList.AddLine(tip, left, c, thickness);
    drawList.AddLine(tip, right, c, thickness);
}

// Twice the signed area of triangle (a, b, c). Sign indicates winding direction; absolute value
// is twice the geometric area. Used for ear-clipping convexity tests and point-in-triangle.
float TriangleSignedArea2(const vec2 &in a, const vec2 &in b, const vec2 &in c) {
    return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
}

// Inclusive point-in-triangle test. Vertices may be wound either way.
bool PointInTriangle(const vec2 &in p, const vec2 &in a, const vec2 &in b, const vec2 &in c) {
    float d1 = TriangleSignedArea2(p, a, b);
    float d2 = TriangleSignedArea2(p, b, c);
    float d3 = TriangleSignedArea2(p, c, a);
    bool hasNeg = (d1 < 0.0f) || (d2 < 0.0f) || (d3 < 0.0f);
    bool hasPos = (d1 > 0.0f) || (d2 > 0.0f) || (d3 > 0.0f);
    return !(hasNeg && hasPos);
}

// Ear-clipping triangulation of a simple polygon. Handles convex AND concave shapes correctly;
// self-intersecting or otherwise degenerate inputs fall back to fan triangulation from vertex 0
// (visually wrong but bounded). Returns a flat array where every consecutive triple of vec2s
// is one triangle. Empty array if input has fewer than 3 vertices.
array<vec2> TriangulatePolygon(const array<vec2> &in pts) {
    array<vec2> outTris;
    if (pts.Length < 3) return outTris;
    if (pts.Length == 3) {
        outTris.InsertLast(pts[0]);
        outTris.InsertLast(pts[1]);
        outTris.InsertLast(pts[2]);
        return outTris;
    }

    // Detect winding via shoelace sum so the convexity test below matches the polygon's
    // orientation (otherwise reflex vertices look like ears and vice versa).
    float shoelace = 0.0f;
    for (uint i = 0; i < pts.Length; i++) {
        vec2 a = pts[i];
        vec2 b = pts[(i + 1) % pts.Length];
        shoelace += a.x * b.y - b.x * a.y;
    }
    bool ccw = shoelace > 0.0f;

    array<uint> idx;
    for (uint i = 0; i < pts.Length; i++) idx.InsertLast(i);

    // Each successful ear clip removes one vertex; bound iterations defensively.
    int guard = int(pts.Length) * int(pts.Length);

    while (idx.Length > 3 && guard-- > 0) {
        bool foundEar = false;
        uint n = idx.Length;
        for (uint i = 0; i < n; i++) {
            uint prevI = (i + n - 1) % n;
            uint nextI = (i + 1) % n;
            vec2 a = pts[idx[prevI]];
            vec2 b = pts[idx[i]];
            vec2 c = pts[idx[nextI]];

            // Convex relative to polygon winding.
            float cross = TriangleSignedArea2(a, b, c);
            if (ccw ? cross <= 0.0f : cross >= 0.0f) continue;

            // No other polygon vertex may lie inside the candidate triangle.
            bool clean = true;
            for (uint j = 0; j < n; j++) {
                if (j == prevI || j == i || j == nextI) continue;
                if (PointInTriangle(pts[idx[j]], a, b, c)) {
                    clean = false;
                    break;
                }
            }
            if (!clean) continue;

            outTris.InsertLast(a);
            outTris.InsertLast(b);
            outTris.InsertLast(c);
            idx.RemoveAt(i);
            foundEar = true;
            break;
        }
        if (!foundEar) {
            // Self-intersecting or degenerate — fall back to fan triangulation.
            outTris.RemoveRange(0, outTris.Length);
            for (uint k = 1; k + 1 < pts.Length; k++) {
                outTris.InsertLast(pts[0]);
                outTris.InsertLast(pts[k]);
                outTris.InsertLast(pts[k + 1]);
            }
            return outTris;
        }
    }

    if (idx.Length == 3) {
        outTris.InsertLast(pts[idx[0]]);
        outTris.InsertLast(pts[idx[1]]);
        outTris.InsertLast(pts[idx[2]]);
    }
    return outTris;
}

// Maps the user-facing HotkeyKey (declared in state/settings.as so Openplanet can render it as
// a settings dropdown) to the corresponding UI::Key the runtime polls. Explicit switch so the
// mapping survives any future renumbering of UI::Key int values.
UI::Key HotkeyKeyToUIKey(HotkeyKey k) {
    switch (k) {
        case HotkeyKey::F1: return UI::Key::F1;
        case HotkeyKey::F2: return UI::Key::F2;
        case HotkeyKey::F3: return UI::Key::F3;
        case HotkeyKey::F4: return UI::Key::F4;
        case HotkeyKey::F5: return UI::Key::F5;
        case HotkeyKey::F6: return UI::Key::F6;
        case HotkeyKey::F7: return UI::Key::F7;
        case HotkeyKey::F8: return UI::Key::F8;
        case HotkeyKey::F9: return UI::Key::F9;
        case HotkeyKey::F10: return UI::Key::F10;
        case HotkeyKey::F11: return UI::Key::F11;
        case HotkeyKey::F12: return UI::Key::F12;
        case HotkeyKey::A: return UI::Key::A;
        case HotkeyKey::B: return UI::Key::B;
        case HotkeyKey::C: return UI::Key::C;
        case HotkeyKey::D: return UI::Key::D;
        case HotkeyKey::E: return UI::Key::E;
        case HotkeyKey::F: return UI::Key::F;
        case HotkeyKey::G: return UI::Key::G;
        case HotkeyKey::H: return UI::Key::H;
        case HotkeyKey::I: return UI::Key::I;
        case HotkeyKey::J: return UI::Key::J;
        case HotkeyKey::K: return UI::Key::K;
        case HotkeyKey::L: return UI::Key::L;
        case HotkeyKey::M: return UI::Key::M;
        case HotkeyKey::N: return UI::Key::N;
        case HotkeyKey::O: return UI::Key::O;
        case HotkeyKey::P: return UI::Key::P;
        case HotkeyKey::Q: return UI::Key::Q;
        case HotkeyKey::R: return UI::Key::R;
        case HotkeyKey::S: return UI::Key::S;
        case HotkeyKey::T: return UI::Key::T;
        case HotkeyKey::U: return UI::Key::U;
        case HotkeyKey::V: return UI::Key::V;
        case HotkeyKey::W: return UI::Key::W;
        case HotkeyKey::X: return UI::Key::X;
        case HotkeyKey::Y: return UI::Key::Y;
        case HotkeyKey::Z: return UI::Key::Z;
        case HotkeyKey::N0: return UI::Key::N0;
        case HotkeyKey::N1: return UI::Key::N1;
        case HotkeyKey::N2: return UI::Key::N2;
        case HotkeyKey::N3: return UI::Key::N3;
        case HotkeyKey::N4: return UI::Key::N4;
        case HotkeyKey::N5: return UI::Key::N5;
        case HotkeyKey::N6: return UI::Key::N6;
        case HotkeyKey::N7: return UI::Key::N7;
        case HotkeyKey::N8: return UI::Key::N8;
        case HotkeyKey::N9: return UI::Key::N9;
    }
    return UI::Key::F7;  // unreachable; keeps the compiler happy
}

// Display name for a HotkeyKey (used by the toolbar's hotkey row labels).
string HotkeyKeyName(HotkeyKey k) {
    switch (k) {
        case HotkeyKey::F1: return "F1";
        case HotkeyKey::F2: return "F2";
        case HotkeyKey::F3: return "F3";
        case HotkeyKey::F4: return "F4";
        case HotkeyKey::F5: return "F5";
        case HotkeyKey::F6: return "F6";
        case HotkeyKey::F7: return "F7";
        case HotkeyKey::F8: return "F8";
        case HotkeyKey::F9: return "F9";
        case HotkeyKey::F10: return "F10";
        case HotkeyKey::F11: return "F11";
        case HotkeyKey::F12: return "F12";
        case HotkeyKey::A: return "A";
        case HotkeyKey::B: return "B";
        case HotkeyKey::C: return "C";
        case HotkeyKey::D: return "D";
        case HotkeyKey::E: return "E";
        case HotkeyKey::F: return "F";
        case HotkeyKey::G: return "G";
        case HotkeyKey::H: return "H";
        case HotkeyKey::I: return "I";
        case HotkeyKey::J: return "J";
        case HotkeyKey::K: return "K";
        case HotkeyKey::L: return "L";
        case HotkeyKey::M: return "M";
        case HotkeyKey::N: return "N";
        case HotkeyKey::O: return "O";
        case HotkeyKey::P: return "P";
        case HotkeyKey::Q: return "Q";
        case HotkeyKey::R: return "R";
        case HotkeyKey::S: return "S";
        case HotkeyKey::T: return "T";
        case HotkeyKey::U: return "U";
        case HotkeyKey::V: return "V";
        case HotkeyKey::W: return "W";
        case HotkeyKey::X: return "X";
        case HotkeyKey::Y: return "Y";
        case HotkeyKey::Z: return "Z";
        case HotkeyKey::N0: return "0";
        case HotkeyKey::N1: return "1";
        case HotkeyKey::N2: return "2";
        case HotkeyKey::N3: return "3";
        case HotkeyKey::N4: return "4";
        case HotkeyKey::N5: return "5";
        case HotkeyKey::N6: return "6";
        case HotkeyKey::N7: return "7";
        case HotkeyKey::N8: return "8";
        case HotkeyKey::N9: return "9";
    }
    return "?";
}

// True if `color` matches a palette entry the user has locked. Used by the eraser to
// preserve "base diagram" annotations while iterating on overlays.
bool IsColorLocked(const vec4 &in color) {
    if (S_LockRed && ColorsEqualRGB(color, g_Palette[0].Color)) return true;
    if (S_LockGreen && ColorsEqualRGB(color, g_Palette[1].Color)) return true;
    if (S_LockBlue && ColorsEqualRGB(color, g_Palette[2].Color)) return true;
    if (S_LockYellow && ColorsEqualRGB(color, g_Palette[3].Color)) return true;
    if (S_LockCustom && ColorsEqualRGB(color, S_CustomColor)) return true;
    return false;
}
