// Translucent-fill union meshing.
//
// A translucent shape (highlighter stroke, filled polygon) rendered as a series of
// overlapping primitives stacks alpha at every overlap, so a self-crossing path or a
// triangulated fill comes out patchwork-darker. ImGui has no API to disable AA on fills,
// and Openplanet doesn't expose AddConvexPolyFilled — so we instead render the shape as
// a list of axis-aligned filled rects whose union equals the shape. Every pixel inside
// the union gets exactly one fill. Adjacent rects still share AA-fringed edges (the
// underlying ImGui limitation), but the artifact is less visually prominent than
// diagonal triangulation seams.
//
// Algorithm: rasterize the shape onto a coarse boolean grid (CELL pixels per cell),
// then greedy-mesh consecutive marked cells into maximal axis-aligned rectangles.
// Performance: O(bbox_area / CELL^2) per build. A typical highlighter stroke
// (~600x300 px bbox at CELL=2) builds in well under 10ms; MAX_GRID_AREA caps
// pathological cases and the caller falls back to per-segment rendering.

const float MESH_CELL = 2.0f;
const int MESH_MAX_GRID_AREA = 4 * 1024 * 1024;

// Builds the union mesh for a polyline of `points` swept by a disc of radius `r`.
// Returns an empty array if the input is degenerate or the bounding box exceeds
// MESH_MAX_GRID_AREA cells.
array<vec4> BuildStrokeUnionMesh(const array<vec2> &in points, float r) {
    array<vec4> mesh;
    if (points.Length == 0 || r <= 0.0f) return mesh;

    vec2 mn, mx;
    ComputeBounds(points, mn, mx);
    // Pad by r (disc radius) plus one cell of slack so cells on the boundary aren't clipped.
    mn = vec2(mn.x - r - MESH_CELL, mn.y - r - MESH_CELL);
    mx = vec2(mx.x + r + MESH_CELL, mx.y + r + MESH_CELL);

    int nx = int(Math::Ceil((mx.x - mn.x) / MESH_CELL));
    int ny = int(Math::Ceil((mx.y - mn.y) / MESH_CELL));
    if (nx <= 0 || ny <= 0) return mesh;
    if (float(nx) * float(ny) > float(MESH_MAX_GRID_AREA)) return mesh;

    array<bool> grid;
    grid.Resize(uint(nx * ny));

    if (points.Length == 1) {
        RasterizeDiscIntoGrid(grid, nx, ny, mn, points[0], r);
    } else {
        for (uint i = 0; i + 1 < points.Length; i++) {
            RasterizeStadiumIntoGrid(grid, nx, ny, mn, points[i], points[i + 1], r);
        }
    }

    GreedyMeshIntoRects(grid, nx, ny, mn, mesh);
    return mesh;
}

// Builds the fill mesh for a simple polygon under the even-odd fill rule.
array<vec4> BuildPolygonFillMesh(const array<vec2> &in vertices) {
    array<vec4> mesh;
    if (vertices.Length < 3) return mesh;

    vec2 mn, mx;
    ComputeBounds(vertices, mn, mx);
    mn = vec2(mn.x - MESH_CELL, mn.y - MESH_CELL);
    mx = vec2(mx.x + MESH_CELL, mx.y + MESH_CELL);

    int nx = int(Math::Ceil((mx.x - mn.x) / MESH_CELL));
    int ny = int(Math::Ceil((mx.y - mn.y) / MESH_CELL));
    if (nx <= 0 || ny <= 0) return mesh;
    if (float(nx) * float(ny) > float(MESH_MAX_GRID_AREA)) return mesh;

    array<bool> grid;
    grid.Resize(uint(nx * ny));

    // Horizontal scanline. For each row's center y, find x intersections with polygon
    // edges, sort, and mark cells between consecutive pairs. An edge contributes one
    // crossing iff exactly one endpoint has y' > y (strict) — this skips horizontal
    // edges and gives consistent counts at vertex coincidences.
    array<float> xs;
    for (int yi = 0; yi < ny; yi++) {
        float y = mn.y + (float(yi) + 0.5f) * MESH_CELL;
        xs.Resize(0);
        for (uint k = 0; k < vertices.Length; k++) {
            vec2 a = vertices[k];
            vec2 b = vertices[(k + 1) % vertices.Length];
            if ((a.y > y) == (b.y > y)) continue;
            float t = (y - a.y) / (b.y - a.y);
            xs.InsertLast(a.x + t * (b.x - a.x));
        }
        for (uint i = 1; i < xs.Length; i++) {
            float key = xs[i];
            int j = int(i);
            while (j > 0 && xs[j - 1] > key) {
                xs[j] = xs[j - 1];
                j--;
            }
            xs[j] = key;
        }
        int rowBase = yi * nx;
        for (uint i = 0; i + 1 < xs.Length; i += 2) {
            int xiStart = int(Math::Ceil((xs[i] - mn.x) / MESH_CELL - 0.5f));
            int xiEnd = int(Math::Floor((xs[i + 1] - mn.x) / MESH_CELL - 0.5f));
            if (xiStart < 0) xiStart = 0;
            if (xiEnd >= nx) xiEnd = nx - 1;
            for (int xi = xiStart; xi <= xiEnd; xi++) {
                grid[uint(rowBase + xi)] = true;
            }
        }
    }

    GreedyMeshIntoRects(grid, nx, ny, mn, mesh);
    return mesh;
}

// Marks every grid cell whose center is within `r` of point `p`.
void RasterizeDiscIntoGrid(array<bool> &inout grid, int nx, int ny, const vec2 &in origin, const vec2 &in p, float r) {
    int minX = int(Math::Floor((p.x - r - origin.x) / MESH_CELL));
    int maxX = int(Math::Floor((p.x + r - origin.x) / MESH_CELL));
    int minY = int(Math::Floor((p.y - r - origin.y) / MESH_CELL));
    int maxY = int(Math::Floor((p.y + r - origin.y) / MESH_CELL));
    if (minX < 0) minX = 0;
    if (maxX >= nx) maxX = nx - 1;
    if (minY < 0) minY = 0;
    if (maxY >= ny) maxY = ny - 1;
    float r2 = r * r;
    for (int yi = minY; yi <= maxY; yi++) {
        int rowBase = yi * nx;
        float cy = origin.y + (float(yi) + 0.5f) * MESH_CELL;
        float dy = cy - p.y;
        for (int xi = minX; xi <= maxX; xi++) {
            float cx = origin.x + (float(xi) + 0.5f) * MESH_CELL;
            float dx = cx - p.x;
            if (dx * dx + dy * dy <= r2) {
                grid[uint(rowBase + xi)] = true;
            }
        }
    }
}

// Marks every grid cell whose center is within `r` of segment [a, b]. The marked region
// is a stadium (rectangle of width 2r between a and b, with semicircular endpoint caps).
// The inner-loop point-to-segment math is inlined rather than calling
// PointToSegmentDistance because we want squared distance (no Math::Sqrt) and we hoist
// invLenSq once per segment.
void RasterizeStadiumIntoGrid(array<bool> &inout grid, int nx, int ny, const vec2 &in origin, const vec2 &in a, const vec2 &in b, float r) {
    vec2 ab = vec2(b.x - a.x, b.y - a.y);
    float lenSq = ab.x * ab.x + ab.y * ab.y;
    if (lenSq < 0.0001f) {
        RasterizeDiscIntoGrid(grid, nx, ny, origin, a, r);
        return;
    }

    float minWX = Math::Min(a.x, b.x) - r;
    float maxWX = Math::Max(a.x, b.x) + r;
    float minWY = Math::Min(a.y, b.y) - r;
    float maxWY = Math::Max(a.y, b.y) + r;
    int minX = int(Math::Floor((minWX - origin.x) / MESH_CELL));
    int maxX = int(Math::Floor((maxWX - origin.x) / MESH_CELL));
    int minY = int(Math::Floor((minWY - origin.y) / MESH_CELL));
    int maxY = int(Math::Floor((maxWY - origin.y) / MESH_CELL));
    if (minX < 0) minX = 0;
    if (maxX >= nx) maxX = nx - 1;
    if (minY < 0) minY = 0;
    if (maxY >= ny) maxY = ny - 1;

    float invLenSq = 1.0f / lenSq;
    float r2 = r * r;
    for (int yi = minY; yi <= maxY; yi++) {
        int rowBase = yi * nx;
        float cy = origin.y + (float(yi) + 0.5f) * MESH_CELL;
        for (int xi = minX; xi <= maxX; xi++) {
            float cx = origin.x + (float(xi) + 0.5f) * MESH_CELL;
            float pax = cx - a.x;
            float pay = cy - a.y;
            float t = (pax * ab.x + pay * ab.y) * invLenSq;
            if (t < 0.0f) t = 0.0f;
            if (t > 1.0f) t = 1.0f;
            float dx = cx - (a.x + ab.x * t);
            float dy = cy - (a.y + ab.y * t);
            if (dx * dx + dy * dy <= r2) {
                grid[uint(rowBase + xi)] = true;
            }
        }
    }
}

// Greedy meshing of a binary grid into maximal axis-aligned rectangles. Output rects are
// (x1, y1, x2, y2) in world coordinates spanning [x1, x2) x [y1, y2). Adjacent output
// rects abut exactly — no overlap.
void GreedyMeshIntoRects(array<bool> &inout grid, int nx, int ny, const vec2 &in origin, array<vec4> &inout outRects) {
    array<bool> consumed;
    consumed.Resize(grid.Length);

    for (int yi = 0; yi < ny; yi++) {
        int rowBase = yi * nx;
        for (int xi = 0; xi < nx; xi++) {
            uint idx = uint(rowBase + xi);
            if (!grid[idx] || consumed[idx]) continue;

            int x2 = xi;
            while (x2 + 1 < nx) {
                uint j = uint(rowBase + x2 + 1);
                if (!grid[j] || consumed[j]) break;
                x2++;
            }

            int y2 = yi;
            while (y2 + 1 < ny) {
                int nextRow = (y2 + 1) * nx;
                bool rowOk = true;
                for (int x = xi; x <= x2; x++) {
                    uint j = uint(nextRow + x);
                    if (!grid[j] || consumed[j]) {
                        rowOk = false;
                        break;
                    }
                }
                if (!rowOk) break;
                y2++;
            }

            for (int y = yi; y <= y2; y++) {
                int row = y * nx;
                for (int x = xi; x <= x2; x++) {
                    consumed[uint(row + x)] = true;
                }
            }

            float wx1 = origin.x + float(xi) * MESH_CELL;
            float wy1 = origin.y + float(yi) * MESH_CELL;
            float wx2 = origin.x + float(x2 + 1) * MESH_CELL;
            float wy2 = origin.y + float(y2 + 1) * MESH_CELL;
            outRects.InsertLast(vec4(wx1, wy1, wx2, wy2));
        }
    }
}

// Shifts every rect in `rects` by `delta` in place. Used by Drawable subclasses that
// cache a fill mesh (Stroke for highlighter, Polygon for filled) to keep the mesh
// aligned with the source vertices through Translate without forcing a rebuild.
void TranslateRectArray(array<vec4> &inout rects, const vec2 &in delta) {
    for (uint i = 0; i < rects.Length; i++) {
        rects[i] = vec4(rects[i].x + delta.x, rects[i].y + delta.y, rects[i].z + delta.x, rects[i].w + delta.y);
    }
}

// Filled axis-aligned rectangle from (min, max). Wraps the 4-vec2-corner expansion that
// AddQuadFilled requires.
void DrawFilledRect(UI::DrawList@ drawList, const vec2 &in min, const vec2 &in max, const vec4 &in color) {
    drawList.AddQuadFilled(
        vec2(min.x, min.y),
        vec2(max.x, min.y),
        vec2(max.x, max.y),
        vec2(min.x, max.y),
        color);
}

// Renders a list of (x1, y1, x2, y2) rects as filled quads in `color`.
void DrawRectMesh(UI::DrawList@ drawList, const array<vec4> &in rects, const vec4 &in color) {
    for (uint i = 0; i < rects.Length; i++) {
        vec4 r = rects[i];
        DrawFilledRect(drawList, vec2(r.x, r.y), vec2(r.z, r.w), color);
    }
}
