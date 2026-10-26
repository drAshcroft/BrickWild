"""Draw an exported SitePlan on the ground it was planned on.

    python -I -X utf8 tools/settlements/draw_plan.py --plan out.json \
        [--terrain grid.json] --out plan.png [--title "..."]

The picture is in the GROUND's frame (x east, z south drawn downward, so north
is up), with the terrain's contours, wet ground in blue, and the plan placed
by its `site.anchor_m` / `site.yaw_deg` when it has them: a plan point p stands
at anchor + p rotated by yaw (Vector2.rotated, x toward z). Roads by class
(steps dashed red), lots thin, buildings filled, commons green. The same
picture a person draws to see whether a village sits on its hill; put it
beside the world set's contact sheets (docs/images/settlements).
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np

ROAD_STYLE = {
    "through": ("#3a3a3a", 2.4, "-"), "street": ("#555555", 1.6, "-"), "lane": ("#6b6b6b", 1.2, "-"),
    "track": ("#8a7a5a", 1.0, "-"), "path": ("#9a9a9a", 0.8, "-"), "steps": ("#b03030", 1.2, "--"),
}


def load_grid(path: Path):
    d = json.loads(path.read_text(encoding="utf-8"))
    cols, rows, cell = int(d["cols"]), int(d["rows"]), float(d["cell_m"])
    if "heights_m" in d:
        h = np.array(d["heights_m"], dtype=float)
    else:
        h = np.fromfile(path.parent / d["file"], dtype="<f4").astype(float)
    h = h.reshape(rows, cols)
    ox, oz = d["origin_m"]
    xs = ox + np.arange(cols) * cell
    zs = oz + np.arange(rows) * cell
    return xs, zs, h, d.get("water_level_m")


def placer(site: dict):
    if "anchor_m" not in site:
        return lambda p: (p[0], p[1])
    ax, az = site["anchor_m"]
    yaw = math.radians(float(site.get("yaw_deg", 0.0)))
    c, s = math.cos(yaw), math.sin(yaw)
    return lambda p: (ax + p[0] * c - p[1] * s, az + p[0] * s + p[1] * c)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--plan", type=Path, required=True)
    ap.add_argument("--terrain", type=Path)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--title", default="")
    a = ap.parse_args()
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.patches import Polygon as MPoly

    plan = json.loads(a.plan.read_text(encoding="utf-8"))
    put = placer(plan.get("site", {}))
    fig, ax = plt.subplots(figsize=(10, 10), dpi=100)
    pts_all = []

    def poly(points):
        q = [put(p) for p in points]
        pts_all.extend(q)
        return np.array(q)

    if a.terrain:
        xs, zs, h, wl = load_grid(a.terrain)
        span = float(h.max() - h.min())
        step = 2.0 if span < 60 else 5.0 if span < 200 else 10.0
        levels = np.arange(math.floor(h.min() / step) * step, h.max() + step, step)
        cs = ax.contour(xs, zs, h, levels=levels, colors="#b8a98a", linewidths=0.5)
        ax.clabel(cs, cs.levels[::4], fontsize=6, fmt="%.0f")
        if wl is not None:
            ax.contourf(xs, zs, h, levels=[h.min() - 1, float(wl)], colors=["#9cc3e6"])
    for c in plan.get("commons", []):
        ax.add_patch(MPoly(poly(c["poly_m"]), closed=True, fc="#cfe3b4", ec="#8fb36a", lw=0.6))
    for w in plan.get("water", []):
        # the plan's own water outlined, so it reads apart from the grid's
        # wet ground drawn under it
        ax.add_patch(MPoly(poly(w["poly_m"]), closed=True, fc="#9cc3e6", ec="#3f78b0", lw=0.6))
    for lot in plan.get("lots", []):
        ax.add_patch(MPoly(poly(lot["poly_m"]), closed=True, fc="none", ec="#c9c9c9", lw=0.4))
        platform = lot.get("platform") or {}
        # VTER-LOTS: terrace walls (cut: holding the bank above the lot,
        # fill: under its edge) and what the building puts on the ground
        # outside its walls (entry flights, a terrace, a talus)
        for wall in platform.get("terrace_walls", []):
            q = poly(wall["points_m"])
            col = "#8a5a2b" if wall.get("holds") == "cut" else "#c08a3e"
            ax.plot(q[:, 0], q[:, 1], color=col, lw=0.6 + min(2.5, float(wall["height_m"])), solid_capstyle="butt")
        for part in platform.get("ground_parts_m", []):
            ax.add_patch(MPoly(poly(part), closed=True, fc="#e0a040", ec="none", alpha=0.8))
    for r in plan.get("roads", []):
        col, lw, ls = ROAD_STYLE.get(r.get("class", ""), ("#777777", 1.0, "-"))
        q = poly(r["points_m"])
        ax.plot(q[:, 0], q[:, 1], color=col, lw=lw, ls=ls, solid_capstyle="round")
    for b in plan.get("buildings", []):
        kind = b.get("kind", "")
        fc = "#7a2e2e" if kind in ("church", "temple") else "#2b2b2b" if kind == "house" else "#4a4a6a"
        ax.add_patch(MPoly(poly(b["poly_m"]), closed=True, fc=fc, ec="none"))
    if pts_all:
        q = np.array(pts_all)
        pad = 40.0
        ax.set_xlim(q[:, 0].min() - pad, q[:, 0].max() + pad)
        ax.set_ylim(q[:, 1].max() + pad, q[:, 1].min() - pad)   # z south drawn down: north up
    ax.set_aspect("equal")
    form = plan.get("form", "")
    intent = plan.get("form_intent", form)
    ax.set_title(a.title or f"{plan.get('name', '')}: {form}" + (f" (intent {intent})" if intent != form else ""),
                 fontsize=10)
    fig.tight_layout()
    a.out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(a.out)
    print(f"draw_plan: {a.out}")


if __name__ == "__main__":
    main()
