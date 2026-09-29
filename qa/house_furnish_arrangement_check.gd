class_name HouseFurnishArrangementCheck
extends RefCounted
## Furniture backing, seating, lighting, density, and clearance rules.

const TOL := 0.03
const BACKING_EPS := 0.000001

var failures: Array = []
var warnings: Array = []
var stats: Dictionary = {}


func _init(report: Dictionary = {}) -> void:
	failures = report.get("failures", [])
	warnings = report.get("warnings", [])
	stats = report.get("stats", {})



## A bed, a cabinet, a bookcase with its back to open air reads as furniture
## dropped from above. Check the back of every piece that asked for a wall.
func check_against_wall(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		if p.get("mounted", false) or p["host"] >= 0:
			continue
		if not PropCatalog.has_tag(p["key"], PropCatalog.WALL):
			continue
		if p.get("free_standing", false):
			# the furnisher could find no wall for it and said so; a workbench
			# out in the room is a compromise, not a defect
			warnings.append("against: %s stands free -- no wall in the room would take it"
				% HouseFurnishCheck.who(plan, f))
			continue
		var gap: float = back_gap(plan, p)
		# Vector2 is float32: allow one micrometre of metric roundoff at
		# the authored limit, without relaxing the physical backing rule.
		if gap > HouseGeometry.WALL_GAP + HouseGeometry.BED_HEAD_TOL + BACKING_EPS:
			failures.append("against: %s stands %.2fm off the wall it should back onto"
				% [HouseFurnishCheck.who(plan, f), gap])


## Distance from the back of a piece to the room wall behind it.
##
## Measured against the room's OWN WALLS rather than against the box round
## them. For a rectangle the two are the same thing and the answer does not
## move; for an octagon the wall behind a cabinet is a diagonal, and measuring
## to the bounding box reported every piece in the room as standing a metre and
## a quarter off a wall it was flat against (GEO-002).
static func back_gap(plan: HousePlan, p: Dictionary) -> float:
	var yaw: float = float(p["yaw"])
	var back := Vector2(sin(yaw), cos(yaw))          # the opposite of facing
	# The piece's OWN depth, not half its axis-aligned box: a cabinet turned
	# onto a diagonal wall has a box bigger than it is, and measuring from the
	# corner of that box put it a metre off a wall it was flat against.
	var foot: Vector2 = PropCatalog.footprint(String(p["key"])) 		* float(p.get("scale", 1.0))
	var edge: Vector2 = Rect2(p["rect"]).get_center() + back * (foot.y / 2.0)
	var breast := HouseGeometry.hearth_breast(plan)
	if PropCatalog.category(String(p["key"])) == "hearth" and not breast.is_empty() \
			and int(breast["room"]) == int(p["room"]):
		var normal: Vector2 = breast["normal"]
		var face: Vector2 = breast["centre"] + normal * float(breast["depth"]) * 0.5
		return absf((edge - face).dot(normal))
	var best := INF
	for w in HouseGeometry.room_walls(plan, int(p["room"])):
		var n: Vector2 = w["normal"]                 # points INTO the room
		if n.dot(back) > -0.5:
			continue                                 # not the wall behind it
		best = minf(best, absf((edge - Vector2(w["from"])).dot(n)))
	return best if is_finite(best) else 0.0


## A chair belongs at a table, facing it. A chair in the middle of the floor
## facing a wall is the single clearest sign of an automatic layout.
func check_seating(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		var cat: String = PropCatalog.category(p["key"])
		if cat != "seat" and cat != "bench":
			continue
		var host: int = p.get("host", -1)
		if host < 0:
			# it may still be at a table it was not explicitly given
			host = _nearest_table(plan, p)
		if host < 0:
			warnings.append("seating: %s is not at any table" % HouseFurnishCheck.who(plan, f))
			continue
		# toward the NEAREST PART of the table, not its middle: a stool tucked
		# under one end of a long table is still facing it, and measuring to
		# the centre would say it had its back to it
		var seat_c: Vector2 = Rect2(p["rect"]).get_center()
		var host_rect: Rect2 = plan.furniture[host]["rect"]
		var near := Vector2(
			clampf(seat_c.x, host_rect.position.x, host_rect.end.x),
			clampf(seat_c.y, host_rect.position.y, host_rect.end.y))
		var to_table: Vector2 = near - seat_c
		if to_table.length() > 1.6:
			failures.append("seating: %s is too far from the table it is drawn up to" % HouseFurnishCheck.who(plan, f))
			continue
		if to_table.length() < 0.01:
			continue        # tucked right under it; it can only be facing it
		var yaw: float = float(p["yaw"])
		var facing := Vector2(-sin(yaw), -cos(yaw))
		# a bench across the narrow end of a table is wider than the end it
		# faces, so its centre's nearest point is the table's corner: what
		# counts is that looking straight ahead from the seat you see table
		var across := Vector2(-facing.y, facing.x)
		var half_w: float = (absf(across.x) * Rect2(p["rect"]).size.x
			+ absf(across.y) * Rect2(p["rect"]).size.y) / 2.0
		var sees := false
		for t in [-0.8, -0.4, 0.0, 0.4, 0.8]:
			if _ray_hits_rect(seat_c + across * (half_w * t), facing, host_rect.grow(0.05), 1.6):
				sees = true
		if sees:
			continue
		if facing.dot(to_table.normalized()) < 0.5:
			failures.append("seating: %s has its back to the table it is drawn up to"
				% HouseFurnishCheck.who(plan, f))


static func _nearest_table(plan: HousePlan, p: Dictionary) -> int:
	var best := -1
	var best_d := 1.6            # a seat further off than this is not "at" it
	for f in plan.furniture_of(p["room"]):
		var cat: String = PropCatalog.category(plan.furniture[f]["key"])
		if cat != "table" and cat != "workbench" and cat != "counter":
			continue
		var d: float = Rect2(plan.furniture[f]["rect"]).get_center().distance_to(
			Rect2(p["rect"]).get_center())
		if d < best_d:
			best_d = d
			best = f
	return best


## Something to see by, in every room somebody uses after dark.
func check_light(plan: HousePlan) -> void:
	for i in range(plan.room_count()):
		if not HouseGeometry.is_habitable(plan.kind_of(i)):
			continue
		var lit := false
		for f in plan.furniture_of(i):
			if PropCatalog.has_tag(plan.furniture[f]["key"], PropCatalog.LIGHT):
				lit = true
				break
		if not lit:
			warnings.append("light: room %d (%s) has no lamp, sconce or candle"
				% [i, String(plan.kind_of(i))])


func check_density(plan: HousePlan) -> void:
	var worst := 0.0
	for i in range(plan.room_count()):
		var used := 0.0
		for f in plan.furniture_of(i):
			var p: Dictionary = plan.furniture[f]
			if p.get("mounted", false) or p["host"] >= 0:
				continue
			used += Rect2(p["rect"]).size.x * Rect2(p["rect"]).size.y
		var area: float = HouseGeometry.room_area(plan, i)
		var frac: float = used / maxf(area, 0.01)
		worst = maxf(worst, frac)
		if frac > HouseGeometry.FURNITURE_DENSITY_MAX:
			warnings.append("density: room %d (%s) is %.0f%% furniture by floor area"
				% [i, String(plan.kind_of(i)), frac * 100.0])
	stats["worst_density"] = snappedf(worst, 0.01)


func check_clear(plan: HousePlan) -> void:
	for z in plan.zones:
		var rect: Rect2 = z["rect"]
		var why: String = String(z.get("why", "clear floor"))
		var room: int = int(z.get("room", -1))
		for f in range(plan.furniture.size()):
			var p: Dictionary = plan.furniture[f]
			if p.get("mounted", false) or int(p["host"]) >= 0:
				continue
			if int(p["room"]) != room:
				continue
			if not PropCatalog.blocks_floor(String(p["key"])):
				continue
			var r: Rect2 = p["rect"]
			if not r.intersects(rect):
				continue
			var over: Rect2 = r.intersection(rect)
			if over.size.x * over.size.y < TOL:
				continue
			failures.append("clear: %s stands in the %s" % [HouseFurnishCheck.who(plan, f), why])


## Does a ray from `from` along `dir`, no longer than `reach`, cross `rect`?
static func _ray_hits_rect(from: Vector2, dir: Vector2, rect: Rect2, reach: float) -> bool:
	var to: Vector2 = from + dir.normalized() * reach
	var t0 := 0.0
	var t1 := 1.0
	var d: Vector2 = to - from
	for axis in range(2):
		var lo: float = rect.position[axis]
		var hi: float = rect.end[axis]
		if absf(d[axis]) < 0.00001:
			if from[axis] < lo or from[axis] > hi:
				return false
			continue
		var ta: float = (lo - from[axis]) / d[axis]
		var tb: float = (hi - from[axis]) / d[axis]
		if ta > tb:
			var swap: float = ta
			ta = tb
			tb = swap
		t0 = maxf(t0, ta)
		t1 = minf(t1, tb)
		if t0 > t1:
			return false
	return true
