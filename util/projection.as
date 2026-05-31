
bool TryGetCarY(float &out y) {
    auto vis = VehicleState::ViewingPlayerState();
    if (vis is null) return false;
    y = vis.Position.y;
    return true;
}

bool ProjectWorldToScreen(const vec3 &in world, vec2 &out screen) {
    if (Camera::IsBehind(world)) return false;
    screen = Camera::ToScreenSpace(world);
    return true;
}

bool ScreenToWorldAtY(const vec2 &in screen, float planeY, vec3 &out world) {
    auto cam = Camera::GetCurrent();
    if (cam is null) return false;

    mat4 proj = mat4::Perspective(cam.Fov, cam.Width_Height, cam.NearZ, cam.FarZ);
    mat4 trans = mat4::Translate(vec3(cam.Location.tx, cam.Location.ty, cam.Location.tz));
    mat4 rot = mat4::Inverse(mat4::Inverse(trans) * mat4(cam.Location));
    mat4 vp = proj * mat4::Inverse(trans * rot);
    mat4 vpInv = mat4::Inverse(vp);

    vec2 dispSize = Display::GetSize();
    if (dispSize.x < 1.0f || dispSize.y < 1.0f) return false;

    float xNdc = 2.0f * screen.x / dispSize.x - 1.0f;
    float yNdc = 2.0f * screen.y / dispSize.y - 1.0f;

    vec4 nearH = vpInv * vec4(xNdc, yNdc, -1.0f, 1.0f);
    vec4 farH = vpInv * vec4(xNdc, yNdc, 1.0f, 1.0f);
    if (Math::Abs(nearH.w) < 0.0001f || Math::Abs(farH.w) < 0.0001f) return false;
    vec3 nearW = vec3(nearH.x / nearH.w, nearH.y / nearH.w, nearH.z / nearH.w);
    vec3 farW = vec3(farH.x / farH.w, farH.y / farH.w, farH.z / farH.w);
    vec3 dir = farW - nearW;

    if (Math::Abs(dir.y) < 0.0001f) return false;
    float t = (planeY - nearW.y) / dir.y;
    if (t < 0.0f) return false;
    world = vec3(nearW.x + dir.x * t, planeY, nearW.z + dir.z * t);
    return true;
}

bool ComputeWorldAnchor(const vec2 &in screen, vec3 &out world) {
    if (!IsInMap()) return false;
    float carY;
    if (!TryGetCarY(carY)) return false;
    return ScreenToWorldAtY(screen, carY, world);
}

bool GetAnchorOffset(const vec3 &in worldAnchor, const vec2 &in screenAnchorAtCommit, vec2 &out offset) {
    if (Camera::GetCurrent() is null) return false;
    if (Camera::IsBehind(worldAnchor)) return false;
    vec2 nowScreen = Camera::ToScreenSpace(worldAnchor);
    offset = nowScreen - screenAnchorAtCommit;
    return true;
}

float WorldYPerScreenPixel(const vec3 &in anchor) {
    if (Camera::GetCurrent() is null) return 0.0f;
    if (Camera::IsBehind(anchor)) return 0.0f;
    vec3 probe = vec3(anchor.x, anchor.y + 1.0f, anchor.z);
    if (Camera::IsBehind(probe)) return 0.0f;
    vec2 sA = Camera::ToScreenSpace(anchor);
    vec2 sB = Camera::ToScreenSpace(probe);
    float pxPerMeter = sA.y - sB.y;
    if (Math::Abs(pxPerMeter) < 0.0001f) return 0.0f;
    return 1.0f / pxPerMeter;
}
