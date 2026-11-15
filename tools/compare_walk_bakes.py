"""Two bakes of a walk series side by side: what a re-bake changed.

    python -I tools/compare_walk_bakes.py artifacts/walk_villages/mixed_f9e5361_old artifacts/walk_villages/mixed

Reads only the bakes' JSON rows (request, transform), so it runs in a second.
Per stop: buildings, how many houses were townhouses, the house footprint
quantiles (request width x length), the spread of the building centres and
the median centre-to-centre distance to the nearest neighbour. Crude beside
tools/probe_village_layout.gd (no eaves, no lots), but it needs no Godot.
"""
import json
import math
import sys
from pathlib import Path


def quantile(xs, q):
    if not xs:
        return float("nan")
    xs = sorted(xs)
    i = (len(xs) - 1) * q
    lo, hi = math.floor(i), math.ceil(i)
    return xs[lo] + (xs[hi] - xs[lo]) * (i - lo)


def summary(path):
    d = json.loads(Path(path).read_text(encoding="utf-8"))
    rows = d["rows"]
    pts = [(r["transform"][9], r["transform"][11]) for r in rows]
    houses = [r["request"] for r in rows if r["request"]["kind"] == "house" and not r.get("extra")]
    areas = [float(h["width"]) * float(h["length"]) for h in houses]
    nn = []
    for i, p in enumerate(pts):
        best = min((math.dist(p, q) for j, q in enumerate(pts) if j != i), default=float("nan"))
        nn.append(best)
    xs, zs = [p[0] for p in pts], [p[1] for p in pts]
    styles = {}
    for h in houses:
        styles[h["style"]] = styles.get(h["style"], 0) + 1
    return {
        "commit": d.get("commit", "?"),
        "n": len(rows),
        "houses": len(houses),
        "styles": styles,
        "area": (quantile(areas, 0.1), quantile(areas, 0.5), quantile(areas, 0.9)),
        "spread": (max(xs) - min(xs), max(zs) - min(zs)) if pts else (0, 0),
        "nn": quantile(nn, 0.5),
    }


def main(old_dir, new_dir):
    print("stop | commit old -> new | buildings | houses | house m2 p10/p50/p90 | spread m | nn p50 m | house styles")
    for new in sorted(Path(new_dir).glob("*.json")):
        old = Path(old_dir) / new.name
        if not old.exists():
            continue
        a, b = summary(old), summary(new)
        fmt = lambda t: "/".join("%.0f" % x for x in t)
        print("%s | %s -> %s | %d -> %d | %d -> %d | %s -> %s | %s -> %s | %.1f -> %.1f | %s -> %s" % (
            new.stem, a["commit"], b["commit"], a["n"], b["n"], a["houses"], b["houses"],
            fmt(a["area"]), fmt(b["area"]), "x".join("%.0f" % s for s in a["spread"]),
            "x".join("%.0f" % s for s in b["spread"]), a["nn"], b["nn"], a["styles"], b["styles"]))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
