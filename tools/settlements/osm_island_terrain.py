"""A terrain grid for a small island from its OpenStreetMap outline (VTER-ISLAND-DEM).

A 30-90 m DEM smears a 3.5 ha island into a 9-19 ha hill (SRTM is a surface
model and a cell straddling the shore is half water), so VillageIslandForm
cannot see it. The island's own outline is the land mask: inside it a low dome
over the lake level, outside it a bed falling away. The heights are a profile,
NOT a measurement; only the shoreline is real (OSM way `osm_id`, ODbL).

    python tools/settlements/osm_island_terrain.py outline.json out.json \
        --lat0 45.90105 --lon0 8.52030 --level 191.5 --cell 8 --half 448

`outline.json` is an Overpass `out geom` answer holding the way. The grid is in
plan axes about (lat0, lon0) as survey.py terrain writes it: +x east, +z south.
"""
import argparse
import json
import math


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("outline")
    ap.add_argument("out")
    ap.add_argument("--lat0", type=float, required=True)
    ap.add_argument("--lon0", type=float, required=True)
    ap.add_argument("--level", type=float, required=True, help="the lake's surface, m")
    ap.add_argument("--cell", type=float, default=8.0)
    ap.add_argument("--half", type=float, default=448.0)
    ap.add_argument("--osm-id", type=int, default=0)
    a = ap.parse_args()
    d = json.load(open(a.outline, encoding="utf-8"))
    way = next(e for e in d["elements"] if e["type"] == "way" and (not a.osm_id or e["id"] == a.osm_id))
    kx = 111320.0 * math.cos(math.radians(a.lat0))
    kz = 110574.0
    poly = [((p["lon"] - a.lon0) * kx, -(p["lat"] - a.lat0) * kz) for p in way["geometry"]]
    n = int(round(2 * a.half / a.cell)) + 1
    x0 = -a.half

    def inside(px, pz):
        c = False
        j = len(poly) - 1
        for i in range(len(poly)):
            (xi, zi), (xj, zj) = poly[i], poly[j]
            if (zi > pz) != (zj > pz) and px < xi + (pz - zi) * (xj - xi) / (zj - zi):
                c = not c
            j = i
        return c

    def edge_dist(px, pz):
        best = 1e18
        for i in range(len(poly)):
            (ax, az), (bx, bz) = poly[i], poly[(i + 1) % len(poly)]
            dx, dz = bx - ax, bz - az
            t = max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz or 1.0)))
            best = min(best, math.hypot(px - ax - t * dx, pz - az - t * dz))
        return best

    hs = []
    land = 0
    for r in range(n):
        for c in range(n):
            px, pz = x0 + c * a.cell, x0 + r * a.cell
            e = edge_dist(px, pz)
            if inside(px, pz):
                land += 1
                hs.append(round(a.level + 0.6 + min(2.0, 0.15 * e), 2))
            else:
                hs.append(round(a.level - 0.6 - min(3.0, 0.1 * e), 2))
    doc = {"schema": "brickwild.terrain", "schema_version": 1,
           "about": f"Isola dei Pescatori: the shoreline is OpenStreetMap way {way['id']} (ODbL); the heights "
                    f"are a dome of 0.6-2.6 m over the lake and a bed falling away, not a measurement. "
                    f"{a.cell:g} m grid about {a.lat0:.5f}, {a.lon0:.5f}; written by "
                    f"tools/settlements/osm_island_terrain.py (VTER-ISLAND-DEM)",
           "origin_m": [x0, x0], "cell_m": a.cell, "cols": n, "rows": n,
           "heights_m": hs, "water_level_m": a.level}
    json.dump(doc, open(a.out, "w", encoding="utf-8"), indent=None)
    print(f"{n}x{n} cells, {land} land cells = {land * a.cell * a.cell / 1e4:.2f} ha; outline area "
          f"{abs(sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))) / 2e4:.2f} ha")


main()
