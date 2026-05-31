
class Drawable {
    vec4 Color;
    uint64 CreatedAt;
    bool WorldAnchored;
    vec3 WorldAnchor;
    vec2 ScreenAnchorAtCommit;

    uint64 m_OffsetFrame;
    vec2 m_CachedOffset;
    bool m_OffsetValid;

    Drawable() {
        Color = vec4(1.0f, 1.0f, 1.0f, 1.0f);
        CreatedAt = Time::Now;
        WorldAnchored = false;
        WorldAnchor = vec3(0, 0, 0);
        ScreenAnchorAtCommit = vec2(0, 0);
        m_OffsetFrame = 0;
        m_CachedOffset = vec2(0, 0);
        m_OffsetValid = true;
    }

    void Draw(UI::DrawList@ drawList, float alphaMul) {}
    bool HitTest(const vec2 &in pos, float radius) { return false; }
    void Translate(const vec2 &in delta) {}
    void Bounds(vec2 &out boundsMin, vec2 &out boundsMax) {
        boundsMin = vec2(0, 0);
        boundsMax = vec2(0, 0);
    }

    array<vec2> GetHandles() { return array<vec2>(); }
    void MoveHandle(int index, const vec2 &in pos) {}

    bool IsNonDegenerate() { return true; }

    vec2 CurrentOffset() {
        if (!WorldAnchored) return vec2(0, 0);
        if (m_OffsetFrame != g_FrameCounter) {
            m_OffsetFrame = g_FrameCounter;
            m_OffsetValid = GetAnchorOffset(WorldAnchor, ScreenAnchorAtCommit, m_CachedOffset);
        }
        return m_OffsetValid ? m_CachedOffset : vec2(0, 0);
    }

    bool IsAnchorVisible() {
        if (!WorldAnchored) return true;
        CurrentOffset();
        return m_OffsetValid;
    }

    bool HitTestScreen(const vec2 &in screenPos, float radius) {
        return HitTest(screenPos - CurrentOffset(), radius);
    }
    void MoveHandleScreen(int index, const vec2 &in screenPos) {
        MoveHandle(index, screenPos - CurrentOffset());
    }
    array<vec2> GetHandlesScreen() {
        array<vec2> h = GetHandles();
        vec2 off = CurrentOffset();
        if (off.x == 0.0f && off.y == 0.0f) return h;
        for (uint i = 0; i < h.Length; i++) h[i] = h[i] + off;
        return h;
    }
    void BoundsScreen(vec2 &out boundsMin, vec2 &out boundsMax) {
        Bounds(boundsMin, boundsMax);
        vec2 off = CurrentOffset();
        boundsMin = boundsMin + off;
        boundsMax = boundsMax + off;
    }

    vec2 ToStored(const vec2 &in screenPos) {
        return screenPos - CurrentOffset();
    }

    Json::Value@ Serialize() {
        Json::Value@ obj = Json::Object();
        obj["color"] = SerializeColor(Color);
        if (WorldAnchored) {
            obj["worldAnchored"] = true;
            obj["worldAnchor"] = SerializeVec3(WorldAnchor);
            obj["screenAnchor"] = SerializePoint(ScreenAnchorAtCommit);
        }
        return obj;
    }
}

class Stroke : Drawable {
    float Thickness;
    bool Dashed;
    bool Highlighter;
    array<vec2> Points;

    array<vec4> Mesh;
    bool MeshDirty;

    Stroke() {
        super();
        Thickness = 4.0f;
        Dashed = false;
        Highlighter = false;
        MeshDirty = true;
    }

    void Draw(UI::DrawList@ drawList, float alphaMul) override {
        if (Points.Length == 0) return;
        vec4 c = vec4(Color.x, Color.y, Color.z, Color.w * alphaMul);

        if (Highlighter) {
            if (MeshDirty) RebuildMesh();
            if (Mesh.Length > 0) {
                DrawRectMesh(drawList, Mesh, c);
                return;
            }
        }

        if (Points.Length == 1) {
            drawList.AddCircleFilled(Points[0], Thickness * 0.5f, c);
            return;
        }

        if (Dashed) {
            float phase = 0.0f;
            for (uint i = 1; i < Points.Length; i++) {
                phase = DrawDashedSegment(drawList, Points[i - 1], Points[i], c, Thickness, phase);
            }
            return;
        }

        for (uint i = 1; i < Points.Length; i++) {
            drawList.AddLine(Points[i - 1], Points[i], c, Thickness);
        }
        float jr = Thickness * 0.5f;
        for (uint i = 0; i < Points.Length; i++) {
            drawList.AddCircleFilled(Points[i], jr, c);
        }
    }

    void RebuildMesh() {
        if (!Highlighter) {
            Mesh.Resize(0);
            MeshDirty = false;
            return;
        }
        Mesh = BuildStrokeUnionMesh(Points, Thickness * 0.5f);
        MeshDirty = false;
    }

    bool HitTest(const vec2 &in pos, float radius) override {
        float threshold = radius + Thickness * 0.5f;
        if (Points.Length == 1) {
            return Distance(pos, Points[0]) <= threshold;
        }
        for (uint i = 1; i < Points.Length; i++) {
            if (PointToSegmentDistance(pos, Points[i - 1], Points[i]) <= threshold) {
                return true;
            }
        }
        return false;
    }

    void Translate(const vec2 &in delta) override {
        for (uint i = 0; i < Points.Length; i++) {
            Points[i] = Points[i] + delta;
        }
        TranslateRectArray(Mesh, delta);
    }

    void Bounds(vec2 &out boundsMin, vec2 &out boundsMax) override {
        ComputeBounds(Points, boundsMin, boundsMax);
    }

    bool IsNonDegenerate() override { return Points.Length >= 2; }

    Json::Value@ Serialize() override {
        Json::Value@ obj = Drawable::Serialize();
        obj["type"] = "stroke";
        obj["thickness"] = Thickness;
        obj["dashed"] = Dashed;
        obj["highlighter"] = Highlighter;
        Json::Value@ pts = Json::Array();
        for (uint i = 0; i < Points.Length; i++) {
            pts.Add(SerializePoint(Points[i]));
        }
        obj["points"] = pts;
        return obj;
    }
}

class Arrow : Drawable {
    vec2 Start;
    vec2 End;
    float Thickness;
    bool Dashed;

    Arrow() {
        super();
        Thickness = 4.0f;
        Dashed = false;
    }

    void Draw(UI::DrawList@ drawList, float alphaMul) override {
        vec4 c = vec4(Color.x, Color.y, Color.z, Color.w * alphaMul);
        if (Dashed) {
            DrawDashedSegment(drawList, Start, End, c, Thickness, 0.0f);
        } else {
            drawList.AddLine(Start, End, c, Thickness);
        }
        DrawHead(drawList, c);
    }

    void DrawHead(UI::DrawList@ drawList, const vec4 &in c) {
        vec2 d = End - Start;
        float len = Math::Sqrt(d.x * d.x + d.y * d.y);
        if (len < 0.01f) return;
        DrawArrowhead(drawList, End, vec2(d.x / len, d.y / len), Thickness, c);
    }

    bool HitTest(const vec2 &in pos, float radius) override {
        return PointToSegmentDistance(pos, Start, End) <= radius + Thickness * 0.5f;
    }

    void Translate(const vec2 &in delta) override {
        Start = Start + delta;
        End = End + delta;
    }

    void Bounds(vec2 &out boundsMin, vec2 &out boundsMax) override {
        boundsMin = vec2(Math::Min(Start.x, End.x), Math::Min(Start.y, End.y));
        boundsMax = vec2(Math::Max(Start.x, End.x), Math::Max(Start.y, End.y));
    }

    array<vec2> GetHandles() override {
        array<vec2> h;
        h.InsertLast(Start);
        h.InsertLast(End);
        return h;
    }

    void MoveHandle(int index, const vec2 &in pos) override {
        if (index == 0) Start = pos;
        else if (index == 1) End = pos;
    }

    bool IsNonDegenerate() override { return Distance(Start, End) >= 4.0f; }

    Json::Value@ Serialize() override {
        Json::Value@ obj = Drawable::Serialize();
        obj["type"] = "arrow";
        obj["thickness"] = Thickness;
        obj["dashed"] = Dashed;
        obj["start"] = SerializePoint(Start);
        obj["end"] = SerializePoint(End);
        return obj;
    }
}

class LineSeg : Drawable {
    vec2 Start;
    vec2 End;
    float Thickness;
    bool Dashed;

    LineSeg() {
        super();
        Thickness = 4.0f;
        Dashed = false;
    }

    void Draw(UI::DrawList@ drawList, float alphaMul) override {
        vec4 c = vec4(Color.x, Color.y, Color.z, Color.w * alphaMul);
        if (Dashed) {
            DrawDashedSegment(drawList, Start, End, c, Thickness, 0.0f);
        } else {
            drawList.AddLine(Start, End, c, Thickness);
        }
    }

    bool HitTest(const vec2 &in pos, float radius) override {
        return PointToSegmentDistance(pos, Start, End) <= radius + Thickness * 0.5f;
    }

    void Translate(const vec2 &in delta) override {
        Start = Start + delta;
        End = End + delta;
    }

    void Bounds(vec2 &out boundsMin, vec2 &out boundsMax) override {
        boundsMin = vec2(Math::Min(Start.x, End.x), Math::Min(Start.y, End.y));
        boundsMax = vec2(Math::Max(Start.x, End.x), Math::Max(Start.y, End.y));
    }

    array<vec2> GetHandles() override {
        array<vec2> h;
        h.InsertLast(Start);
        h.InsertLast(End);
        return h;
    }

    void MoveHandle(int index, const vec2 &in pos) override {
        if (index == 0) Start = pos;
        else if (index == 1) End = pos;
    }

    bool IsNonDegenerate() override { return Distance(Start, End) >= 4.0f; }

    Json::Value@ Serialize() override {
        Json::Value@ obj = Drawable::Serialize();
        obj["type"] = "line";
        obj["thickness"] = Thickness;
        obj["dashed"] = Dashed;
        obj["start"] = SerializePoint(Start);
        obj["end"] = SerializePoint(End);
        return obj;
    }
}

class RectShape : Drawable {
    vec2 Corner1;
    vec2 Corner2;
    float Thickness;

    RectShape() {
        super();
        Thickness = 4.0f;
    }

    void NormalizedCorners(vec2 &out a, vec2 &out b) {
        a = vec2(Math::Min(Corner1.x, Corner2.x), Math::Min(Corner1.y, Corner2.y));
        b = vec2(Math::Max(Corner1.x, Corner2.x), Math::Max(Corner1.y, Corner2.y));
    }

    void Draw(UI::DrawList@ drawList, float alphaMul) override {
        vec4 c = vec4(Color.x, Color.y, Color.z, Color.w * alphaMul);
        vec2 a, b;
        NormalizedCorners(a, b);
        vec2 tr = vec2(b.x, a.y);
        vec2 bl = vec2(a.x, b.y);
        drawList.AddLine(a, tr, c, Thickness);
        drawList.AddLine(tr, b, c, Thickness);
        drawList.AddLine(b, bl, c, Thickness);
        drawList.AddLine(bl, a, c, Thickness);
    }

    bool HitTest(const vec2 &in pos, float radius) override {
        vec2 a, b;
        NormalizedCorners(a, b);
        vec2 tr = vec2(b.x, a.y);
        vec2 bl = vec2(a.x, b.y);
        float threshold = radius + Thickness * 0.5f;
        if (PointToSegmentDistance(pos, a, tr) <= threshold) return true;
        if (PointToSegmentDistance(pos, tr, b) <= threshold) return true;
        if (PointToSegmentDistance(pos, b, bl) <= threshold) return true;
        if (PointToSegmentDistance(pos, bl, a) <= threshold) return true;
        return false;
    }

    void Translate(const vec2 &in delta) override {
        Corner1 = Corner1 + delta;
        Corner2 = Corner2 + delta;
    }

    void Bounds(vec2 &out boundsMin, vec2 &out boundsMax) override {
        NormalizedCorners(boundsMin, boundsMax);
    }

    array<vec2> GetHandles() override {
        array<vec2> h;
        h.InsertLast(Corner1);
        h.InsertLast(vec2(Corner2.x, Corner1.y));
        h.InsertLast(Corner2);
        h.InsertLast(vec2(Corner1.x, Corner2.y));
        return h;
    }

    void MoveHandle(int index, const vec2 &in pos) override {
        if (index == 0) Corner1 = pos;
        else if (index == 1) { Corner1.y = pos.y; Corner2.x = pos.x; }
        else if (index == 2) Corner2 = pos;
        else if (index == 3) { Corner1.x = pos.x; Corner2.y = pos.y; }
    }

    bool IsNonDegenerate() override { return Distance(Corner1, Corner2) >= 4.0f; }

    Json::Value@ Serialize() override {
        Json::Value@ obj = Drawable::Serialize();
        obj["type"] = "rect";
        obj["thickness"] = Thickness;
        obj["corner1"] = SerializePoint(Corner1);
        obj["corner2"] = SerializePoint(Corner2);
        return obj;
    }
}

class CircleShape : Drawable {
    vec2 Center;
    float Radius;
    float Thickness;

    CircleShape() {
        super();
        Radius = 0.0f;
        Thickness = 4.0f;
    }

    void Draw(UI::DrawList@ drawList, float alphaMul) override {
        if (Radius < 1.0f) return;
        vec4 c = vec4(Color.x, Color.y, Color.z, Color.w * alphaMul);
        drawList.AddCircle(Center, Radius, c, 0, Thickness);
    }

    bool HitTest(const vec2 &in pos, float radius) override {
        float d = Distance(pos, Center);
        return Math::Abs(d - Radius) <= radius + Thickness * 0.5f;
    }

    void Translate(const vec2 &in delta) override {
        Center = Center + delta;
    }

    void Bounds(vec2 &out boundsMin, vec2 &out boundsMax) override {
        boundsMin = vec2(Center.x - Radius, Center.y - Radius);
        boundsMax = vec2(Center.x + Radius, Center.y + Radius);
    }

    array<vec2> GetHandles() override {
        array<vec2> h;
        h.InsertLast(vec2(Center.x + Radius, Center.y));
        h.InsertLast(vec2(Center.x, Center.y - Radius));
        h.InsertLast(vec2(Center.x - Radius, Center.y));
        h.InsertLast(vec2(Center.x, Center.y + Radius));
        return h;
    }

    void MoveHandle(int index, const vec2 &in pos) override {
        Radius = Distance(Center, pos);
    }

    bool IsNonDegenerate() override { return Radius >= 4.0f; }

    Json::Value@ Serialize() override {
        Json::Value@ obj = Drawable::Serialize();
        obj["type"] = "circle";
        obj["thickness"] = Thickness;
        obj["center"] = SerializePoint(Center);
        obj["radius"] = Radius;
        return obj;
    }
}

class EllipseShape : Drawable {
    vec2 Corner1;
    vec2 Corner2;
    float Thickness;

    EllipseShape() {
        super();
        Thickness = 4.0f;
    }

    void NormalizedCorners(vec2 &out a, vec2 &out b) {
        a = vec2(Math::Min(Corner1.x, Corner2.x), Math::Min(Corner1.y, Corner2.y));
        b = vec2(Math::Max(Corner1.x, Corner2.x), Math::Max(Corner1.y, Corner2.y));
    }

    void Draw(UI::DrawList@ drawList, float alphaMul) override {
        vec2 a, b;
        NormalizedCorners(a, b);
        float rx = (b.x - a.x) * 0.5f;
        float ry = (b.y - a.y) * 0.5f;
        if (rx < 1.0f || ry < 1.0f) return;
        vec2 center = vec2(a.x + rx, a.y + ry);
        vec4 c = vec4(Color.x, Color.y, Color.z, Color.w * alphaMul);

        int segments = int(Math::Clamp((rx + ry) * 0.5f, 16.0f, 64.0f));
        float twoPi = Math::PI * 2.0f;
        vec2 prev = vec2(center.x + rx, center.y);
        for (int i = 1; i <= segments; i++) {
            float t = float(i) / float(segments) * twoPi;
            vec2 p = vec2(center.x + rx * Math::Cos(t), center.y + ry * Math::Sin(t));
            drawList.AddLine(prev, p, c, Thickness);
            prev = p;
        }
    }

    bool HitTest(const vec2 &in pos, float radius) override {
        vec2 a, b;
        NormalizedCorners(a, b);
        float rx = (b.x - a.x) * 0.5f;
        float ry = (b.y - a.y) * 0.5f;
        if (rx < 0.5f || ry < 0.5f) return false;
        vec2 center = vec2(a.x + rx, a.y + ry);
        float threshold = radius + Thickness * 0.5f;

        float nx = (pos.x - center.x) / rx;
        float ny = (pos.y - center.y) / ry;
        float r2 = nx * nx + ny * ny;
        float minR = Math::Min(rx, ry);
        float pixelOff = Math::Abs(Math::Sqrt(r2) - 1.0f) * minR;
        return pixelOff <= threshold;
    }

    void Translate(const vec2 &in delta) override {
        Corner1 = Corner1 + delta;
        Corner2 = Corner2 + delta;
    }

    void Bounds(vec2 &out boundsMin, vec2 &out boundsMax) override {
        NormalizedCorners(boundsMin, boundsMax);
    }

    array<vec2> GetHandles() override {
        array<vec2> h;
        h.InsertLast(Corner1);
        h.InsertLast(vec2(Corner2.x, Corner1.y));
        h.InsertLast(Corner2);
        h.InsertLast(vec2(Corner1.x, Corner2.y));
        return h;
    }

    void MoveHandle(int index, const vec2 &in pos) override {
        if (index == 0) Corner1 = pos;
        else if (index == 1) { Corner1.y = pos.y; Corner2.x = pos.x; }
        else if (index == 2) Corner2 = pos;
        else if (index == 3) { Corner1.x = pos.x; Corner2.y = pos.y; }
    }

    bool IsNonDegenerate() override { return Distance(Corner1, Corner2) >= 4.0f; }

    Json::Value@ Serialize() override {
        Json::Value@ obj = Drawable::Serialize();
        obj["type"] = "ellipse";
        obj["thickness"] = Thickness;
        obj["corner1"] = SerializePoint(Corner1);
        obj["corner2"] = SerializePoint(Corner2);
        return obj;
    }
}

class TextLabel : Drawable {
    vec2 Position;
    string Text;
    float Size;

    TextLabel() {
        super();
        Size = 24.0f;
    }

    void Draw(UI::DrawList@ drawList, float alphaMul) override {
        vec4 c = vec4(Color.x, Color.y, Color.z, Color.w * alphaMul);
        drawList.AddText(Position, c, Text, null, Size);
    }

    bool HitTest(const vec2 &in pos, float radius) override {
        vec2 size = UI::MeasureString(Text, null, Size);
        return pos.x >= Position.x - radius
            && pos.x <= Position.x + size.x + radius
            && pos.y >= Position.y - radius
            && pos.y <= Position.y + size.y + radius;
    }

    void Translate(const vec2 &in delta) override {
        Position = Position + delta;
    }

    void Bounds(vec2 &out boundsMin, vec2 &out boundsMax) override {
        vec2 size = UI::MeasureString(Text, null, Size);
        boundsMin = Position;
        boundsMax = Position + size;
    }

    Json::Value@ Serialize() override {
        Json::Value@ obj = Drawable::Serialize();
        obj["type"] = "text";
        obj["position"] = SerializePoint(Position);
        obj["text"] = Text;
        obj["size"] = Size;
        return obj;
    }
}

class NumberMarker : Drawable {
    vec2 Position;
    int Number;
    float Size;

    NumberMarker() {
        super();
        Number = 1;
        Size = 32.0f;
    }

    void Draw(UI::DrawList@ drawList, float alphaMul) override {
        vec4 c = vec4(Color.x, Color.y, Color.z, Color.w * alphaMul);
        float radius = Size * 0.5f;
        drawList.AddCircleFilled(Position, radius, c);
        float lum = Color.x * 0.299f + Color.y * 0.587f + Color.z * 0.114f;
        vec4 textColor = lum > 0.55f
            ? vec4(0, 0, 0, alphaMul)
            : vec4(1, 1, 1, alphaMul);
        string label = "" + Number;
        float fontSize = Size * 0.65f;
        vec2 textSize = UI::MeasureString(label, null, fontSize);
        vec2 textPos = vec2(Position.x - textSize.x * 0.5f, Position.y - textSize.y * 0.5f);
        drawList.AddText(textPos, textColor, label, null, fontSize);
    }

    bool HitTest(const vec2 &in pos, float radius) override {
        return Distance(pos, Position) <= radius + Size * 0.5f;
    }

    void Translate(const vec2 &in delta) override {
        Position = Position + delta;
    }

    void Bounds(vec2 &out boundsMin, vec2 &out boundsMax) override {
        float r = Size * 0.5f;
        boundsMin = vec2(Position.x - r, Position.y - r);
        boundsMax = vec2(Position.x + r, Position.y + r);
    }

    Json::Value@ Serialize() override {
        Json::Value@ obj = Drawable::Serialize();
        obj["type"] = "marker";
        obj["position"] = SerializePoint(Position);
        obj["number"] = Number;
        obj["size"] = Size;
        return obj;
    }
}

class Measurement : Drawable {
    vec2 Start;
    vec2 End;
    float Thickness;
    bool Dashed;

    Measurement() {
        super();
        Thickness = 4.0f;
        Dashed = false;
    }

    void Draw(UI::DrawList@ drawList, float alphaMul) override {
        vec4 c = vec4(Color.x, Color.y, Color.z, Color.w * alphaMul);
        if (Dashed) {
            DrawDashedSegment(drawList, Start, End, c, Thickness, 0.0f);
        } else {
            drawList.AddLine(Start, End, c, Thickness);
        }
        vec2 d = End - Start;
        float len = Math::Sqrt(d.x * d.x + d.y * d.y);
        if (len < 0.01f) return;
        vec2 unit = vec2(d.x / len, d.y / len);
        vec2 perp = vec2(-unit.y, unit.x);
        float tickHalf = Math::Max(6.0f, Thickness * 1.5f);
        drawList.AddLine(Start - perp * tickHalf, Start + perp * tickHalf, c, Thickness);
        drawList.AddLine(End - perp * tickHalf, End + perp * tickHalf, c, Thickness);
        vec2 labelPerp = vec2(unit.y, -unit.x);
        vec2 mid = (Start + End) * 0.5f;
        string label = "" + int(len + 0.5f) + " px";
        float fontSize = Math::Max(S_TextSize * 0.6f, 12.0f);
        vec2 textSize = UI::MeasureString(label, null, fontSize);
        vec2 labelPos = mid + labelPerp * (tickHalf + 4.0f) - vec2(textSize.x * 0.5f, textSize.y * 0.5f);
        drawList.AddText(labelPos, c, label, null, fontSize);
    }

    bool HitTest(const vec2 &in pos, float radius) override {
        return PointToSegmentDistance(pos, Start, End) <= radius + Thickness * 0.5f;
    }

    void Translate(const vec2 &in delta) override {
        Start = Start + delta;
        End = End + delta;
    }

    void Bounds(vec2 &out boundsMin, vec2 &out boundsMax) override {
        boundsMin = vec2(Math::Min(Start.x, End.x), Math::Min(Start.y, End.y));
        boundsMax = vec2(Math::Max(Start.x, End.x), Math::Max(Start.y, End.y));
    }

    array<vec2> GetHandles() override {
        array<vec2> h;
        h.InsertLast(Start);
        h.InsertLast(End);
        return h;
    }

    void MoveHandle(int index, const vec2 &in pos) override {
        if (index == 0) Start = pos;
        else if (index == 1) End = pos;
    }

    bool IsNonDegenerate() override { return Distance(Start, End) >= 4.0f; }

    Json::Value@ Serialize() override {
        Json::Value@ obj = Drawable::Serialize();
        obj["type"] = "measurement";
        obj["thickness"] = Thickness;
        obj["dashed"] = Dashed;
        obj["start"] = SerializePoint(Start);
        obj["end"] = SerializePoint(End);
        return obj;
    }
}

class Bracket : Drawable {
    vec2 Start;
    vec2 End;
    float Thickness;
    bool Dashed;

    Bracket() {
        super();
        Thickness = 4.0f;
        Dashed = false;
    }

    void Draw(UI::DrawList@ drawList, float alphaMul) override {
        vec4 c = vec4(Color.x, Color.y, Color.z, Color.w * alphaMul);
        if (Dashed) {
            DrawDashedSegment(drawList, Start, End, c, Thickness, 0.0f);
        } else {
            drawList.AddLine(Start, End, c, Thickness);
        }
        vec2 d = End - Start;
        float len = Math::Sqrt(d.x * d.x + d.y * d.y);
        if (len < 0.01f) return;
        vec2 unit = vec2(d.x / len, d.y / len);
        vec2 perp = vec2(-unit.y, unit.x);
        float capLen = Math::Max(16.0f, Thickness * 4.0f);
        drawList.AddLine(Start, Start + perp * capLen, c, Thickness);
        drawList.AddLine(End, End + perp * capLen, c, Thickness);
    }

    bool HitTest(const vec2 &in pos, float radius) override {
        return PointToSegmentDistance(pos, Start, End) <= radius + Thickness * 0.5f;
    }

    void Translate(const vec2 &in delta) override {
        Start = Start + delta;
        End = End + delta;
    }

    void Bounds(vec2 &out boundsMin, vec2 &out boundsMax) override {
        boundsMin = vec2(Math::Min(Start.x, End.x), Math::Min(Start.y, End.y));
        boundsMax = vec2(Math::Max(Start.x, End.x), Math::Max(Start.y, End.y));
    }

    array<vec2> GetHandles() override {
        array<vec2> h;
        h.InsertLast(Start);
        h.InsertLast(End);
        return h;
    }

    void MoveHandle(int index, const vec2 &in pos) override {
        if (index == 0) Start = pos;
        else if (index == 1) End = pos;
    }

    bool IsNonDegenerate() override { return Distance(Start, End) >= 4.0f; }

    Json::Value@ Serialize() override {
        Json::Value@ obj = Drawable::Serialize();
        obj["type"] = "bracket";
        obj["thickness"] = Thickness;
        obj["dashed"] = Dashed;
        obj["start"] = SerializePoint(Start);
        obj["end"] = SerializePoint(End);
        return obj;
    }
}

class Polygon : Drawable {
    array<vec2> Vertices;
    float Thickness;
    bool Dashed;
    bool Filled;

    array<vec4> FillMesh;
    bool FillMeshDirty;

    Polygon() {
        super();
        Thickness = 4.0f;
        Dashed = false;
        Filled = false;
        FillMeshDirty = true;
    }

    void DrawEdge(UI::DrawList@ drawList, const vec2 &in a, const vec2 &in b, const vec4 &in c) {
        if (Dashed) {
            DrawDashedSegment(drawList, a, b, c, Thickness, 0.0f);
        } else {
            drawList.AddLine(a, b, c, Thickness);
        }
    }

    void RebuildFillMesh() {
        FillMesh = BuildPolygonFillMesh(Vertices);
        FillMeshDirty = false;
    }

    void Draw(UI::DrawList@ drawList, float alphaMul) override {
        if (Vertices.Length == 0) return;
        vec4 c = vec4(Color.x, Color.y, Color.z, Color.w * alphaMul);
        bool building = (g_Pending !is null && g_Pending is this);

        if (Filled && !building && Vertices.Length >= 3) {
            if (FillMeshDirty) RebuildFillMesh();
            vec4 fillColor = vec4(c.x, c.y, c.z, c.w * 0.25f);
            DrawRectMesh(drawList, FillMesh, fillColor);
        }

        for (uint i = 1; i < Vertices.Length; i++) {
            DrawEdge(drawList, Vertices[i - 1], Vertices[i], c);
        }

        if (building) {
            vec2 mouse = UI::GetMousePos();
            vec4 preview = vec4(c.x, c.y, c.z, c.w * 0.5f);
            drawList.AddLine(Vertices[Vertices.Length - 1], mouse, preview, Thickness);
            float r = Math::Max(5.0f, Thickness);
            drawList.AddCircle(Vertices[0], r, c, 0, 1.5f);
            if (Vertices.Length >= 3 && Distance(mouse, Vertices[0]) <= 8.0f) {
                drawList.AddCircleFilled(Vertices[0], r, c);
            }
            for (uint i = 1; i < Vertices.Length; i++) {
                drawList.AddCircleFilled(Vertices[i], Math::Max(3.0f, Thickness * 0.5f), c);
            }
        } else if (Vertices.Length >= 3) {
            DrawEdge(drawList, Vertices[Vertices.Length - 1], Vertices[0], c);
        }
    }

    bool HitTest(const vec2 &in pos, float radius) override {
        if (Vertices.Length < 2) return false;
        float threshold = radius + Thickness * 0.5f;
        for (uint i = 1; i < Vertices.Length; i++) {
            if (PointToSegmentDistance(pos, Vertices[i - 1], Vertices[i]) <= threshold) return true;
        }
        if (Vertices.Length >= 3) {
            if (PointToSegmentDistance(pos, Vertices[Vertices.Length - 1], Vertices[0]) <= threshold) return true;
        }
        return false;
    }

    void Translate(const vec2 &in delta) override {
        for (uint i = 0; i < Vertices.Length; i++) {
            Vertices[i] = Vertices[i] + delta;
        }
        TranslateRectArray(FillMesh, delta);
    }

    void Bounds(vec2 &out boundsMin, vec2 &out boundsMax) override {
        ComputeBounds(Vertices, boundsMin, boundsMax);
    }

    array<vec2> GetHandles() override {
        array<vec2> h;
        for (uint i = 0; i < Vertices.Length; i++) {
            h.InsertLast(Vertices[i]);
        }
        return h;
    }

    void MoveHandle(int index, const vec2 &in pos) override {
        if (index < 0 || uint(index) >= Vertices.Length) return;
        Vertices[uint(index)] = pos;
        FillMeshDirty = true;
    }

    bool IsNonDegenerate() override { return Vertices.Length >= 3; }

    Json::Value@ Serialize() override {
        Json::Value@ obj = Drawable::Serialize();
        obj["type"] = "polygon";
        obj["thickness"] = Thickness;
        obj["dashed"] = Dashed;
        obj["filled"] = Filled;
        Json::Value@ pts = Json::Array();
        for (uint i = 0; i < Vertices.Length; i++) {
            pts.Add(SerializePoint(Vertices[i]));
        }
        obj["vertices"] = pts;
        return obj;
    }
}

class CurvedArrow : Drawable {
    vec2 Start;
    vec2 End;
    vec2 Control;
    float Thickness;
    bool Dashed;
    bool AwaitingBend;

    CurvedArrow() {
        super();
        Thickness = 4.0f;
        Dashed = false;
        AwaitingBend = false;
    }

    vec2 Sample(float t) {
        float u = 1.0f - t;
        return Start * (u * u) + Control * (2.0f * u * t) + End * (t * t);
    }

    void Draw(UI::DrawList@ drawList, float alphaMul) override {
        vec4 c = vec4(Color.x, Color.y, Color.z, Color.w * alphaMul);
        int segments = 32;
        vec2 prev = Start;
        if (Dashed) {
            float phase = 0.0f;
            for (int i = 1; i <= segments; i++) {
                vec2 p = Sample(float(i) / float(segments));
                phase = DrawDashedSegment(drawList, prev, p, c, Thickness, phase);
                prev = p;
            }
        } else {
            for (int i = 1; i <= segments; i++) {
                vec2 p = Sample(float(i) / float(segments));
                drawList.AddLine(prev, p, c, Thickness);
                prev = p;
            }
        }
        vec2 tangent = End - Control;
        float tlen = Math::Sqrt(tangent.x * tangent.x + tangent.y * tangent.y);
        if (tlen < 0.01f) {
            tangent = End - Start;
            tlen = Math::Sqrt(tangent.x * tangent.x + tangent.y * tangent.y);
            if (tlen < 0.01f) return;
        }
        DrawArrowhead(drawList, End, vec2(tangent.x / tlen, tangent.y / tlen), Thickness, c);
    }

    bool HitTest(const vec2 &in pos, float radius) override {
        float threshold = radius + Thickness * 0.5f;
        int segments = 24;
        vec2 prev = Start;
        for (int i = 1; i <= segments; i++) {
            vec2 p = Sample(float(i) / float(segments));
            if (PointToSegmentDistance(pos, prev, p) <= threshold) return true;
            prev = p;
        }
        return false;
    }

    void Translate(const vec2 &in delta) override {
        Start = Start + delta;
        End = End + delta;
        Control = Control + delta;
    }

    void Bounds(vec2 &out boundsMin, vec2 &out boundsMax) override {
        boundsMin = vec2(
            Math::Min(Math::Min(Start.x, End.x), Control.x),
            Math::Min(Math::Min(Start.y, End.y), Control.y));
        boundsMax = vec2(
            Math::Max(Math::Max(Start.x, End.x), Control.x),
            Math::Max(Math::Max(Start.y, End.y), Control.y));
    }

    array<vec2> GetHandles() override {
        array<vec2> h;
        h.InsertLast(Start);
        h.InsertLast(End);
        h.InsertLast(Control);
        return h;
    }

    void MoveHandle(int index, const vec2 &in pos) override {
        if (index == 0) Start = pos;
        else if (index == 1) End = pos;
        else if (index == 2) Control = pos;
    }

    bool IsNonDegenerate() override { return Distance(Start, End) >= 4.0f; }

    Json::Value@ Serialize() override {
        Json::Value@ obj = Drawable::Serialize();
        obj["type"] = "curvedarrow";
        obj["thickness"] = Thickness;
        obj["dashed"] = Dashed;
        obj["start"] = SerializePoint(Start);
        obj["end"] = SerializePoint(End);
        obj["control"] = SerializePoint(Control);
        return obj;
    }
}

class PaletteColor {
    string Id;
    string Label;
    vec4 Color;

    PaletteColor(const string &in id, const string &in label, const vec4 &in color) {
        Id = id;
        Label = label;
        Color = color;
    }
}
