// Highlighter union-mesh builder.
//
// A highlighter stroke is a polyline drawn with a translucent color (alpha ~0.35). If we
// render it as a series of overlapping line segments + vertex discs, every pixel inside
// the swept-disc shape gets painted multiple times — once per segment that covers it,
// plus once per disc. The translucent color stacks at every overlap, so a self-crossing
// path comes out patchwork-darker (see the user-reported screenshot).
//
// To avoid that, we render each stroke as a single uniform-alpha shape: a list of
// axis-aligned filled rectangles whose union exactly equals the swept-disc shape of the
// polyline with radius r. Every pixel inside the union gets exactly one fill, so alpha
// is uniform across the whole stroke regardless of how many times the path crosses
// itself. Crossing a *different* stroke still stacks alpha, which matches the user spec
// ("don't overlap unless I start drawing again").
//
// Algorithm: rasterize each segment's stadium (rect + endpoint discs) into a coarse
// boolean grid (CELL pixels per cell), then greedy-mesh consecutive marked cells into
// maximal axis-aligned rectangles. The result is typically a few dozen to a couple
// hundred rects per stroke.
//
// Performance: O(bbox_area / CELL^2) for both rasterize and greedy-mesh. A typical
// highlighter stroke (~600x300 px bbox at CELL=2) runs in well under 10ms. The cap
// (MAX_GRID_AREA) bails out for pathological inputs and the caller falls back to plain
// per-segment rendering.

const float MESH_CELL = 2.0f;
const int MESH_MAX_GRID_AREA = 4 * 1024 * 1024;

// Builds the union mesh for a highlighter stroke of `points` swept by a disc of radius
// `r`. Returns an empty array if the stroke is degenerate or the bounding box exceeds
// MESH_MAX_GRID_AREA cells (caller is expected to render the fallback per-segment path
// in that case).
array<vec4> BuildStrokeUnionMesh(const array<vec2> &in points, float r) {
    array<vec4> mesh;
    if (points.Length == 0 || r <= 0.0f) return mesh;

    vec2 mn = points[0];
    vec2 mx = points[0];
    for (uint i = 1; i < points.Length; i++) {
        if (points[i].x < mn.x) mn.x = points[i].x;
        if (points[i].y < mn.y) mn.y = points[i].y;
        if (points[i].x > mx.x) mx.x = points[i].x;
        if (points[i].y > mx.y) mx.y = points[i].y;
    }
    // Pad the bbox by r (disc radius) plus one cell of slack so cells whose centers fall
    // exactly on the bbox edge are still inside the grid.
    mn = vec2(mn.x - r - MESH_CELL, mn.y - r - MESH_CELL);
    mx = vec2(mx.x + r + MESH_CELL, mx.y + r + MESH_CELL);

    int nx = int(Math::Ceil((mx.x - mn.x) / MESH_CELL));
    int ny = int(Math::Ceil((mx.y - mn.y) / MESH_CELL));
    if (nx <= 0 || ny <= 0) return mesh;
    if (float(nx) * float(ny) > float(MESH_MAX_GRID_AREA)) return mesh;

    array<bool> grid;
    grid.Resize(uint(nx * ny));
    for (uint i = 0; i < grid.Length; i++) grid[i] = false;

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
        for (int xi = minX; xi <= maxX; xi++) {
            float cx = origin.x + (float(xi) + 0.5f) * MESH_CELL;
            float cy = origin.y + (float(yi) + 0.5f) * MESH_CELL;
            float dx = cx - p.x;
            float dy = cy - p.y;
            if (dx * dx + dy * dy <= r2) {
                grid[uint(yi * nx + xi)] = true;
            }
        }
    }
}

// Marks every grid cell whose center is within `r` of segment [a, b]. The marked region
// is the stadium (capsule): rectangle of width 2r between a and b, with semicircular
// caps at both endpoints.
void RasterizeStadiumIntoGrid(array<bool> &inout grid, int nx, int ny, const vec2 &in origin, const vec2 &in a, const vec2 &in b, float r) {
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

    vec2 ab = vec2(b.x - a.x, b.y - a.y);
    float lenSq = ab.x * ab.x + ab.y * ab.y;
    float r2 = r * r;

    if (lenSq < 0.0001f) {
        // Degenerate segment — same point twice. Treat as a disc.
        for (int yi = minY; yi <= maxY; yi++) {
            for (int xi = minX; xi <= maxX; xi++) {
                float cx = origin.x + (float(xi) + 0.5f) * MESH_CELL;
                float cy = origin.y + (float(yi) + 0.5f) * MESH_CELL;
                float dx = cx - a.x;
                float dy = cy - a.y;
                if (dx * dx + dy * dy <= r2) {
                    grid[uint(yi * nx + xi)] = true;
                }
            }
        }
        return;
    }

    float invLenSq = 1.0f / lenSq;
    for (int yi = minY; yi <= maxY; yi++) {
        for (int xi = minX; xi <= maxX; xi++) {
            float cx = origin.x + (float(xi) + 0.5f) * MESH_CELL;
            float cy = origin.y + (float(yi) + 0.5f) * MESH_CELL;
            // Project cell center onto segment, clamp to [0, 1] for the caps.
            float pax = cx - a.x;
            float pay = cy - a.y;
            float t = (pax * ab.x + pay * ab.y) * invLenSq;
            if (t < 0.0f) t = 0.0f;
            if (t > 1.0f) t = 1.0f;
            float dx = cx - (a.x + ab.x * t);
            float dy = cy - (a.y + ab.y * t);
            if (dx * dx + dy * dy <= r2) {
                grid[uint(yi * nx + xi)] = true;
            }
        }
    }
}

// Builds a list of axis-aligned filled rectangles whose union covers the interior of
// the simple polygon `vertices` (even-odd fill rule). Caller renders each rect with
// AddQuadFilled. Replaces per-triangle ear-clipping fill, which leaked visible AA-fringe
// seams along every triangulation edge — adjacent filled primitives' fringes stack and
// produce a darker stripe at every shared edge regardless of orientation. Greedy-meshed
// axis-aligned rects abut at the same kind of shared edges, but in practice they tend
// to be longer/fewer than ear-clipping triangle edges and at integer-pixel positions, so
// the stacking artifact is less visually prominent.
//
// Returns empty if the polygon is degenerate or its bbox exceeds MESH_MAX_GRID_AREA
// cells; the caller is expected to fall back to triangulated rendering in that case.
array<vec4> BuildPolygonFillMesh(const array<vec2> &in vertices) {
    array<vec4> mesh;
    if (vertices.Length < 3) return mesh;

    vec2 mn = vertices[0];
    vec2 mx = vertices[0];
    for (uint i = 1; i < vertices.Length; i++) {
        if (vertices[i].x < mn.x) mn.x = vertices[i].x;
        if (vertices[i].y < mn.y) mn.y = vertices[i].y;
        if (vertices[i].x > mx.x) mx.x = vertices[i].x;
        if (vertices[i].y > mx.y) mx.y = vertices[i].y;
    }
    // One cell of margin so cells whose centers sit on the bbox don't get clipped.
    mn = vec2(mn.x - MESH_CELL, mn.y - MESH_CELL);
    mx = vec2(mx.x + MESH_CELL, mx.y + MESH_CELL);

    int nx = int(Math::Ceil((mx.x - mn.x) / MESH_CELL));
    int ny = int(Math::Ceil((mx.y - mn.y) / MESH_CELL));
    if (nx <= 0 || ny <= 0) return mesh;
    if (float(nx) * float(ny) > float(MESH_MAX_GRID_AREA)) return mesh;

    array<bool> grid;
    grid.Resize(uint(nx * ny));
    for (uint i = 0; i < grid.Length; i++) grid[i] = false;

    // Horizontal scanline rasterization. For each row's center y, find x intersections
    // of polygon edges with the line y, sort, then mark cells between consecutive
    // intersection pairs. Convention: an edge contributes one crossing if exactly one
    // endpoint has y' > y (strict) — this skips horizontal edges (would div-by-zero on
    // the t computation) and gives consistent counts at vertex coincidences.
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
        for (uint i = 0; i + 1 < xs.Length; i += 2) {
            float xStart = xs[i];
            float xEnd = xs[i + 1];
            int xiStart = int(Math::Ceil((xStart - mn.x) / MESH_CELL - 0.5f));
            int xiEnd = int(Math::Floor((xEnd - mn.x) / MESH_CELL - 0.5f));
            if (xiStart < 0) xiStart = 0;
            if (xiEnd >= nx) xiEnd = nx - 1;
            for (int xi = xiStart; xi <= xiEnd; xi++) {
                grid[uint(yi * nx + xi)] = true;
            }
        }
    }

    GreedyMeshIntoRects(grid, nx, ny, mn, mesh);
    return mesh;
}

// Greedy meshing of a binary grid into maximal axis-aligned rectangles. Each marked cell
// is consumed by exactly one output rect, so the union of the rects equals the union of
// the marked cells. Output rects are in world coordinates: (x1, y1, x2, y2) where the
// rect spans [x1, x2) x [y1, y2). Adjacent rects abut exactly, no overlap.
void GreedyMeshIntoRects(array<bool> &inout grid, int nx, int ny, const vec2 &in origin, array<vec4> &inout outRects) {
    array<bool> consumed;
    consumed.Resize(grid.Length);
    for (uint i = 0; i < consumed.Length; i++) consumed[i] = false;

    for (int yi = 0; yi < ny; yi++) {
        for (int xi = 0; xi < nx; xi++) {
            uint idx = uint(yi * nx + xi);
            if (!grid[idx] || consumed[idx]) continue;

            // Extend right as far as marked-and-unconsumed cells go.
            int x2 = xi;
            while (x2 + 1 < nx) {
                uint j = uint(yi * nx + (x2 + 1));
                if (!grid[j] || consumed[j]) break;
                x2++;
            }

            // Extend down as far as every cell in the [xi..x2] strip is marked-and-unconsumed.
            int y2 = yi;
            while (y2 + 1 < ny) {
                bool rowOk = true;
                for (int x = xi; x <= x2; x++) {
                    uint j = uint((y2 + 1) * nx + x);
                    if (!grid[j] || consumed[j]) {
                        rowOk = false;
                        break;
                    }
                }
                if (!rowOk) break;
                y2++;
            }

            for (int y = yi; y <= y2; y++) {
                for (int x = xi; x <= x2; x++) {
                    consumed[uint(y * nx + x)] = true;
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
