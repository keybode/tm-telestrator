float DrawDashedSegment(UI::DrawList@ drawList, const vec2 &in a, const vec2 &in b, const vec4 &in c, float thickness, float phase) {
    float dashLen = Math::Max(thickness * 3.0f, 6.0f);
    float gapLen = dashLen * 0.6f;
    float cycle = dashLen + gapLen;

    vec2 d = b - a;
    float len = Math::Sqrt(d.x * d.x + d.y * d.y);
    if (len < 0.01f) return phase;
    vec2 unit = vec2(d.x / len, d.y / len);

    const int MAX_DASHES = 4000;
    int k = int(Math::Floor(phase / cycle));
    int drawn = 0;
    while (drawn < MAX_DASHES) {
        float dashStart = float(k) * cycle - phase;
        if (dashStart >= len) break;
        float clipStart = Math::Max(dashStart, 0.0f);
        float clipEnd = Math::Min(dashStart + dashLen, len);
        if (clipEnd > clipStart) {
            drawList.AddLine(a + unit * clipStart, a + unit * clipEnd, c, thickness);
        }
        k++;
        drawn++;
    }
    return phase + len;
}

float Distance(const vec2 &in a, const vec2 &in b) {
    vec2 d = b - a;
    return Math::Sqrt(d.x * d.x + d.y * d.y);
}

void ComputeBounds(const array<vec2> &in pts, vec2 &out boundsMin, vec2 &out boundsMax) {
    if (pts.Length == 0) {
        boundsMin = vec2(0, 0);
        boundsMax = vec2(0, 0);
        return;
    }
    boundsMin = pts[0];
    boundsMax = pts[0];
    for (uint i = 1; i < pts.Length; i++) {
        if (pts[i].x < boundsMin.x) boundsMin.x = pts[i].x;
        if (pts[i].y < boundsMin.y) boundsMin.y = pts[i].y;
        if (pts[i].x > boundsMax.x) boundsMax.x = pts[i].x;
        if (pts[i].y > boundsMax.y) boundsMax.y = pts[i].y;
    }
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

vec2 ConstrainAngle(const vec2 &in origin, const vec2 &in target, float angleStep) {
    vec2 d = target - origin;
    float len = Math::Sqrt(d.x * d.x + d.y * d.y);
    if (len < 0.01f) return target;
    float angle = Math::Atan2(d.y, d.x);
    float snapped = Math::Floor((angle / angleStep) + 0.5f) * angleStep;
    return vec2(origin.x + Math::Cos(snapped) * len, origin.y + Math::Sin(snapped) * len);
}

vec2 ConstrainSquare(const vec2 &in anchor, const vec2 &in target) {
    float dx = target.x - anchor.x;
    float dy = target.y - anchor.y;
    float m = Math::Max(Math::Abs(dx), Math::Abs(dy));
    float sx = dx >= 0.0f ? 1.0f : -1.0f;
    float sy = dy >= 0.0f ? 1.0f : -1.0f;
    return vec2(anchor.x + sx * m, anchor.y + sy * m);
}

void DrawArrowhead(UI::DrawList@ drawList, const vec2 &in tip, const vec2 &in unit, float thickness, const vec4 &in c) {
    vec2 perp = vec2(-unit.y, unit.x);
    float headSize = Math::Max(10.0f, thickness * 3.0f);
    vec2 base = tip - unit * headSize;
    vec2 left = base + perp * headSize * 0.5f;
    vec2 right = base - perp * headSize * 0.5f;
    drawList.AddLine(tip, left, c, thickness);
    drawList.AddLine(tip, right, c, thickness);
}

float TriangleSignedArea2(const vec2 &in a, const vec2 &in b, const vec2 &in c) {
    return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
}

bool PointInTriangle(const vec2 &in p, const vec2 &in a, const vec2 &in b, const vec2 &in c) {
    float d1 = TriangleSignedArea2(p, a, b);
    float d2 = TriangleSignedArea2(p, b, c);
    float d3 = TriangleSignedArea2(p, c, a);
    bool hasNeg = (d1 < 0.0f) || (d2 < 0.0f) || (d3 < 0.0f);
    bool hasPos = (d1 > 0.0f) || (d2 > 0.0f) || (d3 > 0.0f);
    return !(hasNeg && hasPos);
}

array<vec2> TriangulatePolygon(const array<vec2> &in pts) {
    array<vec2> outTris;
    if (pts.Length < 3) return outTris;
    if (pts.Length == 3) {
        outTris.InsertLast(pts[0]);
        outTris.InsertLast(pts[1]);
        outTris.InsertLast(pts[2]);
        return outTris;
    }

    float shoelace = 0.0f;
    for (uint i = 0; i < pts.Length; i++) {
        vec2 a = pts[i];
        vec2 b = pts[(i + 1) % pts.Length];
        shoelace += a.x * b.y - b.x * a.y;
    }
    bool ccw = shoelace > 0.0f;

    array<uint> idx;
    for (uint i = 0; i < pts.Length; i++) idx.InsertLast(i);

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

            float cross = TriangleSignedArea2(a, b, c);
            if (ccw ? cross <= 0.0f : cross >= 0.0f) continue;

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
    return UI::Key::F7;
}

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

bool IsColorLocked(const vec4 &in color) {
    if (S_LockRed && ColorsEqualRGB(color, g_Palette[0].Color)) return true;
    if (S_LockGreen && ColorsEqualRGB(color, g_Palette[1].Color)) return true;
    if (S_LockBlue && ColorsEqualRGB(color, g_Palette[2].Color)) return true;
    if (S_LockYellow && ColorsEqualRGB(color, g_Palette[3].Color)) return true;
    if (S_LockCustom && ColorsEqualRGB(color, S_CustomColor)) return true;
    return false;
}
