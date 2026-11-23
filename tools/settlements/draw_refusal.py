"""Draw what `tools/probe_site_refusal.gd --out summary.json` planned: the site, the
common, the roads by class, the lots, each building's walls with its name, and
(on given ground) the contours. The unplaced buildings and the first rule that
refused each are listed under the picture.

    python tools/settlements/draw_refusal.py summary.json picture.png
"""
import json
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Polygon, Rectangle  # noqa: E402

ROAD = {"through": "#5b4a3a", "street": "#8a7560", "lane": "#b39a7c", "track": "#cdbb9c", "path": "#d9cfb8",
        "steps": "#9a8f86"}
FILL = {"church": "#c9b3e6", "manor": "#e6a3a3", "monument": "#e6c58f", "shop": "#9fc3e6", "townhouse": "#d9d9d9",
        "cottage": "#e9e4d4", "farm": "#cfe3b4"}


def main() -> int:
    src, dst = sys.argv[1], sys.argv[2]
    d = json.load(open(src, encoding="utf-8"))
    x, y, w, h = d["site"]
    fig, ax = plt.subplots(figsize=(14, 14 * max(h, 60) / max(w, 60) + 1.5))
    if d.get("ground"):
        g = d["ground"]
        step = g["step"]
        xs = [x + i * step for i in range(len(g["heights"][0]))]
        ys = [y + j * step for j in range(len(g["heights"]))]
        cs = ax.contour(xs, ys, g["heights"], levels=18, colors="#b0a090", linewidths=0.5)
        ax.clabel(cs, fontsize=6, fmt="%.0f")
    ax.add_patch(Rectangle((x, y), w, h, fill=False, edgecolor="black", linewidth=1.2))
    for poly in d.get("water", []):
        ax.add_patch(Polygon(poly, closed=True, facecolor="#a8d4f0", edgecolor="none", alpha=0.7))
    for poly in d["commons"]:
        ax.add_patch(Polygon(poly, closed=True, facecolor="#9fd49f", edgecolor="#4d8a4d"))
    if d.get("landmark_site"):
        ax.add_patch(Polygon(d["landmark_site"], closed=True, fill=False, edgecolor="#7a4dbf", linestyle="--"))
    for lot in d["lots"]:
        ax.add_patch(Polygon(lot["poly"], closed=True, fill=False, edgecolor="#999999", linewidth=0.6))
    for i, road in enumerate(d["roads"]):
        pts = road["points"]
        ax.plot([p[0] for p in pts], [p[1] for p in pts], color=ROAD.get(road["class"], "red"),
                linewidth=max(1.0, road["width"] * 0.45), solid_capstyle="butt", alpha=0.85)
        mid = pts[len(pts) // 2]
        ax.text(mid[0], mid[1], "%d %s" % (i, road["class"]), fontsize=5, color="#333333")
    for b in d["buildings"]:
        ax.add_patch(Polygon(b["bounds"], closed=True, fill=False, edgecolor="#bbbbbb", linewidth=0.4))
        ax.add_patch(Polygon(b["walls"], closed=True, facecolor=FILL.get(b["class"], "#dddddd"), edgecolor="black",
                             linewidth=0.7))
        cx = sum(p[0] for p in b["walls"]) / len(b["walls"])
        cy = sum(p[1] for p in b["walls"]) / len(b["walls"])
        ax.text(cx, cy, b["label"].replace("shop/", "").replace("house/", "h:"), fontsize=5, ha="center", va="center")
        ax.plot([b["front"][0]], [b["front"][1]], marker="o", markersize=2, color="red")
    if d.get("enclosure"):
        e = d["enclosure"]
        ax.plot([p[0] for p in e] + [e[0][0]], [p[1] for p in e] + [e[0][1]], color="#444444", linewidth=1.5,
                linestyle=":")
    ax.set_aspect("equal")
    ax.set_xlim(x - 10, x + w + 10)
    ax.set_ylim(y - 10, y + h + 10)
    said = ["%s, %d of %d placed, site %.0f x %.0f m, %s re-plans" % (
        d["form"], d["placed"], d["requested"], w, h, d.get("search", {}).get("attempts", "?"))]
    said += [u["says"] for u in d.get("unplaced", [])]
    ax.set_title("\n".join(said), fontsize=8, loc="left")
    fig.savefig(dst, dpi=110, bbox_inches="tight")
    return 0


if __name__ == "__main__":
    sys.exit(main())
