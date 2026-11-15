"""What a person walking a real village would notice, from the survey's own
OSM cache (no network): how big the buildings are as a DISTRIBUTION, what
they are, how far apart they stand wall to wall, how many touch, and how far
a town wall stands from the houses inside it.

The survey (survey.py measure()) kept medians of these per site. The
generator needs the shapes of the distributions, so this reads the cached
Overpass answers again and writes them out per site and pooled by culture.

    python -I tools/settlements/layout_stats.py --data artifacts/settlements \
        --repo . --out tests/fixtures/settlements/layout_stats.json

Offline only: a site whose Overpass answer is not cached is skipped.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import numpy as np  # noqa: E402
import shapely  # noqa: E402
from shapely.geometry import Point  # noqa: E402
from shapely.strtree import STRtree  # noqa: E402

import survey as sv  # noqa: E402

# OSM building values that are not a home, a shop or a hall someone stands in
OUTBUILDING = {"shed", "garage", "garages", "farm_auxiliary", "barn", "stable", "cowshed", "sty",
               "hut", "carport", "greenhouse", "storage_tank", "service", "kiosk", "toilets",
               "boathouse", "outbuilding", "shelter", "roof", "container", "bunker", "transformer_tower",
               "silo", "hangar", "tank", "ruins", "construction"}
CIVIC = {"church", "chapel", "cathedral", "mosque", "temple", "shrine", "monastery", "school",
         "public", "civic", "government", "hospital", "townhall", "train_station", "college",
         "university", "kindergarten", "fire_station", "sports_hall", "stadium", "castle",
         "fort", "palace", "museum", "bell_tower", "tower", "religious"}
WORK = {"industrial", "commercial", "retail", "warehouse", "office", "supermarket", "hotel",
        "manufacture", "factory", "farm"}
HOME = {"house", "detached", "semidetached_house", "terrace", "residential", "apartments",
        "bungalow", "cabin", "dormitory", "static_caravan", "hut", "yes"}


def kind_of(tag: str) -> str:
    if tag in OUTBUILDING:
        return "outbuilding"
    if tag in CIVIC:
        return "civic"
    if tag in WORK:
        return "work"
    return "home" if tag in HOME else "other"


def parse_buildings(js, loc):
    out = []
    for el in js.get("elements", []):
        t = el.get("tags", {})
        if "building" not in t or t["building"] in ("no", "roof", "ruins") or el["type"] == "node":
            continue
        for p in sv.ring_polys(el, loc):
            if p.area >= 6.0:
                out.append((p, t["building"], t))
    return out


def walls_of(js, loc):
    out = []
    for el in js.get("elements", []):
        t = el.get("tags", {})
        if (t.get("barrier") == "city_wall" or t.get("historic") == "citywalls") and el["type"] == "way":
            ln = sv.way_line(el, loc)
            if ln is not None:
                out.append(ln)
    return out


def min_rect_dims(p):
    r = p.minimum_rotated_rectangle
    xs, ys = r.exterior.coords.xy
    e = [math.hypot(xs[i + 1] - xs[i], ys[i + 1] - ys[i]) for i in range(2)]
    return max(e), min(e)


def q(a, qs=(10, 25, 50, 75, 90)):
    a = np.asarray(a, dtype=float)
    if a.size == 0:
        return {}
    return {f"p{k}": round(float(np.percentile(a, k)), 2) for k in qs}


def site_stats(s, cache):
    loc = sv.Local(s["lat"], s["lon"])
    key = sv.site_query(s["lat"], s["lon"], sv.RADIUS_M)
    js = cache.get("overpass", key)
    if js is None:
        return None
    rows = parse_buildings(js, loc)
    disc = Point(0, 0).buffer(sv.RADIUS_M, 64)
    rows = [r for r in rows if disc.contains(r[0].centroid)]
    if len(rows) < sv.MIN_BUILDINGS:
        return None
    cent = np.array([[r[0].centroid.x, r[0].centroid.y] for r in rows])
    k, lab = sv.clusters(cent, sv.CLUSTER_LINK_M)
    near = np.linalg.norm(cent, axis=1) < 250
    score = np.bincount(lab, weights=(1.0 + 2.0 * near))
    main = int(score.argmax())
    body = [rows[i] for i in np.where(lab == main)[0]]
    polys = [r[0] for r in body]
    areas = np.array([p.area for p in polys])
    kinds = [kind_of(r[1]) for r in body]
    tags = Counter(r[1] for r in body)
    dims = [min_rect_dims(p) for p in polys]
    aspect = np.array([a / max(b, 0.5) for a, b in dims])
    # wall to wall: nearest other building's polygon distance
    tree = STRtree(polys)
    gaps = []
    for i, p in enumerate(polys):
        best = math.inf
        for j in tree.query(p.buffer(60.0)):
            j = int(j)
            if j != i:
                best = min(best, p.distance(polys[j]))
        gaps.append(best if best < math.inf else 60.0)
    gaps = np.array(gaps)
    levels = []
    for r in body:
        lv = r[2].get("building:levels")
        try:
            levels.append(float(lv))
        except (TypeError, ValueError):
            pass
    main_mask = np.array([kd in ("home", "work", "other") for kd in kinds]) & (areas >= 25.0)
    homes = areas[main_mask]
    hull = shapely.MultiPoint([p.centroid for p in polys]).convex_hull
    # VREAL-GRADIENT: do the big houses stand in the middle? Spearman of a main
    # building's area against its distance from the body's middle (the
    # centroid of the main buildings), and from the church where one is tagged
    def spearman(a, b):
        if len(a) < 8:
            return None
        ra = np.argsort(np.argsort(a))
        rb = np.argsort(np.argsort(b))
        return round(float(np.corrcoef(ra, rb)[0, 1]), 3)
    main_idx = [i for i in range(len(polys)) if main_mask[i]]
    grad_c = grad_church = None
    if len(main_idx) >= 8:
        cx = np.array([[polys[i].centroid.x, polys[i].centroid.y] for i in main_idx])
        mid = cx.mean(axis=0)
        grad_c = spearman(areas[main_idx], np.hypot(cx[:, 0] - mid[0], cx[:, 1] - mid[1]))
        church = [i for i, r in enumerate(body) if r[1] in ("church", "chapel", "cathedral")]
        if church:
            cc = polys[church[0]].centroid
            grad_church = spearman(areas[main_idx], np.hypot(cx[:, 0] - cc.x, cx[:, 1] - cc.y))
    out = {
        "id": s["id"], "name": s["name"], "cc": s["cc"], "population": s.get("population"),
        "culture": sv.CC_CULTURE.get(s["cc"], ""),
        "n_body": len(body),
        "area_all": q(areas),
        "area_main": q(homes),
        "main_log_mean": round(float(np.mean(np.log(homes))), 3) if homes.size else None,
        "main_log_sd": round(float(np.std(np.log(homes))), 3) if homes.size else None,
        "share_small_lt25": round(float(np.mean(areas < 25.0)), 3),
        "share_big_gt200": round(float(np.mean(areas > 200.0)), 3),
        "share_big_gt300": round(float(np.mean(areas > 300.0)), 3),
        "kind_share": {kd: round(kinds.count(kd) / len(kinds), 3) for kd in sorted(set(kinds))},
        "top_tags": tags.most_common(8),
        "aspect": q(aspect),
        "long_side_m": q([a for a, _ in dims]),
        "short_side_m": q([b for _, b in dims]),
        # the tail is the loneliest building in the body (VREAL-BODY's gate)
        "gap_m": q(gaps, (10, 25, 50, 75, 90, 95, 99)),
        "gap_max_m": round(float(gaps.max()), 2) if gaps.size else None,
        "touching_share": round(float(np.mean(gaps < 0.5)), 3),
        "levels": q(levels) if len(levels) >= 10 else {},
        "levels_tagged": len(levels),
        "hull_ha": round(hull.area / 1e4, 2),
        "gradient_rho": grad_c,
        "gradient_rho_church": grad_church,
    }
    walls = walls_of(js, loc)
    if walls:
        wl = shapely.union_all(walls)
        # how far is the wall from the nearest building, sampled every 5 m
        d = []
        for ln in (wl.geoms if hasattr(wl, "geoms") else [wl]):
            n = max(2, int(ln.length / 5.0))
            for t in np.linspace(0, ln.length, n):
                pt = ln.interpolate(t)
                if not disc.contains(pt):
                    continue
                best = min(pt.distance(polys[int(j)]) for j in tree.query(pt.buffer(200.0))) \
                    if len(tree.query(pt.buffer(200.0))) else 200.0
                d.append(best)
        if d:
            out["wall_to_building_m"] = q(d)
            out["wall_length_m"] = round(float(wl.length), 0)
    return out


def pooled(rows, key):
    vals = {}
    for r in rows:
        for k, v in r[key].items():
            vals.setdefault(k, []).append(v)
    return {k: round(float(np.median(v)), 2) for k, v in vals.items()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="artifacts/settlements")
    ap.add_argument("--repo", default=".")
    ap.add_argument("--out", default="artifacts/vreal_layout/real_layout_stats.json")
    a = ap.parse_args()
    repo = Path(a.repo)
    fx = json.loads((repo / "tests/fixtures/settlements/world_settlements.json").read_text(encoding="utf-8"))
    cache = sv.Cache(Path(a.data))
    cache.offline = True
    rows = []
    for s in fx["sites"]:
        if not s.get("morph", {}).get("usable"):
            continue
        try:
            r = site_stats(s, cache)
        except Exception as e:  # one bad site must not lose the rest
            print(f"{s['name']}: {type(e).__name__} {e}", flush=True)
            continue
        if r is not None:
            rows.append(r)
            print(f"{r['name'][:22]:22s} {r['cc']} n={r['n_body']:5d} main p50={r['area_main'].get('p50')} "
                  f"p90={r['area_main'].get('p90')} gap p50={r['gap_m']['p50']} touch={r['touching_share']}",
                  flush=True)
    by_culture = {}
    for c in sorted(set(r["culture"] for r in rows)):
        rr = [r for r in rows if r["culture"] == c]
        if len(rr) < 3:
            continue
        by_culture[c or "other"] = {
            "sites": len(rr), "area_main": pooled(rr, "area_main"), "area_all": pooled(rr, "area_all"),
            "gap_m": pooled(rr, "gap_m"), "aspect": pooled(rr, "aspect"),
            "touching_share": round(float(np.median([r["touching_share"] for r in rr])), 3),
            "main_log_sd": round(float(np.median([r["main_log_sd"] for r in rr if r["main_log_sd"]])), 3),
        }
    allr = {"sites": len(rows), "area_main": pooled(rows, "area_main"), "area_all": pooled(rows, "area_all"),
            "gap_m": pooled(rows, "gap_m"), "aspect": pooled(rows, "aspect"),
            "long_side_m": pooled(rows, "long_side_m"), "short_side_m": pooled(rows, "short_side_m"),
            "touching_share": round(float(np.median([r["touching_share"] for r in rows])), 3),
            "share_small_lt25": round(float(np.median([r["share_small_lt25"] for r in rows])), 3),
            "share_big_gt200": round(float(np.median([r["share_big_gt200"] for r in rows])), 3),
            "main_log_sd": round(float(np.median([r["main_log_sd"] for r in rows if r["main_log_sd"]])), 3)}
    walled = [r for r in rows if "wall_to_building_m" in r]
    if walled:
        allr["walled_sites"] = len(walled)
        allr["wall_to_building_m"] = pooled(walled, "wall_to_building_m")
    out = {"about": __doc__.strip().splitlines()[0], "pooled": allr, "by_culture": by_culture, "sites": rows}
    p = Path(a.out)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(json.dumps(out, indent=1, ensure_ascii=False).encode("utf-8"))
    print(json.dumps({"pooled": allr, "by_culture": by_culture}, indent=1))


if __name__ == "__main__":
    main()
