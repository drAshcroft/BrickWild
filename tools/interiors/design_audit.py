"""Audit furnished house plans against interior-design rules a person would apply.

The existing house QA asks "is it physically valid and walkable?". This asks
"would a household arrange it like this?". Every rule names its source in
docs/INTERIOR_DESIGN.md (the rule ids R-xx). Input is the JSON written by
tools/dump_interiors_json.gd:

    python -I tools/interiors/design_audit.py artifacts/interior_research/plans_sample.json [--json out.json]

Output: one line per finding, then a per-rule tally across all plans. A rule
counts a finding once per offending piece or room, so the tally is "how many
times would a designer circle something on the sheet".
"""
import json
import math
import sys
from collections import Counter, defaultdict

# ---- vocabulary -----------------------------------------------------------
SEATS = {"seat", "bench"}
WALL_CATS = {"bed", "storage", "chest", "bookcase", "nightstand", "workbench", "counter",
             "shelf_floor", "dresser"}
LIVING_KINDS = {"hall", "parlour", "dining", "dining_room", "great_hall", "living"}
PRIVATE_KINDS = {"bedroom", "lords_chamber", "chamber", "guest_room", "dormitory"}
SERVICE_KINDS = {"store", "kitchen", "stable", "tack_room", "pantry", "buttery"}
PRE_MODERN_STYLES = {"cottage", "farmhouse", "townhouse", "longhall", "thatch_cottage",
                     "roundhouse", "pueblo", "african", "asian", "mediterranean", "rich"}
# Bed width in metres -> sleepers. The catalogue's "Twin" is 1.88 m wide: a double.
SLEEPERS_PER_M_WIDTH = 1.0 / 0.9
# Seat run per diner along a table edge (Neufert / Panero: 0.60 m per cover).
COVER_M = 0.60

# ---- thresholds (see docs/INTERIOR_DESIGN.md for each source) ------------
WALL_GAP_MAX = 0.20          # R-01 a wall piece's back within 0.20 m of a wall
SEAT_TABLE_REACH = 0.55      # R-02 a chair's front within 0.55 m of its table edge
EMPTY_RATIO = 0.06           # R-05 floor-standing furniture covers < 6 % of a living room
EMPTY_MIN_AREA = 10.0        #      ... and the room is bigger than this
CROWD_RATIO = 0.45           # R-06 > 45 % covered is crowded
DOOR_SWING_DEPTH = 0.90      # R-07 a door's swing / approach zone 0.9 m deep
BED_DOOR_LINE = 1.0          # R-08 a bed's foot or side within 1.0 m in front of a door
LONE_SEAT_REACH = 2.5        # R-03 a seat with no table, no fire and no other seat within 2.5 m
PERIOD_SEATS_OFF_WALL = 1720 # R-03/04 before this, idle seats rest against the walls (guides H4)
M2_PER_SLEEPER_MAX = 40.0    # R-20 ESTIMATE: pre-modern households ran ~10-20 m2 a head; modern EU ~40


def facing(yaw):
    return (-math.sin(yaw), -math.cos(yaw))


def rect_center(r):
    return (r[0] + r[2] / 2.0, r[1] + r[3] / 2.0)


def rect_gap(a, b):
    dx = max(b[0] - (a[0] + a[2]), a[0] - (b[0] + b[2]), 0.0)
    dy = max(b[1] - (a[1] + a[3]), a[1] - (b[1] + b[3]), 0.0)
    return math.hypot(dx, dy)


def rect_overlap(a, b):
    ox = min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0])
    oy = min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1])
    return max(ox, 0.0) * max(oy, 0.0)


def seg_point_dist(p, a, b):
    ax, ay = a
    bx, by = b
    px, py = p
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L2))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def room_edges(room):
    pts = room["outline"]
    if not pts:
        x, y, w, h = room["rect"]
        pts = [[x, y], [x + w, y], [x + w, y + h], [x, y + h]]
    return [(tuple(pts[i]), tuple(pts[(i + 1) % len(pts)])) for i in range(len(pts))]


def dist_to_walls(p, room):
    return min(seg_point_dist(p, a, b) for a, b in room_edges(room))


def back_point(f):
    """Mid-point of the piece's back edge (the side opposite its facing)."""
    cx, cy = rect_center(f["rect"])
    fx, fy = facing(f["yaw"])
    w, h = f["rect"][2], f["rect"][3]
    half = abs(fx) * w / 2.0 + abs(fy) * h / 2.0
    return (cx - fx * half, cy - fy * half)


def front_point(f, beyond=0.0):
    cx, cy = rect_center(f["rect"])
    fx, fy = facing(f["yaw"])
    w, h = f["rect"][2], f["rect"][3]
    half = abs(fx) * w / 2.0 + abs(fy) * h / 2.0 + beyond
    return (cx + fx * half, cy + fy * half)


def door_zone(door):
    """Rectangle the swing / approach of a door sweeps, on both sides (0.9 m deep)."""
    p = door["pos"]
    n = door["normal"]
    px, py = p[0], p[-1]
    nx, ny = n[0], n[-1]
    tx, ty = -ny, nx
    hw = door["width"] / 2.0
    xs = [px + tx * hw, px - tx * hw, px + nx * DOOR_SWING_DEPTH, px - nx * DOOR_SWING_DEPTH]
    ys = [py + ty * hw, py - ty * hw, py + ny * DOOR_SWING_DEPTH, py - ny * DOOR_SWING_DEPTH]
    x0, x1 = min(px + tx * hw, px - tx * hw), max(px + tx * hw, px - tx * hw)
    y0, y1 = min(py + ty * hw, py - ty * hw), max(py + ty * hw, py - ty * hw)
    x0, x1 = min(x0, min(xs)), max(x1, max(xs))
    y0, y1 = min(y0, min(ys)), max(y1, max(ys))
    if abs(nx) > 0.5:   # door in a wall running along y
        return [px - DOOR_SWING_DEPTH, py - hw, 2 * DOOR_SWING_DEPTH, 2 * hw]
    return [px - hw, py - DOOR_SWING_DEPTH, 2 * hw, 2 * DOOR_SWING_DEPTH]


def seat_faces(seat, table):
    """A place at table: the seat's front edge is within reach of the table and it faces it."""
    fp = front_point(seat)
    return rect_gap([fp[0] - 0.01, fp[1] - 0.01, 0.02, 0.02], table["rect"]) <= SEAT_TABLE_REACH


def floor_pieces(plan, room_i):
    return [f for f in plan["furniture"] if f["room"] == room_i and not f["mounted"]
            and f["cat"] not in {"tableware", "candle", "books", "tool", "trinket", "cookware",
                                 "rug", "workbench_insert"} and f["rect"][2] * f["rect"][3] > 0.04]


def audit(plan):
    out = []
    rooms = {r["i"]: r for r in plan["rooms"]}
    style = plan.get("style", "")

    def add(rule, where, msg):
        out.append({"case": plan["case"], "rule": rule, "where": where, "msg": msg})

    tables = [f for f in plan["furniture"] if f["cat"] == "table" and not f["mounted"]]
    hearth_room = plan.get("hearth", {}).get("room", -1)

    # R-01 wall pieces have their backs to a wall (beds: the head)
    for f in plan["furniture"]:
        if f["mounted"] or f["cat"] not in WALL_CATS or f["room"] not in rooms:
            continue
        g = dist_to_walls(back_point(f), rooms[f["room"]])
        if g > WALL_GAP_MAX:
            add("R-01 floating", "%s f%d %s" % (rooms[f["room"]]["kind"], f["i"], f["key"]),
                "back stands %.2f m off any wall" % g)

    # R-02 / R-03 every seat belongs to a group: a table in front, a fire, or another seat
    for f in plan["furniture"]:
        if f["mounted"] or f["cat"] not in SEATS or f["room"] not in rooms:
            continue
        fp = front_point(f)
        same_room_tables = [t for t in tables if t["room"] == f["room"]]
        near_table = min((rect_gap([fp[0] - 0.01, fp[1] - 0.01, 0.02, 0.02], t["rect"])
                          for t in same_room_tables), default=99)
        any_table = min((rect_gap(f["rect"], t["rect"]) for t in same_room_tables), default=99)
        if near_table <= SEAT_TABLE_REACH:
            continue
        if any_table <= 0.6:
            add("R-02 seat turned away", "%s f%d %s" % (rooms[f["room"]]["kind"], f["i"], f["key"]),
                "beside a table but not facing it")
            continue
        room = rooms[f["room"]]
        where = "%s f%d %s" % (room["kind"], f["i"], f["key"])
        # A seat whose front is within 0.35 m of a wall, with its back NOT to a wall,
        # faces the plaster: wrong in every century (human pin: "chair facing wall").
        back_to_wall = dist_to_walls(back_point(f), room) <= WALL_GAP_MAX
        if not back_to_wall and dist_to_walls(front_point(f), room) < 0.35:
            add("R-03 seat faces a wall", where, "its front is against the plaster")
            continue
        others = [g for g in plan["furniture"] if g is not f and g["room"] == f["room"]
                  and g["cat"] in SEATS and not g["mounted"]
                  and rect_gap(f["rect"], g["rect"]) < LONE_SEAT_REACH]
        fire_here = (f["room"] == hearth_room)
        # Seats in a room with neither a table nor a fire serve nothing, against the wall
        # or not (human pin: "why is there a chair here?").
        # period_seating = without_table (HouseSpec): strict pre-1720 history, the
        # table is put away and wall seats need none. Mid-floor seats still do.
        strict_history = (plan.get("period_seating") == "without_table"
                          and plan.get("period", 1200) < PERIOD_SEATS_OFF_WALL)
        if not fire_here and not same_room_tables and not (strict_history and back_to_wall):
            add("R-04 seats with no purpose", where, "a room of seats with no table and no fire")
            continue
        # Before c.1720 idle seats stood back-to-wall round a room whose table was set
        # aside and brought out for meals (GUIDES H4: Rybczynski; John 2008 figs 10-11).
        if back_to_wall and plan.get("period", 1200) < PERIOD_SEATS_OFF_WALL:
            continue
        if not others and not fire_here:
            add("R-03 seat adrift", where, "mid-floor: not at the table, no fire, no other seat")

    # R-05 / R-06 occupancy of living rooms
    for i, r in rooms.items():
        pieces = floor_pieces(plan, i)
        cover = sum(f["rect"][2] * f["rect"][3] for f in pieces)
        ratio = cover / max(r["area"], 0.1)
        if r["kind"] in LIVING_KINDS | PRIVATE_KINDS and r["area"] > EMPTY_MIN_AREA and ratio < EMPTY_RATIO:
            add("R-05 empty room", "%s #%d" % (r["kind"], i),
                "%.0f m2 holding %.0f %% furniture" % (r["area"], ratio * 100))
        if ratio > CROWD_RATIO:
            add("R-06 crowded room", "%s #%d" % (r["kind"], i), "%.0f %% of the floor covered" % (ratio * 100))

    # R-07 nothing standing in a door's swing / approach
    for d in plan["doors"]:
        if len(d["pos"]) < 2:
            continue
        z = door_zone(d)
        for f in plan["furniture"]:
            if f["mounted"] or f["storey"] != d["storey"] or f["room"] not in (d["a"], d["b"]):
                continue
            if f["cat"] in {"tableware", "candle", "books", "tool", "trinket", "rug"}:
                continue
            if rect_overlap(z, f["rect"]) > 0.05:
                add("R-07 blocks a door", "%s f%d %s" % (rooms[f["room"]]["kind"], f["i"], f["key"]),
                    "inside the swing of door %d" % d["i"])

    # R-08 bed: not in the line of the door, not in the entrance room
    entrance = plan.get("entrance_room", -1)
    for f in plan["furniture"]:
        if f["cat"] != "bed" or f["mounted"]:
            continue
        if f["room"] == entrance:
            add("R-09 bed in the entrance room", "f%d %s" % (f["i"], f["key"]),
                "you walk in from the street onto a bed")
        for d in plan["doors"]:
            if d["storey"] != f["storey"] or f["room"] not in (d["a"], d["b"]) or len(d["pos"]) < 2:
                continue
            p = (d["pos"][0], d["pos"][-1])
            if rect_gap([p[0] - 0.01, p[1] - 0.01, 0.02, 0.02], f["rect"]) < BED_DOOR_LINE:
                add("R-08 bed at the door", "%s f%d %s" % (rooms[f["room"]]["kind"], f["i"], f["key"]),
                    "within %.1f m of door %d" % (BED_DOOR_LINE, d["i"]))

    # R-10 the household: seats at its table vs people its beds sleep
    beds = [f for f in plan["furniture"] if f["cat"] == "bed" and not f["mounted"]]
    sleepers = sum(max(1, round(min(f["rect"][2], f["rect"][3]) * SLEEPERS_PER_M_WIDTH)) for f in beds)
    if tables:
        main = max(tables, key=lambda t: t["rect"][2] * t["rect"][3])
        diners = [f for f in plan["furniture"] if f["cat"] in SEATS and not f["mounted"]
                  and f["room"] == main["room"] and seat_faces(f, main)]
        places = 0
        for s in diners:
            places += max(1, int(max(s["rect"][2], s["rect"][3]) / COVER_M)) if s["cat"] == "bench" else 1
        covers = int(2 * max(main["rect"][2], main["rect"][3]) / COVER_M)
        if sleepers and places < sleepers:
            add("R-10 too few places at table", "%s f%d" % (rooms[main["room"]]["kind"], main["i"]),
                "%d places for a household its beds say is %d" % (places, sleepers))
        if places and covers >= 3 * places:
            add("R-11 table out of scale", "%s f%d" % (rooms[main["room"]]["kind"], main["i"]),
                "table seats %d, %d places laid" % (covers, places))
    if not beds and any(r["kind"] in PRIVATE_KINDS for r in rooms.values()):
        add("R-12 nowhere to sleep", "house", "bedrooms but no bed")
    floor = sum(r["area"] for r in rooms.values())
    if sleepers and floor / sleepers > M2_PER_SLEEPER_MAX:
        add("R-20 house too big for its beds", "house",
            "%.0f m2 of floor for %d sleeper(s): %.0f m2 a head" % (floor, sleepers, floor / sleepers))

    # R-13 one household table (a dwelling, not an inn)
    # a sitting parlour's side table (group "sitting") is not a place to dine
    dining_tables = [t for t in tables if rooms.get(t["room"], {}).get("kind") in LIVING_KINDS | {"kitchen"}
                     and t.get("group") != "sitting"]
    if plan.get("purpose") not in ("innkeeper",) and len(dining_tables) > 1 and style != "rich":
        add("R-13 several dining tables", "house", "%d tables in living rooms" % len(dining_tables))

    # R-14 the fire is where the household lives (pre-modern)
    if style in PRE_MODERN_STYLES and hearth_room in rooms:
        hk = rooms[hearth_room]["kind"]
        eats_by_fire = any(t["room"] == hearth_room for t in tables)
        sits_by_fire = any(f["room"] == hearth_room and f["cat"] in SEATS for f in plan["furniture"])
        if not (eats_by_fire or sits_by_fire):
            add("R-14 cold living, fire with no one at it", "%s #%d" % (hk, hearth_room),
                "the only fire has no table and no seat; the household lives in another room")

    # R-15 repeated principal rooms; stores between living rooms
    kinds = Counter((r["kind"], r["storey"]) for r in rooms.values())
    for (k, s), n in kinds.items():
        if k in {"parlour", "hall", "kitchen", "dining_room"} and n > 1:
            add("R-15 duplicated room", "storey %d" % s, "%d %ss on one floor" % (n, k))
    living_storeys = {r["storey"] for r in rooms.values() if r["kind"] in LIVING_KINDS}
    for r in rooms.values():
        if r["kind"] == "store" and r["storey"] > 0 and r["storey"] in living_storeys and r["area"] > 15:
            add("R-16 big store on a living floor", "store #%d" % r["i"],
                "%.0f m2 of barrels beside the parlour, upstairs" % r["area"])

    # R-17 intimacy gradient: a bedroom reached only through another bedroom or the kitchen
    adj = defaultdict(set)
    for d in plan["doors"]:
        if d["a"] >= 0 and d["b"] >= 0:
            adj[d["a"]].add(d["b"])
            adj[d["b"]].add(d["a"])
    for i, r in rooms.items():
        if r["kind"] in PRIVATE_KINDS and adj[i]:
            via = {rooms[j]["kind"] for j in adj[i] if j in rooms}
            if via and via <= PRIVATE_KINDS:
                add("R-17 bedroom through a bedroom", "%s #%d" % (r["kind"], i), "only door leads to %s" % via)

    # R-18 period props: wall torches in a dwelling
    for f in plan["furniture"]:
        if f["key"] == "Torch_Metal" and rooms.get(f["room"], {}).get("kind") in LIVING_KINDS | PRIVATE_KINDS | {"kitchen"}:
            add("R-18 torch indoors", "%s f%d" % (rooms[f["room"]]["kind"], f["i"]),
                "an open torch on a timber wall; houses burned candles and rushlights")

    # R-19 matched seats round one table
    for t in tables:
        keys = {f["key"] for f in plan["furniture"] if f["cat"] == "seat" and f["host"] == t["i"]}
        if len(keys) > 1:
            add("R-19 mismatched chairs", "%s f%d" % (rooms[t["room"]]["kind"], t["i"]), " + ".join(sorted(keys)))
    return out


def main():
    src = sys.argv[1]
    data = json.load(open(src, encoding="utf-8"))
    allf = []
    per_case = Counter()
    for plan in data["plans"]:
        fs = audit(plan)
        allf += fs
        per_case[plan["case"]] = len(fs)
        for f in fs:
            print("%-18s %-38s %-32s %s" % (f["case"], f["rule"], f["where"], f["msg"]))
    print("\n== per rule (findings / plans with it) over %d plans" % len(data["plans"]))
    by_rule = defaultdict(set)
    cnt = Counter()
    for f in allf:
        by_rule[f["rule"]].add(f["case"])
        cnt[f["rule"]] += 1
    for rule in sorted(cnt):
        print("  %-40s %4d  in %2d plans" % (rule, cnt[rule], len(by_rule[rule])))
    print("\n== per plan")
    for c, n in per_case.most_common():
        print("  %-20s %d" % (c, n))
    if "--json" in sys.argv:
        json.dump(allf, open(sys.argv[sys.argv.index("--json") + 1], "w"), indent=1)


if __name__ == "__main__":
    main()
