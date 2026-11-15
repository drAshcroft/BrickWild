"""BrickWild interiors beside the real-data medians in docs/interior/DATASETS.md.

    python -I tools/interiors/compare_to_data.py artifacts/interior_research/plans_sample.json

Prints the BrickWild value of each measure the datasets give (HSSD-hab, SUN RGB-D,
Swiss Dwellings), so a reader sees which numbers are far from how people furnish.
The reference values are copied from docs/interior/DATASETS.md (2026-11-14 run).
"""
import json
import os
import statistics
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import design_audit as da  # noqa: E402

REFERENCE = {
    "bed head at a wall": "0.90 HSSD (n=435); 0.66 SUN scans, a lower bound (n=1019)",
    "storage back at a wall": "0.91-0.99 HSSD (cabinet .92, chest of drawers .93, wardrobe .99)",
    "places per dining table": "median 4 HSSD (n=93) and SUN (n=171); 6 next",
    "beds with 2 / 1 / 0 bedside pieces": "0.40 / 0.23 / 0.37 HSSD (n=435)",
    "bedroom area m2": "16.3 HSSD (n=382); 14.0 Swiss (n=23k)",
    "kitchen area m2": "17.4 HSSD (n=172); 8.0 Swiss",
    "living-room area m2": "32.4 HSSD (n=133); 28.4 Swiss living-dining",
    "bedroom pieces per m2": "0.33 HSSD",
    "living-room pieces per m2": "0.22 HSSD",
    "kitchen pieces per m2": "0.52 HSSD",
}


def main():
    data = json.load(open(sys.argv[1], encoding="utf-8"))
    beds_at_wall = []
    storage_at_wall = []
    places = []
    bedside = defaultdict(int)
    area = defaultdict(list)
    density = defaultdict(list)
    for plan in data["plans"]:
        rooms = {r["i"]: r for r in plan["rooms"]}
        furn = plan["furniture"]
        for f in furn:
            if f["mounted"] or f["room"] not in rooms:
                continue
            g = da.dist_to_walls(da.back_point(f), rooms[f["room"]])
            if f["cat"] == "bed":
                beds_at_wall.append(g <= 0.15)
                n = sum(1 for o in furn if o["cat"] == "nightstand" and o["room"] == f["room"]
                        and da.rect_gap(o["rect"], f["rect"]) < 0.3)
                bedside[min(n, 2)] += 1
            if f["cat"] in {"storage", "chest", "bookcase"}:
                storage_at_wall.append(g <= 0.15)
        for t in [f for f in furn if f["cat"] == "table" and not f["mounted"]]:
            if rooms.get(t["room"], {}).get("kind") not in da.LIVING_KINDS | {"kitchen"}:
                continue
            p = 0
            for s in furn:
                if s["cat"] in da.SEATS and not s["mounted"] and s["room"] == t["room"] and da.seat_faces(s, t):
                    p += max(1, int(max(s["rect"][2], s["rect"][3]) / da.COVER_M)) if s["cat"] == "bench" else 1
            places.append(p)
        for i, r in rooms.items():
            k = r["kind"]
            group = ("bedroom" if k in da.PRIVATE_KINDS else "kitchen" if k == "kitchen"
                     else "living-room" if k in da.LIVING_KINDS else None)
            if group:
                area[group].append(r["area"])
                density[group].append(len(da.floor_pieces(plan, i)) / max(r["area"], 0.1))

    def frac(xs):
        return "%.2f (n=%d)" % (sum(xs) / len(xs), len(xs)) if xs else "n=0"

    def med(xs):
        return "%.1f (n=%d)" % (statistics.median(xs), len(xs)) if xs else "n=0"

    nb = sum(bedside.values()) or 1
    rows = [
        ("bed head at a wall", frac(beds_at_wall)),
        ("storage back at a wall", frac(storage_at_wall)),
        ("places per dining table", med(places)),
        ("beds with 2 / 1 / 0 bedside pieces", "%.2f / %.2f / %.2f (n=%d)" % (
            bedside[2] / nb, bedside[1] / nb, bedside[0] / nb, nb)),
        ("bedroom area m2", med(area["bedroom"])),
        ("kitchen area m2", med(area["kitchen"])),
        ("living-room area m2", med(area["living-room"])),
        ("bedroom pieces per m2", "%.2f (n=%d)" % (statistics.median(density["bedroom"]), len(density["bedroom"]))),
        ("living-room pieces per m2", "%.2f (n=%d)" % (statistics.median(density["living-room"]), len(density["living-room"]))),
        ("kitchen pieces per m2", "%.2f (n=%d)" % (statistics.median(density["kitchen"]), len(density["kitchen"]))),
    ]
    print("| Measure | BrickWild (%d houses) | Real data |" % len(data["plans"]))
    print("|---|---|---|")
    for name, value in rows:
        print("| %s | %s | %s |" % (name, value, REFERENCE[name]))


if __name__ == "__main__":
    main()
