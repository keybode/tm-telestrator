// World-anchor projection helpers.
//
// When S_WorldAnchor is on, a fresh mark captures a world-space anchor point at press
// time. Each frame, the anchor is forward-projected to screen via the Camera dependency
// and the drawable is rigidly translated by (currentScreen - screenAtCommit) so it
// "sticks" to that world location as the camera moves. Shape geometry is otherwise
// untouched — no perspective deformation, just a translate.
//
// Forward projection comes free from openplanet-nl/camera (Camera::ToScreenSpace). The
// reverse direction (screen pixel -> world point) is not exposed by Openplanet, so we
// rebuild the camera's view-projection matrix from CHmsCamera fields, invert it, and
// intersect the resulting ray with a horizontal Y-plane. Y is sampled from the player
// car's altitude at click time via VehicleState::ViewingPlayerState — works for ground
// marks on most TM tracks; elevated ramps/loops will drift unless the user re-anchors.
//
// Both Camera and VehicleState are essential dependencies so they're always present when
// the plugin loads (declared in info.toml [script] dependencies).

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

// Inverts the current camera's view-projection through the horizontal plane Y = planeY
// and returns the world point that re-projects to `screen`. Replicates the matrix
// composition from openplanet-nl/camera Impl.as so the inverse round-trips the same
// transform Camera::ToScreenSpace uses.
//
// Returns false if: camera unavailable, display has zero size, the ray is parallel to
// the plane, the intersection is behind the near plane, or w-divide is degenerate.
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

    // Match the camera plugin's forward NDC convention: screen = (ndc + 1) / 2 * dispSize.
    // No y-flip — the plugin doesn't flip on the way out, so we don't on the way in.
    float xNdc = 2.0f * screen.x / dispSize.x - 1.0f;
    float yNdc = 2.0f * screen.y / dispSize.y - 1.0f;

    // Two clip-space points along the camera ray (near=-1, far=+1 in NDC z).
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

// Top-level helper used at tool-press time. Returns false if anchoring isn't possible
// right now (not in a map, no controlled car, or ray misses the plane), in which case
// the caller should fall back to a plain screen-space mark.
bool ComputeWorldAnchor(const vec2 &in screen, vec3 &out world) {
    if (!IsInMap()) return false;
    float carY;
    if (!TryGetCarY(carY)) return false;
    return ScreenToWorldAtY(screen, carY, world);
}

// Per-frame translation offset for a world-anchored drawable. Returns false when the
// anchor is currently behind the camera or no camera is active — DrawAll uses that as
// a signal to skip rendering rather than show the drawable at a stale screen position.
bool GetAnchorOffset(const vec3 &in worldAnchor, const vec2 &in screenAnchorAtCommit, vec2 &out offset) {
    if (Camera::GetCurrent() is null) return false;
    if (Camera::IsBehind(worldAnchor)) return false;
    vec2 nowScreen = Camera::ToScreenSpace(worldAnchor);
    offset = nowScreen - screenAnchorAtCommit;
    return true;
}
