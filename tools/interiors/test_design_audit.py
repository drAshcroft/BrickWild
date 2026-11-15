"""Controls for tools/interiors/design_audit.py: a passing plan and one failing mutation per rule.

A two-cell hall-and-chamber cottage laid out the way a designer (and a 1600s
household) would: the fire on the hall's end wall, the table under the window
with a bench and two chairs at it, a settle facing the fire, a dresser on the
wall; a chamber behind with a double bed, a child's bed and two chests.

    python -I tools/interiors/test_design_audit.py

Exit 0 when the good plan has no findings and every mutation trips exactly the
rule it was written for (other rules may also fire; the named one must).
"""
import copy
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import design_audit as da  # noqa: E402

N, S, W, E = 0.0, math.pi, math.pi / 2, -math.pi / 2   # yaw that FACES north / south / west / east


def piece(i, key, cat, room, rect, yaw, host=-1, mounted=False):
    return {"i": i, "key": key, "cat": cat, "room": room, "storey": 0, "rect": rect,
            "pos": [rect[0] + rect[2] / 2, 0.0, rect[1] + rect[3] / 2], "yaw": yaw,
            "host": host, "mounted": mounted, "group": "", "zone": [0, 0, 0, 0]}


def good_plan():
    rooms = [
        {"i": 0, "kind": "hall", "storey": 0, "rect": [0, 0, 6, 5.5], "outline": [], "area": 33.0},
        {"i": 1, "kind": "bedroom", "storey": 0, "rect": [0, 5.5, 6, 3.0], "outline": [], "area": 18.0},
    ]
    doors = [
        {"i": 0, "a": 0, "b": -1, "pos": [4.5, 0.0], "normal": [0, -1], "width": 0.9,
         "exterior": True, "front": True, "storey": 0},
        {"i": 1, "a": 0, "b": 1, "pos": [4.5, 5.5], "normal": [0, 1], "width": 0.8,
         "exterior": False, "front": False, "storey": 0},
    ]
    windows = [{"i": 0, "room": 0, "pos": [1.5, 0.0], "normal": [0, -1], "width": 0.8, "storey": 0},
               {"i": 1, "room": 1, "pos": [3.0, 8.5], "normal": [0, 1], "width": 0.6, "storey": 0}]
    f = [
        piece(0, "Table_Small", "table", 0, [2.6, 1.2, 1.8, 0.8], 0.0),
        piece(1, "Chair_1", "seat", 0, [2.7, 0.55, 0.5, 0.5], S, host=0),
        piece(2, "Chair_1", "seat", 0, [3.4, 0.55, 0.5, 0.5], S, host=0),
        piece(3, "Bench", "bench", 0, [2.6, 2.15, 1.8, 0.4], N, host=0),
        piece(4, "Settle", "bench", 0, [1.5, 2.2, 0.5, 1.6], W),
        piece(5, "Dresser", "storage", 0, [5.55, 2.0, 0.45, 1.4], W),
        piece(6, "Candle_1", "candle", 0, [3.4, 1.5, 0.1, 0.1], 0.0, host=0),
        piece(7, "Bed_Double", "bed", 1, [0.0, 6.2, 2.0, 1.4], E),
        piece(8, "Bed_Child", "bed", 1, [2.4, 6.6, 0.9, 1.9], N),
        piece(9, "Chest_Wood", "chest", 1, [0.2, 8.0, 1.0, 0.5], N),
        piece(10, "Chest_Wood", "chest", 1, [5.5, 6.6, 0.5, 1.0], W),
    ]
    return {"case": "control:good", "style": "cottage", "purpose": "none", "entrance_door": 0,
            "entrance_room": 0, "rooms": rooms, "doors": doors, "windows": windows, "stairs": [],
            "furniture": f, "hearth": {"room": 0, "wall": 3}, "focus": {}, "compromises": []}


def mutate(name):
    p = good_plan()
    p["case"] = "control:" + name
    f = p["furniture"]
    if name == "R-01":          # the dresser walks into the room
        f[5]["rect"] = [4.6, 2.0, 0.45, 1.4]
    elif name == "R-02":        # a chair beside the table, turned to the wall
        f[1]["yaw"] = N
    elif name == "R-03":        # one chair stranded in the chamber
        f.append(piece(11, "Chair_1", "seat", 1, [5.4, 8.0, 0.5, 0.5], S))
    elif name == "R-04":        # a parlour of benches round nothing
        p["rooms"].append({"i": 2, "kind": "parlour", "storey": 0, "rect": [6, 0, 4, 4],
                           "outline": [], "area": 16.0})
        f.append(piece(11, "Bench", "bench", 2, [6.2, 0.1, 1.8, 0.4], S))
        f.append(piece(12, "Bench", "bench", 2, [6.2, 1.0, 1.8, 0.4], N))
    elif name == "R-05":        # the chamber is emptied
        p["furniture"] = [x for x in f if x["room"] != 1] + [piece(11, "Bed_Child", "bed", 1, [2.4, 6.6, 0.9, 1.9], N)]
        p["rooms"][1]["rect"] = [0, 5.5, 12, 6]
        p["rooms"][1]["area"] = 72.0
    elif name == "R-06":        # the hall is filled with crates
        for k in range(21):
            f.append(piece(20 + k, "Crate_Wooden", "crate", 0,
                           [0.1 + (k % 7) * 0.8, 3.0 + (k // 7) * 0.8, 0.75, 0.75], N))
    elif name == "R-07":        # a chest in the swing of the chamber door
        f.append(piece(11, "Chest_Wood", "chest", 1, [4.1, 5.6, 0.8, 0.5], S))
    elif name == "R-08":        # the bed beside the chamber door
        f[8]["rect"] = [4.1, 5.7, 0.9, 1.9]
    elif name == "R-09":        # a bed in the entrance hall
        f.append(piece(11, "Bed_Child", "bed", 0, [0.0, 3.5, 1.9, 0.9], E))
    elif name == "R-10":        # the bench is taken away: 2 places for 3 sleepers
        p["furniture"] = [x for x in f if x["i"] != 3]
    elif name == "R-11":        # a feast trestle for two
        f[0]["rect"] = [1.6, 1.2, 4.2, 0.9]
        p["furniture"] = [x for x in f if x["i"] != 3]
    elif name == "R-12":        # no beds at all
        p["furniture"] = [x for x in f if x["cat"] != "bed"]
    elif name == "R-13":        # a second dining table in the hall
        f.append(piece(11, "Table_Small", "table", 0, [0.6, 4.2, 1.8, 0.8], 0.0))
    elif name == "R-14":        # the fire is moved to a kitchen nobody sits in
        p["rooms"].append({"i": 2, "kind": "kitchen", "storey": 0, "rect": [6, 0, 4, 5.5],
                           "outline": [], "area": 22.0})
        p["hearth"] = {"room": 2, "wall": 1}
    elif name == "R-15":        # two halls on one floor
        p["rooms"].append({"i": 2, "kind": "hall", "storey": 0, "rect": [6, 0, 4, 5.5],
                           "outline": [], "area": 22.0})
    elif name == "R-16":        # a big store upstairs beside a parlour
        p["rooms"].append({"i": 2, "kind": "parlour", "storey": 1, "rect": [0, 0, 6, 4], "outline": [], "area": 24.0})
        p["rooms"].append({"i": 3, "kind": "store", "storey": 1, "rect": [0, 4, 6, 4], "outline": [], "area": 24.0})
    elif name == "R-17":        # a second chamber reached only through the first
        p["rooms"].append({"i": 2, "kind": "bedroom", "storey": 0, "rect": [6, 5.5, 3, 3], "outline": [], "area": 9.0})
        p["doors"].append({"i": 2, "a": 1, "b": 2, "pos": [6.0, 7.0], "normal": [1, 0], "width": 0.8,
                           "exterior": False, "front": False, "storey": 0})
    elif name == "R-18":        # a wall torch in the hall
        f.append(piece(11, "Torch_Metal", "sconce", 0, [0.0, 1.0, 0.2, 0.4], E, mounted=True))
    elif name == "R-19":        # a stool beside the chairs
        f[2]["key"] = "Stool"
    return p


RULES = ["R-%02d" % k for k in range(1, 20)]


def main():
    failures = []
    good = da.audit(good_plan())
    if good:
        failures.append("good plan has findings: %s" % [(g["rule"], g["where"], g["msg"]) for g in good])
    for rule in RULES:
        found = {f["rule"].split(" ")[0] for f in da.audit(mutate(rule))}
        if rule not in found:
            failures.append("%s mutation did not trip %s (found %s)" % (rule, rule, sorted(found)))
    for f in failures:
        print("FAIL", f)
    print("%d controls, %d failures" % (1 + len(RULES), len(failures)))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
