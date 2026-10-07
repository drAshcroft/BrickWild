class_name HouseFurnishWalkCheck
extends RefCounted
## The rules the walkers taught. Two rounds of human walk QA (visualqa/
## walk_pins.jsonl, 3-7 Oct) pinned the same defects on the same seeds after
## the first round was declared fixed, and the furnishing check passed every
## one of them. Each rule here is one of those pins, written as a measurement:
##
##   TUCK         a seat drawn up to a table goes beside it, not into its trestle
##                end, and not into anything else (the `placed` rule skips every
##                hosted piece, so a stool inside a table was invisible)
##   PULL_OUT     the floor a seat is pulled out into is not another table's,
##                nor another seat's, nor a cupboard's
##   TABLE_BAND   nothing but seats stands along a table's long side
##   SEAT_KINDS   the seats round the tables of one room are one kind of seat
##   SEAT_COUNT   a table that is sat at seats at least two
##   SPARSE       a large room someone uses is furnished, not left empty
##   LAMPS        a large room has a light for every LAMP_AREA of floor
##   WORKTOP      a kitchen has something to work on, not only a fire
##   BEDSIDE      a bedside table stands at the bedside
##   STOWAGE      a room people sleep in has a chest or cupboard for every two beds
##   CORRIDOR     in a corridor, everything stands against a long wall
##   BED_DOOR     a bed is not right beside the door (feng shui, and sense)
##   FRONT_DOOR   nothing at all stands in the way in through the front door;
##                no "the room had nowhere else for it"
##
## Every rule fails on a pinned building; tests/suites/walk_pin_suite.gd holds
## the fixtures that prove it.

const TOL := 0.03
## How far a seat may slide under the long side of its table.
const TUCK_DEPTH := 0.25
## The strip along a table's long side that belongs to the people at it.
const SEAT_BAND := 0.45
## A lived-in room this large must have this share of its floor furnished.
const SPARSE_AREA := 20.0
const SPARSE_MIN := 0.10
## One light for every this many square metres.
const LAMP_AREA := 35.0
const LAMP_ROOM := 30.0
## A bedside table's gap to its bed.
const BEDSIDE_GAP := 0.35
## A bed's clearance from a door's own swing.
const BED_DOOR_GAP := 0.4
## Rooms people eat in: a table there with nobody at it is a sideboard.
const EATING := [&"hall", &"dining_room", &"mess", &"great_hall", &"guardroom", &"lounge"]

var failures: Array = []
var warnings: Array = []


func _init(report: Dictionary = {}) -> void:
	failures = report.get("failures", [])
	warnings = report.get("warnings", [])


static func _is_seat(key: String) -> bool:
	var cat := PropCatalog.category(key)
	return cat == "seat" or cat == "bench"


static func _is_table(key: String) -> bool:
	return PropCatalog.category(key) == "table"


## Stands on the floor and takes floor: not hung, not on a table, not a rug.
static func _on_floor(p: Dictionary) -> bool:
	if p.get("mounted", false):
		return false
	var key := String(p["key"])
	if int(p.get("host", -1)) >= 0 and not _is_seat(key):
		return false
	return PropCatalog.blocks_floor(key)


## The long axis of a table, as a unit vector in plan.
static func _long_axis(rect: Rect2) -> Vector2:
	return Vector2(1, 0) if rect.size.x >= rect.size.y else Vector2(0, 1)


func check_tuck(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		if not _is_seat(String(p["key"])) or p.get("mounted", false):
			continue
		var rect: Rect2 = p["rect"]
		var host := int(p.get("host", -1))
		if host >= 0 and _is_table(String(plan.furniture[host]["key"])):
			var t: Rect2 = plan.furniture[host]["rect"]
			var over := t.intersection(rect)
			if over.size.x > TOL and over.size.y > TOL:
				var long := _long_axis(t)
				# beyond the table's end along its length: that is the trestle
				var t_lo: float = t.position.dot(long)
				var t_hi: float = t.end.dot(long)
				var s_lo: float = rect.position.dot(long)
				var s_hi: float = rect.end.dot(long)
				if s_lo < t_lo - TOL or s_hi > t_hi + TOL:
					failures.append("tuck: %s is pushed %.2fm into the end of the table it is drawn up to"
						% [HouseFurnishCheck.who(plan, f), over.size.dot(long)])
				else:
					var depth: float = over.size.dot(Vector2(long.y, long.x))
					if depth > TUCK_DEPTH + TOL:
						failures.append("tuck: %s is %.2fm under the table it is drawn up to"
							% [HouseFurnishCheck.who(plan, f), depth])
		# and a seat, hosted or not, stands in nothing else
		for g in range(plan.furniture.size()):
			if g == f or g == host:
				continue
			var q: Dictionary = plan.furniture[g]
			if int(q["room"]) != int(p["room"]) or not _on_floor(q):
				continue
			if _is_seat(String(q["key"])) and g < f:
				continue        # a pair of seats is reported once
			var o := rect.intersection(Rect2(q["rect"]))
			if o.size.x > TOL and o.size.y > TOL:
				failures.append("tuck: %s stands in %s" % [HouseFurnishCheck.who(plan, f),
					HouseFurnishCheck.who(plan, g)])


func check_pull_out(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		var host := int(p.get("host", -1))
		if not _is_seat(String(p["key"])) or host < 0 or p.get("mounted", false):
			continue
		var zone: Rect2 = p.get("zone", Rect2())
		if zone.size.x <= 0.0 or zone.size.y <= 0.0:
			continue
		for g in range(plan.furniture.size()):
			if g == f or g == host:
				continue
			var q: Dictionary = plan.furniture[g]
			if int(q["room"]) != int(p["room"]) or not _on_floor(q):
				continue
			# a neighbour at the same table shares the same strip of floor
			if int(q.get("host", -1)) == host:
				continue
			var hits := zone.intersection(Rect2(q["rect"]))
			var why := ""
			if hits.size.x > TOL and hits.size.y > TOL:
				why = "stands on"
			elif _is_seat(String(q["key"])) and int(q.get("host", -1)) >= 0:
				var z2: Rect2 = q.get("zone", Rect2())
				var both := zone.intersection(z2)
				if g > f and both.size.x > TOL and both.size.y > TOL:
					why = "shares"
			if why != "":
				failures.append("pull_out: %s %s the floor %s is pulled out into"
					% [HouseFurnishCheck.who(plan, g), why, HouseFurnishCheck.who(plan, f)])


func check_table_band(plan: HousePlan) -> void:
	for t in range(plan.furniture.size()):
		var tp: Dictionary = plan.furniture[t]
		if not _is_table(String(tp["key"])) or tp.get("mounted", false):
			continue
		# a table nobody is drawn up to, outside a room people eat in, is a desk
		# or a side table: the floor along it is anybody's
		var sat := false
		for g in plan.furniture_of(int(tp["room"])):
			if int(plan.furniture[g].get("host", -1)) == t and _is_seat(String(plan.furniture[g]["key"])):
				sat = true
		if not sat and not plan.kind_of(int(tp["room"])) in EATING:
			continue
		var tr: Rect2 = tp["rect"]
		var across := Vector2(1, 0) if _long_axis(tr) == Vector2(0, 1) else Vector2(0, 1)
		for side in [-1.0, 1.0]:
			# the strip along one long side, the length of the table
			var band := tr
			if across.x > 0.0:
				band = Rect2(Vector2(tr.position.x - SEAT_BAND if side < 0 else tr.end.x, tr.position.y),
					Vector2(SEAT_BAND, tr.size.y))
			else:
				band = Rect2(Vector2(tr.position.x, tr.position.y - SEAT_BAND if side < 0 else tr.end.y),
					Vector2(tr.size.x, SEAT_BAND))
			if not HouseGeometry.room_floor_rect(plan, int(tp["room"])).intersects(band.grow(-TOL)):
				continue
			for g in plan.furniture_of(int(tp["room"])):
				var q: Dictionary = plan.furniture[g]
				if g == t or not _on_floor(q) or _is_seat(String(q["key"])) or _is_table(String(q["key"])):
					continue
				var o := band.intersection(Rect2(q["rect"]))
				if o.size.x > 0.1 and o.size.y > 0.1:
					failures.append("table_band: %s stands where someone sits at %s"
						% [HouseFurnishCheck.who(plan, g), HouseFurnishCheck.who(plan, t)])


func check_seat_kinds(plan: HousePlan) -> void:
	for i in range(plan.room_count()):
		var kinds := {}
		for f in plan.furniture_of(i):
			var p: Dictionary = plan.furniture[f]
			if PropCatalog.category(String(p["key"])) != "seat" or int(p.get("host", -1)) < 0:
				continue
			if not _is_table(String(plan.furniture[int(p["host"])]["key"])):
				continue
			kinds[String(p["key"])] = true
		if kinds.size() > 1:
			failures.append("seat_kinds: room %d (%s) sets its tables with %s"
				% [i, String(plan.kind_of(i)), " and ".join(PackedStringArray(kinds.keys()))])


## How many people a seat holds: a bench one per 0.6 m of its length.
static func _holds(p: Dictionary) -> int:
	if PropCatalog.category(String(p["key"])) != "bench":
		return 1
	var r: Rect2 = p["rect"]
	return maxi(1, int(floor(maxf(r.size.x, r.size.y) / 0.6)))


func check_seat_count(plan: HousePlan) -> void:
	for t in range(plan.furniture.size()):
		var tp: Dictionary = plan.furniture[t]
		if not _is_table(String(tp["key"])) or tp.get("mounted", false) or String(tp.get("row", "")) != "":
			continue
		var holds := 0
		for f in plan.furniture_of(int(tp["room"])):
			if int(plan.furniture[f].get("host", -1)) == t and _is_seat(String(plan.furniture[f]["key"])):
				holds += _holds(plan.furniture[f])
		var eats: bool = plan.kind_of(int(tp["room"])) in EATING
		if holds == 1 or (holds == 0 and eats):
			failures.append("seat_count: %s seats %d" % [HouseFurnishCheck.who(plan, t), holds])


## A corridor is for walking; its emptiness is the point.
static func _corridor(rect: Rect2) -> bool:
	var lo := minf(rect.size.x, rect.size.y)
	return lo < 2.6 or maxf(rect.size.x, rect.size.y) > lo * 3.5


func check_sparse(plan: HousePlan) -> void:
	for i in range(plan.room_count()):
		if not HouseGeometry.is_habitable(plan.kind_of(i)):
			continue
		var area: float = HouseGeometry.room_area(plan, i)
		if area < SPARSE_AREA or _corridor(HouseGeometry.room_floor_rect(plan, i)):
			continue
		var used := 0.0
		for f in plan.furniture_of(i):
			var p: Dictionary = plan.furniture[f]
			if _on_floor(p) or (_is_table(String(p["key"])) and not p.get("mounted", false)):
				used += Rect2(p["rect"]).get_area()
		if used / area < SPARSE_MIN:
			failures.append("sparse: room %d (%s) is %.0f m2 with %.0f%% of it furnished"
				% [i, String(plan.kind_of(i)), area, used / area * 100.0])


func check_corridor(plan: HousePlan) -> void:
	for i in range(plan.room_count()):
		var r := HouseGeometry.room_floor_rect(plan, i)
		if not _corridor(r):
			continue
		var across := 1 if r.size.x >= r.size.y else 0      # the short axis
		for f in plan.furniture_of(i):
			var p: Dictionary = plan.furniture[f]
			if not _on_floor(p):
				continue
			var q: Rect2 = p["rect"]
			var gap := minf(q.position[across] - r.position[across], r.end[across] - q.end[across])
			if gap > HouseGeometry.WALL_GAP + 0.15:
				failures.append("corridor: %s stands loose %.2fm off the wall of a %.1fm corridor"
					% [HouseFurnishCheck.who(plan, f), gap, r.size[across]])


func check_lamps(plan: HousePlan) -> void:
	for i in range(plan.room_count()):
		if not HouseGeometry.is_habitable(plan.kind_of(i)):
			continue
		var area: float = HouseGeometry.room_area(plan, i)
		if area < LAMP_ROOM:
			continue
		var lights := 0
		for f in plan.furniture_of(i):
			if PropCatalog.has_tag(String(plan.furniture[f]["key"]), PropCatalog.LIGHT):
				lights += 1
		var want := int(ceil(area / LAMP_AREA))
		if lights < want:
			failures.append("lamps: room %d (%s) is %.0f m2 lit by %d light(s), wants %d"
				% [i, String(plan.kind_of(i)), area, lights, want])


func check_worktop(plan: HousePlan) -> void:
	for i in range(plan.room_count()):
		if plan.kind_of(i) != &"kitchen":
			continue
		var has := false
		for f in plan.furniture_of(i):
			if PropCatalog.category(String(plan.furniture[f]["key"])) in ["table", "workbench", "counter"]:
				has = true
		if not has:
			failures.append("worktop: room %d (kitchen) has a fire and nothing to prepare food on"
				% i)


func check_bedside(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(String(p["key"])) != "nightstand":
			continue
		var best := INF
		for g in plan.furniture_of(int(p["room"])):
			if PropCatalog.category(String(plan.furniture[g]["key"])) == "bed":
				best = minf(best, _gap(Rect2(p["rect"]), Rect2(plan.furniture[g]["rect"])))
		if best > BEDSIDE_GAP:
			failures.append("bedside: %s stands %s from any bed" % [HouseFurnishCheck.who(plan, f),
				"%.2fm" % best if is_finite(best) else "a room away"])


func check_stowage(plan: HousePlan) -> void:
	for i in range(plan.room_count()):
		var beds := 0
		var kept := 0
		for f in plan.furniture_of(i):
			var cat := PropCatalog.category(String(plan.furniture[f]["key"]))
			if cat == "bed":
				beds += 1
			elif cat in ["chest", "storage", "nightstand"]:
				kept += 1
		if beds > 0 and kept < int(ceil(beds / 2.0)):
			failures.append("stowage: room %d (%s) sleeps %d with %d chest(s) or cupboard(s)"
				% [i, String(plan.kind_of(i)), beds, kept])


func check_bed_door(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(String(p["key"])) != "bed":
			continue
		for d in plan.doors_of(int(p["room"])):
			var door: Dictionary = plan.doors[d]
			if HousePlan.record_storey(door) != HousePlan.record_storey(p):
				continue
			for side in [-1.0, 1.0]:
				var swing: Rect2 = HouseGeometry.door_clear_rect(door, side)
				if Rect2(p["rect"]).intersects(swing.grow(BED_DOOR_GAP)):
					failures.append("bed_door: the %s lies right beside door %d"
						% [HouseFurnishCheck.who(plan, f), d])
					break


func check_front_door(plan: HousePlan) -> void:
	var d := plan.entrance()
	if d < 0:
		return
	var door: Dictionary = plan.doors[d]
	var n: Vector2 = door["normal"]
	var along := Vector2(n.y, -n.x).abs()
	var c: Vector2 = door["pos"]
	var w := float(door["width"])
	for side in [-1.0, 1.0]:
		var a: Vector2 = c - along * (w / 2.0)
		var b: Vector2 = c + along * (w / 2.0) + n * side * HouseFurnishPlacement.DOOR_APPROACH
		var way := Rect2(a.min(b), (b - a).abs())
		for f in range(plan.furniture.size()):
			var p: Dictionary = plan.furniture[f]
			if HousePlan.record_storey(p) != HousePlan.record_storey(door) or not _on_floor(p):
				continue
			var o := way.intersection(Rect2(p["rect"]))
			if o.size.x > TOL and o.size.y > TOL:
				failures.append("front_door: %s stands in the way in through the front door"
					% HouseFurnishCheck.who(plan, f))


## The clear gap between two rectangles; 0 when they touch or overlap.
static func _gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(dx, dy).length()
