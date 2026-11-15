"""Draw the plans in a tools/probe_village_layout.gd JSON, one panel each:
roads, commons, building footprints coloured by kind, the enclosure.

    python -I tools/settlements/draw_layout_probe.py artifacts/vreal_layout/base.json out.png
"""
import json
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Polygon  # noqa: E402

COL = {"house": "#c9a26b", "shop": "#7f9fbf", "church": "#9b6bb5", "castle": "#666666",
       "temple": "#b56b6b", "windmill": "#88aa66"}


def main(src, out):
    plans = json.load(open(src, encoding="utf-8"))["plans"]
    n = len(plans)
    cols = min(n, 3)
    rows = (n + cols - 1) // cols
    fig, axes = plt.subplots(rows, cols, figsize=(6 * cols, 4.2 * rows), squeeze=False)
    for ax, p in zip(axes.flat, plans):
        for r in p["roads"]:
            xs, ys = zip(*r["points"])
            ax.plot(xs, ys, color="#bbbbbb", lw=max(1.0, r["width"] * 0.8), solid_capstyle="butt", zorder=1)
        for c in p["commons"]:
            ax.add_patch(Polygon(c["poly"], closed=True, fc="#d9ead3", ec="#93c47d", zorder=0))
        for b in p["buildings"]:
            ax.add_patch(Polygon(b["poly"], closed=True, fc=COL.get(b["kind"], "#999"), ec="#333", lw=0.5, zorder=3))
        if p.get("wall"):
            xs, ys = zip(*(p["wall"]["poly"] + p["wall"]["poly"][:1]))
            ax.plot(xs, ys, color="#8b0000", lw=1.2, zorder=2)
        x, y, w, h = p["site"]
        ax.plot([x, x + w, x + w, x, x], [y, y, y + h, y + h, y], color="#dddddd", lw=0.8, ls="--")
        ax.set_aspect("equal")
        ax.invert_yaxis()
        ax.set_title(f"{p['stop']}: {p['culture']}/{p['purpose']} pop {p['population']} ({p['form']})", fontsize=9)
        ax.tick_params(labelsize=6)
    for ax in list(axes.flat)[n:]:
        ax.axis("off")
    fig.tight_layout()
    fig.savefig(out, dpi=110)
    print("wrote", out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
