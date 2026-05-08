const string SAVE_FILENAME = "state.json";
const int SAVE_FORMAT_VERSION = 1;

void SaveState() {
    // IO::FromStorageFolder auto-creates the per-plugin storage folder on first call,
    // so no need to FolderExists/CreateFolder beforehand.
    Json::Value@ root = Json::Object();
    root["version"] = SAVE_FORMAT_VERSION;
    root["tool"] = int(g_CurrentTool);
    root["color"] = SerializeColor(g_CurrentColor);
    root["drawingEnabled"] = g_DrawingEnabled;
    root["nextMarker"] = g_NextMarkerNumber;

    Json::Value@ items = Json::Array();
    for (uint i = 0; i < g_Drawables.Length; i++) {
        items.Add(g_Drawables[i].Serialize());
    }
    root["drawables"] = items;

    Json::ToFile(IO::FromStorageFolder(SAVE_FILENAME), root);
}

void LoadState() {
    string path = IO::FromStorageFolder(SAVE_FILENAME);
    if (!IO::FileExists(path)) return;

    Json::Value@ root = Json::FromFile(path);
    if (root is null || root.GetType() != Json::Type::Object) return;

    if (root.HasKey("color")) {
        g_CurrentColor = DeserializeColor(root["color"]);
    }
    if (root.HasKey("tool")) {
        int t = int(root["tool"]);
        // Upper bound must track the last appended Tool enum member.
        if (t >= int(Tool::Pen) && t <= int(Tool::CurvedArrow)) {
            g_CurrentTool = Tool(t);
        }
    }
    if (root.HasKey("drawingEnabled")) {
        g_DrawingEnabled = bool(root["drawingEnabled"]);
    }
    if (root.HasKey("nextMarker")) {
        g_NextMarkerNumber = int(root["nextMarker"]);
    }

    if (root.HasKey("drawables") && root["drawables"].GetType() == Json::Type::Array) {
        Json::Value@ arr = root["drawables"];
        for (uint i = 0; i < arr.Length; i++) {
            Drawable@ d = DeserializeDrawable(arr[i]);
            if (d !is null) g_Drawables.InsertLast(d);
        }
    }

    // Ensure marker numbering continues past whatever was loaded.
    for (uint i = 0; i < g_Drawables.Length; i++) {
        NumberMarker@ m = cast<NumberMarker>(g_Drawables[i]);
        if (m !is null && m.Number >= g_NextMarkerNumber) {
            g_NextMarkerNumber = m.Number + 1;
        }
    }
}

Drawable@ DeserializeDrawable(Json::Value@ obj) {
    if (obj is null || obj.GetType() != Json::Type::Object) return null;
    if (!obj.HasKey("type")) return null;

    string type = string(obj["type"]);
    Drawable@ d = null;

    if (type == "stroke") {
        Stroke@ s = Stroke();
        if (obj.HasKey("thickness")) s.Thickness = float(obj["thickness"]);
        if (obj.HasKey("dashed")) s.Dashed = bool(obj["dashed"]);
        if (obj.HasKey("points") && obj["points"].GetType() == Json::Type::Array) {
            Json::Value@ pts = obj["points"];
            for (uint i = 0; i < pts.Length; i++) {
                s.Points.InsertLast(DeserializePoint(pts[i]));
            }
        }
        @d = s;
    } else if (type == "arrow") {
        Arrow@ a = Arrow();
        if (obj.HasKey("thickness")) a.Thickness = float(obj["thickness"]);
        if (obj.HasKey("dashed")) a.Dashed = bool(obj["dashed"]);
        if (obj.HasKey("start")) a.Start = DeserializePoint(obj["start"]);
        if (obj.HasKey("end")) a.End = DeserializePoint(obj["end"]);
        @d = a;
    } else if (type == "line") {
        LineSeg@ l = LineSeg();
        if (obj.HasKey("thickness")) l.Thickness = float(obj["thickness"]);
        if (obj.HasKey("dashed")) l.Dashed = bool(obj["dashed"]);
        if (obj.HasKey("start")) l.Start = DeserializePoint(obj["start"]);
        if (obj.HasKey("end")) l.End = DeserializePoint(obj["end"]);
        @d = l;
    } else if (type == "rect") {
        RectShape@ r = RectShape();
        if (obj.HasKey("thickness")) r.Thickness = float(obj["thickness"]);
        if (obj.HasKey("corner1")) r.Corner1 = DeserializePoint(obj["corner1"]);
        if (obj.HasKey("corner2")) r.Corner2 = DeserializePoint(obj["corner2"]);
        @d = r;
    } else if (type == "circle") {
        CircleShape@ ci = CircleShape();
        if (obj.HasKey("thickness")) ci.Thickness = float(obj["thickness"]);
        if (obj.HasKey("center")) ci.Center = DeserializePoint(obj["center"]);
        if (obj.HasKey("radius")) ci.Radius = float(obj["radius"]);
        @d = ci;
    } else if (type == "ellipse") {
        EllipseShape@ e = EllipseShape();
        if (obj.HasKey("thickness")) e.Thickness = float(obj["thickness"]);
        if (obj.HasKey("corner1")) e.Corner1 = DeserializePoint(obj["corner1"]);
        if (obj.HasKey("corner2")) e.Corner2 = DeserializePoint(obj["corner2"]);
        @d = e;
    } else if (type == "text") {
        TextLabel@ t = TextLabel();
        if (obj.HasKey("position")) t.Position = DeserializePoint(obj["position"]);
        if (obj.HasKey("text")) t.Text = string(obj["text"]);
        if (obj.HasKey("size")) t.Size = float(obj["size"]);
        @d = t;
    } else if (type == "marker") {
        NumberMarker@ m = NumberMarker();
        if (obj.HasKey("position")) m.Position = DeserializePoint(obj["position"]);
        if (obj.HasKey("number")) m.Number = int(obj["number"]);
        if (obj.HasKey("size")) m.Size = float(obj["size"]);
        @d = m;
    } else if (type == "measurement") {
        Measurement@ ms = Measurement();
        if (obj.HasKey("thickness")) ms.Thickness = float(obj["thickness"]);
        if (obj.HasKey("dashed")) ms.Dashed = bool(obj["dashed"]);
        if (obj.HasKey("start")) ms.Start = DeserializePoint(obj["start"]);
        if (obj.HasKey("end")) ms.End = DeserializePoint(obj["end"]);
        @d = ms;
    } else if (type == "bracket") {
        Bracket@ b = Bracket();
        if (obj.HasKey("thickness")) b.Thickness = float(obj["thickness"]);
        if (obj.HasKey("dashed")) b.Dashed = bool(obj["dashed"]);
        if (obj.HasKey("start")) b.Start = DeserializePoint(obj["start"]);
        if (obj.HasKey("end")) b.End = DeserializePoint(obj["end"]);
        @d = b;
    } else if (type == "polygon") {
        Polygon@ p = Polygon();
        if (obj.HasKey("thickness")) p.Thickness = float(obj["thickness"]);
        if (obj.HasKey("dashed")) p.Dashed = bool(obj["dashed"]);
        if (obj.HasKey("filled")) p.Filled = bool(obj["filled"]);
        if (obj.HasKey("vertices") && obj["vertices"].GetType() == Json::Type::Array) {
            Json::Value@ pts = obj["vertices"];
            for (uint i = 0; i < pts.Length; i++) {
                p.Vertices.InsertLast(DeserializePoint(pts[i]));
            }
        }
        @d = p;
    } else if (type == "curvedarrow") {
        CurvedArrow@ ca = CurvedArrow();
        if (obj.HasKey("thickness")) ca.Thickness = float(obj["thickness"]);
        if (obj.HasKey("dashed")) ca.Dashed = bool(obj["dashed"]);
        if (obj.HasKey("start")) ca.Start = DeserializePoint(obj["start"]);
        if (obj.HasKey("end")) ca.End = DeserializePoint(obj["end"]);
        if (obj.HasKey("control")) ca.Control = DeserializePoint(obj["control"]);
        @d = ca;
    }

    if (d !is null && obj.HasKey("color")) {
        d.Color = DeserializeColor(obj["color"]);
    }
    return d;
}

Json::Value@ SerializeColor(const vec4 &in c) {
    Json::Value@ arr = Json::Array();
    arr.Add(Json::Value(c.x));
    arr.Add(Json::Value(c.y));
    arr.Add(Json::Value(c.z));
    arr.Add(Json::Value(c.w));
    return arr;
}

vec4 DeserializeColor(Json::Value@ v) {
    if (v is null || v.GetType() != Json::Type::Array || v.Length < 4) {
        return vec4(1.0f, 1.0f, 1.0f, 1.0f);
    }
    return vec4(float(v[0]), float(v[1]), float(v[2]), float(v[3]));
}

Json::Value@ SerializePoint(const vec2 &in p) {
    Json::Value@ arr = Json::Array();
    arr.Add(Json::Value(p.x));
    arr.Add(Json::Value(p.y));
    return arr;
}

vec2 DeserializePoint(Json::Value@ v) {
    if (v is null || v.GetType() != Json::Type::Array || v.Length < 2) {
        return vec2(0, 0);
    }
    return vec2(float(v[0]), float(v[1]));
}
