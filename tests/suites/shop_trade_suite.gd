class_name ShopTradeSuite
extends RefCounted
## LIVE-SHOPS: one representative trade, the bakery, judged as a working shop.
##
## A shop is not its label. The customer comes in, walks to the counter and is
## served; behind the counter is a work area; the work draws on stores. The
## three must be separate to walk: the customer's lane may not be a baker's
## bench. The checks run on the walk grid (HouseNavCheck / WalkGrid), over a
## matrix frozen BEFORE tuning (three seeds x three footprints), and each role
## is removed in turn to prove the check can fail.

const SEEDS: Array[int] = [1, 6203, 8102]
const SIZES: Array[Vector2] = [Vector2(9.0, 12.0), Vector2(11.0, 15.0), Vector2(14.0, 18.0)]

const WORK_ROOMS: Array[StringName] = [&"kitchen", &"workshop"]
const WORK_CATS: Array[String] = ["workbench", "hearth", "anvil"]
const STORAGE_CATS: Array[String] = ["storage", "barrel", "crate", "sack", "chest"]

const WORK_STANCE := 0.6 # where the baker stands to use a bench or an oven


static func run() -> SuiteResult:
	var res := SuiteResult.new("shop trade (bakery)")
	for size in SIZES:
		for seed_ in SEEDS:
			var label := "bakery %dx%d seed %d" % [int(size.x), int(size.y), seed_]
			var plan := _make(&"bakery", size, seed_)
			var found := contract(plan)
			res.checked += 1
			for failure in found:
				res.fail("%s: %s" % [label, failure])
			# the same request is the same shop
			var again := _make(&"bakery", size, seed_)
			res.checked += 1
			if _signature(plan) != _signature(again):
				res.fail("%s: a repeat generation produced a different shop" % label)
			_controls(res, plan, label)
	# the same footprint as a general store must not read as a bakery
	var store := _make(&"general_store", Vector2(11.0, 15.0), 1)
	res.checked += 1
	var store_failures := contract(store)
	if not store_failures.any(func(f: String) -> bool: return f.begins_with("identity")):
		res.fail("a general store passes as a bakery")
	return res


static func _make(business: StringName, size: Vector2, seed_: int) -> HousePlan:
	var spec := ShopSpec.new()
	spec.business = business
	spec.style = &"townhouse"
	spec.width = size.x
	spec.length = size.y
	spec.height = 2.9
	return ShopGenerator.generate(spec, seed_)


static func _signature(plan: HousePlan) -> String:
	var parts: PackedStringArray = []
	for p in plan.furniture:
		parts.append("%s|%d|%s|%s" % [p["key"], int(p["room"]), str(Rect2(p["rect"])), str(p.get("host", -1))])
	return "\n".join(parts)


## Every role, removed in turn, must break the rule that names it.
static func _controls(res: SuiteResult, plan: HousePlan, label: String) -> void:
	var cases := {
		"counter": {"drop": ["counter"], "expect": "counter"},
		"storage": {"drop": STORAGE_CATS, "expect": "storage"},
		"work": {"drop": ["workbench"], "expect": "work area"},
		"oven": {"drop": ["hearth"], "expect": "identity"},
	}
	for role in cases:
		var spec: Dictionary = cases[role]
		var original := plan.furniture
		plan.furniture = _without(plan, spec["drop"])
		var found := contract(plan)
		plan.furniture = original
		res.checked += 1
		if not found.any(func(f: String) -> bool: return f.begins_with(String(spec["expect"]))):
			res.fail("%s: control '%s' removed and the '%s' rule did not fail" % [label, role, spec["expect"]])
	# a bench in the customer's lane is the baker's work crossing the public way
	var lane_case := _bench_in_lane(plan)
	res.checked += 1
	if lane_case.is_empty():
		res.fail("%s: no lane to put a bench in" % label)
		return
	var saved := plan.furniture
	plan.furniture = lane_case
	var found2 := contract(plan)
	plan.furniture = saved
	if not found2.any(func(f: String) -> bool: return f.begins_with("lane") or f.begins_with("route")):
		res.fail("%s: a bench in the customer lane did not fail the lane or route rule" % label)


static func _without(plan: HousePlan, cats: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in plan.furniture:
		if String(PropCatalog.category(String(p["key"]))) in cats:
			continue
		var copy: Dictionary = p.duplicate(true)
		copy["host"] = -1 # indices shift once something is gone
		out.append(copy)
	return out


static func _bench_in_lane(plan: HousePlan) -> Array[Dictionary]:
	var geometry := _lane(plan)
	if geometry.is_empty():
		return []
	var template := {}
	for p in plan.furniture:
		if PropCatalog.category(String(p["key"])) == "workbench":
			template = p.duplicate(true)
			break
	if template.is_empty():
		return []
	var mid: Vector2 = (Vector2(geometry["from"]) + Vector2(geometry["to"])) * 0.5
	# a run of bench right across the shop, between the door and the counter
	var floor_rect := HouseGeometry.room_floor_rect(plan, plan.entrance_room())
	var rect := Rect2(Vector2(floor_rect.position.x, mid.y - 0.5), Vector2(floor_rect.size.x, 1.0))
	template["rect"] = rect
	template["zone"] = rect
	template["room"] = plan.entrance_room()
	template["host"] = -1
	var out: Array[Dictionary] = []
	for p in plan.furniture:
		var copy: Dictionary = p.duplicate(true)
		copy["host"] = -1
		out.append(copy)
	out.append(template)
	return out


## The customer's lane: from just inside the front door to the counter's
## door-side stance. {} when there is no counter in the entry room.
static func _lane(plan: HousePlan) -> Dictionary:
	var door := plan.entrance()
	var room := plan.entrance_room()
	if door < 0 or room < 0:
		return {}
	var counter := _counter(plan, room)
	if counter.is_empty():
		return {}
	var inside: Vector2 = Vector2(plan.doors[door]["pos"]) \
		- Vector2(plan.doors[door]["normal"]) * (HouseGeometry.wall_thickness(plan.spec) * 0.5 + 0.2)
	var r: Rect2 = counter["rect"]
	var c := r.get_center()
	var best_point := c
	var best := INF
	for point in [Vector2(c.x, r.position.y - 0.55), Vector2(c.x, r.end.y + 0.55),
			Vector2(r.position.x - 0.55, c.y), Vector2(r.end.x + 0.55, c.y)]:
		var d := Vector2(point).distance_to(inside)
		if d < best:
			best = d
			best_point = point
	return {"from": inside, "to": best_point, "counter": r}


static func _counter(plan: HousePlan, room: int) -> Dictionary:
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(String(p["key"])) == "counter" and not p.get("mounted", false):
			return p
	return {}


static func _cats(plan: HousePlan, room := -1) -> Dictionary:
	var out := {}
	for p in plan.furniture:
		if room >= 0 and int(p["room"]) != room:
			continue
		out[String(PropCatalog.category(String(p["key"])))] = true
	return out


## Rooms reachable from `start` by interior doors, with their door count.
static func _door_neighbours(plan: HousePlan, room: int) -> Array[int]:
	var out: Array[int] = []
	for d in plan.doors:
		if bool(d.get("exterior", false)):
			continue
		var a := int(d["a"])
		var b := int(d["b"])
		if a == room and b >= 0 and not out.has(b):
			out.append(b)
		elif b == room and a >= 0 and not out.has(a):
			out.append(a)
	return out


## The measured bakery contract. Returns failure strings, empty when sound.
## Each begins with the name of its rule: counter, route, lane, work area,
## storage, identity.
static func contract(plan: HousePlan) -> Array[String]:
	var out: Array[String] = []
	var door := plan.entrance()
	var room := plan.entrance_room()
	if door < 0 or room < 0 or plan.kind_of(room) != &"sales_floor":
		out.append("route: the front door does not open onto the sales floor")
		return out
	var counter := _counter(plan, room)
	if counter.is_empty():
		out.append("counter: the sales floor has no counter to be served at")
		return out
	var nav := HouseNavCheck.new()
	nav.check(plan)
	var level := HousePlan.record_storey(plan.doors[door])
	var grid: WalkGrid = nav._grids.get(level)
	var geometry := _lane(plan)
	var inside: Vector2 = geometry["from"]
	var stance: Vector2 = geometry["to"]
	if grid == null or not grid.flood_from(inside):
		out.append("route: nowhere to stand inside the front door")
		return out

	# 1. arrival to counter: the customer can get there, and not by a detour
	var walked := grid.distance_to(stance, 0.5)
	var straight := inside.distance_to(stance)
	if walked == INF:
		out.append("route: the counter cannot be reached from the door")
	elif walked > straight * 1.6 + 1.5:
		out.append("route: the customer walks %.1fm to a counter %.1fm away" % [walked, straight])
	if not Rect2(HouseGeometry.room_floor_rect(plan, room)).grow(0.1).has_point(stance):
		out.append("route: the customer's place at the counter is outside the sales floor")

	# 2. the way still works with every work fixture's standing room taken
	# out of the public floor: the customer must not have to stand where the
	# baker stands in order to be served
	var saved := plan.furniture
	var padded: Array[Dictionary] = []
	for p in plan.furniture:
		var copy: Dictionary = p.duplicate(true)
		copy["host"] = -1
		if int(p["room"]) == room and not p.get("mounted", false) 				and String(PropCatalog.category(String(p["key"]))) in WORK_CATS:
			copy["rect"] = Rect2(p["rect"]).grow(WORK_STANCE)
		padded.append(copy)
	plan.furniture = padded
	var padded_nav := HouseNavCheck.new()
	padded_nav.check(plan)
	plan.furniture = saved
	var padded_grid: WalkGrid = padded_nav._grids.get(level)
	if padded_grid == null or not padded_grid.flood_from(inside):
		out.append("lane: work fixtures leave no standing room inside the door")
	else:
		var around := padded_grid.distance_to(stance, 0.5)
		if around == INF or around > walked * 1.4 + 1.0:
			out.append("lane: serving the counter means standing where the work is done")

	# 3. a work area deeper in the building than the counter, joined to the shop
	var work_rooms: Array[int] = []
	for r in range(plan.room_count()):
		if plan.kind_of(r) in WORK_ROOMS and r != room and "workbench" in _cats(plan, r):
			work_rooms.append(r)
	if work_rooms.is_empty():
		out.append("work area: no kitchen or workshop with a bench to work at")
	else:
		var served := false
		var behind := false
		for w in work_rooms:
			if _door_neighbours(plan, room).has(w) or _two_doors(plan, room, w):
				served = true
			for f in plan.furniture_of(w):
				var p: Dictionary = plan.furniture[f]
				if PropCatalog.category(String(p["key"])) != "workbench":
					continue
				var d := grid.distance_to(Rect2(p["rect"]).get_center(), 1.3)
				if d != INF and d > walked:
					behind = true
		if not served:
			out.append("work area: no door joins the shop to its work rooms")
		if not behind:
			out.append("work area: no bench is reachable behind the counter")

	# 4. stores that the work can draw on
	var linked := false
	var stored := false
	for p in plan.furniture:
		if not (String(PropCatalog.category(String(p["key"]))) in STORAGE_CATS):
			continue
		var r2 := int(p["room"])
		if r2 == room or p.get("mounted", false):
			continue
		stored = true
		var near_work := work_rooms.has(r2)
		for w2 in work_rooms:
			if _door_neighbours(plan, w2).has(r2):
				near_work = true
		if near_work and grid.reached(Rect2(p["rect"]), 0.8):
			linked = true
	if not stored:
		out.append("storage: no stock is kept behind the shop")
	elif not linked:
		out.append("storage: stock is kept, but not where the work can reach it")

	# 5. recognisable without its sign: oven, counter, bench and flour
	var cats := _cats(plan)
	for need in ["counter", "hearth", "workbench", "sack"]:
		if not cats.has(need):
			out.append("identity: a bakery has no %s" % need)
	return out


static func _two_doors(plan: HousePlan, a: int, b: int) -> bool:
	for mid in _door_neighbours(plan, a):
		if _door_neighbours(plan, mid).has(b):
			return true
	return false
