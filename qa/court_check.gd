class_name CourtCheck
extends RefCounted
## Is this a building round a yard, or a building with a hole in it?
##
## A courtyard is the oldest plan there is -- the monastery, the caravanserai,
## the inn with a yard, the Roman house -- and what makes one is not that it
## has a hole. Four things do, and each is a sentence and a measurement
## (WORLD 1.1):
##
##   SKY         the court is open: nothing is roofed over it, and it is big
##               enough that the sky reaches the ground in it
##   INWARD      the ranges LOOK IN. More of the windows onto the court than
##               away from it, which is the whole idea: a courtyard building
##               turns its back on the street
##   RING        you can walk right round. Every range that touches the court
##               has a door onto it, and the court joins them all
##   PROPORTION  the court is a room, not a light well and not a field: its
##               narrow side is no less than the ranges are tall, and it takes
##               a real share of the footprint
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

## Every rule, in the order it runs. A family may replace one through
## `check(plan, overrides)` (RuleSet, INT-020).
const RULES: Array[StringName] = [&"sky", &"inward", &"ring", &"proportion"]
const METHODS := {}

## A court narrower than this is a light well, not a yard.
const MIN_SIDE := 3.0
## And it has to be at least this much of the footprint to be the thing the
## building is arranged around.
const MIN_SHARE := 0.04
## How tall the ranges may stand for a court of a given width: a yard you
## cannot see the sky out of is a shaft.
const MAX_HEIGHT_RATIO := 1.35

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}
var replaced: Dictionary = {}


func check(plan: HousePlan, overrides: Dictionary = {}) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	stats["courts"] = plan.courts.size()
	if plan.has_court():
		replaced = RuleSet.run(self, RULES, METHODS, overrides, [plan], [plan],
			failures, warnings)
	return {"ok": failures.is_empty(), "failures": failures,
		"warnings": warnings, "stats": stats, "replaced": replaced}


## Nothing is built in the court and nothing is roofed over it.
##
## The plan check already says no ROOM stands in a court; what this adds is the
## furniture, because a court filled with the hall's tables is a hall with the
## roof off rather than a yard.
func _check_sky(plan: HousePlan) -> void:
	for ci in range(plan.courts.size()):
		var poly: PackedVector2Array = plan.court_outline(ci)
		for f in range(plan.furniture.size()):
			var p: Dictionary = plan.furniture[f]
			if p.get("mounted", false) or int(p["host"]) >= 0:
				continue
			if not PropCatalog.blocks_floor(String(p["key"])):
				continue
			if Poly.contains_point(poly, Rect2(p["rect"]).get_center()):
				failures.append("sky: %s stands in court %d, which is open ground"
					% [String(p["key"]), ci])
		for si in range(plan.stairs.size()):
			var r: Rect2 = plan.stairs[si].get("rect", Rect2())
			if r.size.x > 0.0 and Poly.contains_point(poly, r.get_center()):
				failures.append("sky: stair %d is built in court %d" % [si, ci])


## The ranges look IN.
##
## Counted over the windows, because that is what looking means. A courtyard
## building that put its glass on the street and its blank walls on the yard
## has the plan inside out -- it is a terrace with a hole in it.
func _check_inward(plan: HousePlan) -> void:
	var inward := 0
	var outward := 0
	for wi in range(plan.windows.size()):
		var w: Dictionary = plan.windows[wi]
		if _onto_court(plan, Vector2(w["pos"]), Vector2(w["normal"])):
			inward += 1
		else:
			outward += 1
	stats["windows_inward"] = inward
	stats["windows_outward"] = outward
	if inward == 0:
		failures.append("inward: not one window looks into the court")
	elif inward < outward:
		failures.append("inward: %d windows look into the court and %d away from it -- the plan is inside out"
			% [inward, outward])


## You can walk right round: every room on the court has a door onto it.
func _check_ring(plan: HousePlan) -> void:
	var touching: Array[int] = []
	for i in range(plan.room_count()):
		if _touches_court(plan, i):
			touching.append(i)
	stats["rooms_on_court"] = touching.size()
	if touching.is_empty():
		failures.append("ring: no room stands on the court")
		return
	var doored := 0
	for i2 in touching:
		var has := false
		for d in plan.doors_of(i2):
			var door: Dictionary = plan.doors[d]
			if _onto_court(plan, Vector2(door["pos"]), Vector2(door["normal"])) \
					or _onto_court(plan, Vector2(door["pos"]), -Vector2(door["normal"])):
				has = true
				break
		if has:
			doored += 1
	stats["doors_onto_court"] = doored
	if doored == 0:
		failures.append("ring: %d rooms stand on the court and not one opens onto it"
			% touching.size())


## The court is a room, not a light well and not a field.
func _check_proportion(plan: HousePlan) -> void:
	var site: Rect2 = HouseGeometry.site_rect(plan.spec)
	var footprint: float = site.size.x * site.size.y
	var tall: float = plan.spec.height * maxi(int(plan.spec.storeys), 1)
	for ci in range(plan.courts.size()):
		var rect: Rect2 = plan.courts[ci]["rect"]
		var narrow: float = minf(rect.size.x, rect.size.y)
		if narrow < MIN_SIDE:
			failures.append("proportion: court %d is %.2fm across -- that is a light well"
				% [ci, narrow])
			continue
		var share: float = (rect.size.x * rect.size.y) / maxf(footprint, 0.01)
		if share < MIN_SHARE:
			failures.append("proportion: court %d is %.1f%% of the footprint -- too little to arrange a building round"
				% [ci, share * 100.0])
		if narrow < tall / MAX_HEIGHT_RATIO:
			warnings.append("proportion: court %d is %.1fm across between %.1fm ranges -- little sky reaches the ground"
				% [ci, narrow, tall])


# ------------------------------------------------------------------ helpers

## Does an opening at `pos`, facing `n`, look into a court?
static func _onto_court(plan: HousePlan, pos: Vector2, n: Vector2) -> bool:
	var outside: Vector2 = pos + n * (HouseGeometry.WALL_T + 0.05)
	for ci in range(plan.courts.size()):
		if Poly.contains_point(plan.court_outline(ci), outside, 0.01):
			return true
	return false


## Does this room have a wall on a court?
static func _touches_court(plan: HousePlan, room: int) -> bool:
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	for ci in range(plan.courts.size()):
		if HousePlan.record_storey(plan.courts[ci]) > plan.storey_of_room(room):
			continue
		var court: Rect2 = plan.courts[ci]["rect"]
		if f.grow(HouseGeometry.WALL_T + 0.1).intersects(court):
			return true
	return false
