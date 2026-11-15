"""Draw furnished house plans from above, one sheet per house, one panel per storey.

Reads the JSON written by tools/dump_interiors_json.gd:
    python -I tools/interiors/draw_interiors.py artifacts/interior_research/plans.json artifacts/interior_research/sheets

Rooms are outlined and named; doors are red ticks (exterior thick); windows blue;
furniture is a box coloured by category with a short arrow for the way it FACES
(facing = (-sin yaw, -cos yaw), the convention qa/house_furnish_arrangement_check.gd uses).
Mounted pieces (shelves, sconces) are drawn hollow; pieces 'on' a host are dots.
"""
import json
import math
import os
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, Rectangle

CAT_COLOURS = {
    "bed": "#c0504d", "nightstand": "#e6a19f", "chest": "#9b7b4f", "storage": "#8064a2",
    "table": "#4f81bd", "seat": "#9bbb59", "bench": "#76923c", "hearth": "#f79646",
    "bookcase": "#604a7b", "shelf": "#b3a2c7", "workbench": "#7f6000", "counter": "#31859c",
    "barrel": "#a5682a", "crate": "#c49a6c", "cookware": "#e46c0a", "rack": "#7f7f7f",
}
SMALL = {"tableware", "candle", "books", "tool", "trinket", "cookware_small"}


def facing(yaw):
    return -math.sin(yaw), -math.cos(yaw)


def draw_storey(ax, plan, storey):
    rooms = [r for r in plan["rooms"] if r["storey"] == storey]
    xs, ys = [], []
    for r in rooms:
        pts = r["outline"] or [[r["rect"][0], r["rect"][1]],
                               [r["rect"][0] + r["rect"][2], r["rect"][1]],
                               [r["rect"][0] + r["rect"][2], r["rect"][1] + r["rect"][3]],
                               [r["rect"][0], r["rect"][1] + r["rect"][3]]]
        ax.add_patch(Polygon(pts, closed=True, fill=True, fc="#f7f3ea", ec="black", lw=1.6))
        cx = sum(p[0] for p in pts) / len(pts)
        cy = sum(p[1] for p in pts) / len(pts)
        ax.text(cx, cy, "%s #%d\n%.1f m2" % (r["kind"], r["i"], r["area"]), ha="center",
                va="center", fontsize=7, color="#555555", alpha=0.8, zorder=1)
        xs += [p[0] for p in pts]
        ys += [p[1] for p in pts]
    for s in plan["stairs"]:
        for key, colour in (("lower", "#999999"), ("upper", "#cccccc")):
            rr = s[key]
            if (s["storey"] == storey and key == "lower") or (s["to"] == storey and key == "upper"):
                if rr[2] > 0:
                    ax.add_patch(Rectangle((rr[0], rr[1]), rr[2], rr[3], fc=colour, ec="k",
                                           hatch="---", alpha=0.6, zorder=2))
    for d in plan["doors"]:
        if d["storey"] != storey or len(d["pos"]) < 2:
            continue
        px, py = d["pos"][0], d["pos"][-1] if len(d["pos"]) == 2 else d["pos"][2]
        nx, ny = d["normal"][0], d["normal"][-1] if len(d["normal"]) == 2 else d["normal"][2]
        tx, ty = -ny, nx
        w = d["width"] / 2
        ax.plot([px - tx * w, px + tx * w], [py - ty * w, py + ty * w], color="red",
                lw=4 if d["exterior"] else 2.5, solid_capstyle="butt", zorder=5)
        if d["exterior"] and d.get("front"):
            ax.annotate("ENTRY", (px, py), fontsize=7, color="red", zorder=6)
    for w in plan["windows"]:
        if w["storey"] != storey or len(w["pos"]) < 2:
            continue
        px, py = w["pos"][0], w["pos"][-1] if len(w["pos"]) == 2 else w["pos"][2]
        nx, ny = w["normal"][0], w["normal"][-1] if len(w["normal"]) == 2 else w["normal"][2]
        tx, ty = -ny, nx
        hw = w["width"] / 2
        ax.plot([px - tx * hw, px + tx * hw], [py - ty * hw, py + ty * hw], color="#3399ff",
                lw=3, solid_capstyle="butt", zorder=5)
    for f in plan["furniture"]:
        if f["storey"] != storey:
            continue
        x, y, w, h = f["rect"]
        cat = f["cat"]
        c = CAT_COLOURS.get(cat, "#bbbbbb")
        cx, cy = x + w / 2, y + h / 2
        if cat in SMALL or (f["host"] >= 0 and cat not in CAT_COLOURS and not f["mounted"]):
            ax.plot([cx], [cy], ".", color=c, ms=3, zorder=7)
            continue
        ax.add_patch(Rectangle((x, y), w, h, fc="none" if f["mounted"] else c, ec=c if f["mounted"] else "k",
                               lw=0.8, alpha=0.85, zorder=4))
        if not f["mounted"]:
            fx, fy = facing(f["yaw"])
            L = 0.35
            ax.arrow(cx, cy, fx * L, fy * L, head_width=0.12, color="k", lw=0.6, zorder=8)
            label = f["key"].split("_")[0][:9]
            ax.text(cx, cy, label, fontsize=5, ha="center", va="top", zorder=9)
    if xs:
        ax.set_xlim(min(xs) - 0.5, max(xs) + 0.5)
        ax.set_ylim(max(ys) + 0.5, min(ys) - 0.5)
    ax.set_aspect("equal")
    ax.set_title("storey %d" % storey, fontsize=9)
    ax.tick_params(labelsize=6)


def main():
    src, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    with open(src, encoding="utf-8") as fh:
        data = json.load(fh)
    for plan in data["plans"]:
        storeys = sorted({r["storey"] for r in plan["rooms"]})
        fig, axes = plt.subplots(1, len(storeys), figsize=(7 * len(storeys), 7), squeeze=False)
        for ax, s in zip(axes[0], storeys):
            draw_storey(ax, plan, s)
        fig.suptitle("%s  (style %s)" % (plan["case"], plan["style"]), fontsize=11)
        fig.tight_layout()
        name = plan["case"].replace(":", "_")
        fig.savefig(os.path.join(out_dir, name + ".png"), dpi=110)
        plt.close(fig)
        print("wrote", name)


if __name__ == "__main__":
    main()
