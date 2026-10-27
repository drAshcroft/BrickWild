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

## The general store's matrix: 3 footprints x 2 seeds, frozen before tuning.
const STORE_SEEDS: Array[int] = [1, 8102]
const GOODS_CATS: Array[String] = ["table", "crate", "barrel", "sack", "shelf", "storage", "chest"]
const STOCK_CATS: Array[String] = ["storage", "barrel", "crate", "sack", "chest"]
const BROWSE_STANCE := 0.45 # where the customer stands to look at a table of goods

## The other trades, 3 footprints x 2 seeds each, frozen before tuning
## (2026-10-20). Counter shops serve across a counter on the sales floor and
## work at a bench in the workshop behind it, as the bakery does; workshop-front
## trades take the customer into the work and serve him at it.
const TRADE_SEEDS: Array[int] = [1, 8102]
const COUNTER_TRADES: Array[StringName] = [&"butcher", &"apothecary", &"tailor"]
const WORK_FRONT_TRADES := {&"carpenter": "workbench", &"blacksmith": "anvil"}
## What makes each trade legible without its sign. `need`: categories the shop
## must hold; `work`: one of these must be in a work room beside the bench (the
## trade's own work, not just a bench); `ban`: another trade's fixtures; `sign`:
## the category whose removal must fail identity in the negative control.
const IDENTITY := {
	&"bakery": {"need": ["counter", "hearth", "workbench", "sack"], "work": [], "ban": [], "sign": "hearth"},
	&"butcher": {"need": ["counter", "blade", "workbench", "barrel"], "work": ["blade"],
		"ban": ["hearth", "anvil", "alchemy"], "sign": "blade"},
	&"apothecary": {"need": ["counter", "alchemy", "storage", "workbench"], "work": ["alchemy"],
		"ban": ["anvil", "hearth", "blade"], "sign": "alchemy"},
	&"tailor": {"need": ["counter", "rack", "sack", "shelf", "workbench"], "work": ["sack", "rack"],
		"ban": ["anvil", "hearth", "alchemy"], "sign": "rack"},
	&"carpenter": {"need": ["workbench", "rack", "bench", "crate"], "work": [],
		"ban": ["anvil", "hearth", "alchemy"], "sign": "rack"},
	&"blacksmith": {"need": ["hearth", "anvil", "workbench"], "work": [],
		"ban": ["alchemy", "counter"], "sign": "hearth"},
}
## Another trade's sign: a piece the customer must not see on the public floor
## of any trade but these. A rack of bottles is the apothecary; a sword is the
## smith's; a crate of apples or carrots is the grocer.
const SIGN_KEYS := {
	"Shelf_Small_Bottles": [&"apothecary", &"general_store"],
	"Sword_Bronze": [&"blacksmith"],
	"FarmCrate_Apple": [&"general_store", &"bakery"],
	"FarmCrate_Carrot": [&"general_store", &"bakery"],
	"Barrel_Apples": [&"general_store", &"bakery"],
}
## The fixtures a workshop-front trade works at, padded by WORK_STANCE.
const FRONT_WORK_CATS: Array[String] = ["workbench", "hearth", "anvil", "bench"]


static func run() -> SuiteResult:
	var res := SuiteResult.new("shop trade (bakery, store, five trades)")
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
	_run_store(res)
	_run_trades(res)
	_run_traits(res)
	_run_walk_furnish(res)
	return res


## SHOP-WALK-FURNISH (26 Oct walk pins): the 11 counter trades x seeds 1 and
## 8102 at the walk's 11 x 14 m footprint, in the two styles that were pinned
## plus the plain townhouse. No floor piece may stand in the walk through any
## door or the keeper's stance at the serving hatch, and no fitting may hang
## through the body of the piece below it. Each rule has a failing control.
const WALK_TRADES: Array[StringName] = [&"apothecary", &"alchemist_laboratory", &"bakery",
	&"blacksmith", &"butcher", &"carpenter", &"general_store", &"tailor", &"tavern",
	&"inn", &"restaurant"]
const WALK_STYLES: Array[StringName] = [&"african", &"rich", &"townhouse"]


static func _walk_plan(business: StringName, style: StringName, seed_: int) -> HousePlan:
	var spec := ShopSpec.new()
	spec.business = business
	spec.style = style
	spec.width = 11.0
	spec.length = 14.0
	spec.height = 2.8
	return ShopGenerator.generate(spec, seed_)


static func walk_clearance(plan: HousePlan) -> Array:
	var physical := HouseFurnishPhysicalCheck.new()
	physical.check_shop_clearance(plan)
	return physical.failures


static func _run_walk_furnish(res: SuiteResult) -> void:
	var door_control := 0
	var hatch_control := 0
	var hung_control := 0
	for style in WALK_STYLES:
		for business in WALK_TRADES:
			for seed_ in [1, 8102]:
				var label := "walk %s %s seed %d" % [style, business, seed_]
				var plan := _walk_plan(business, style, seed_)
				res.checked += 1
				for failure in walk_clearance(plan):
					res.fail("%s: %s" % [label, failure])
				# controls, once per kind of defect, on the first shop that can take one
				if hatch_control == 0:
					var zone := _hatch_zone(plan)
					if zone.size.x > 0.0:
						hatch_control = 1
						_control(res, plan, label + " hatch control", "serving hatch",
							_crate_at(plan, int(zone["room"]), Rect2(zone["rect"])))
				if door_control == 0:
					var entry := plan.entrance()
					if entry >= 0:
						door_control = 1
						var door: Dictionary = plan.doors[entry]
						var at := Vector2(door["pos"]) - Vector2(door["normal"]) * 0.9
						_control(res, plan, label + " door control", "door",
							_crate_at(plan, int(door["a"]), Rect2(at - Vector2(0.3, 0.3), Vector2(0.6, 0.6))))
				if hung_control == 0:
					for i in plan.furniture.size():
						var item: Dictionary = plan.furniture[i]
						if bool(item.get("mounted", false)) and PropCatalog.category(String(item["key"])) == "shelf":
							hung_control = 1
							var box := HouseFurnishGeometry.mounted_box(item)
							var rect: Rect2 = box["rect"]
							_control(res, plan, label + " hung control", "hung above",
								_crate_at(plan, int(item["room"]), rect, 2.2))
							break


static func _hatch_zone(plan: HousePlan) -> Dictionary:
	for room in plan.room_count():
		for zone in HouseFurnishGeometry.shop_keep_clear(plan, room):
			if String(zone["why"]).contains("hatch"):
				return {"room": room, "rect": zone["rect"], "size": Rect2(zone["rect"]).size}
	return {"size": Vector2.ZERO}


## A tall crate record added to the plan, the check run, the record removed.
static func _crate_at(plan: HousePlan, room: int, rect: Rect2, height_scale := -1.0) -> Dictionary:
	var rec := HouseFurnishGeometry.candidate("Crate_Metal", rect.get_center(), 0.0)
	rec["room"] = room
	rec["storey"] = 0
	if height_scale > 0.0:
		rec["height_scale"] = height_scale
	return rec


static func _control(res: SuiteResult, plan: HousePlan, label: String, word: String, rec: Dictionary) -> void:
	plan.furniture.append(rec)
	var found := walk_clearance(plan)
	plan.furniture.pop_back()
	res.checked += 1
	if not found.any(func(f: String) -> bool: return f.contains(word)):
		res.fail("%s: a crate put in the %s passed the clearance check" % [label, word])


## The general store, judged as a store: goods on show, a counter, stock behind.
static func _run_store(res: SuiteResult) -> void:
	for size in SIZES:
		for seed_ in STORE_SEEDS:
			var label := "general store %dx%d seed %d" % [int(size.x), int(size.y), seed_]
			var plan := _make(&"general_store", size, seed_)
			res.checked += 1
			for failure in store_contract(plan):
				res.fail("%s: %s" % [label, failure])
			res.checked += 1
			if _signature(plan) != _signature(_make(&"general_store", size, seed_)):
				res.fail("%s: a repeat generation produced a different shop" % label)
			_store_controls(res, plan, label)
	# a bakery's goods are an oven and a bench, not a shopkeeper's stock
	var bakery := _make(&"bakery", Vector2(11.0, 15.0), 1)
	res.checked += 1
	if not store_contract(bakery).any(func(f: String) -> bool: return f.begins_with("identity")):
		res.fail("a bakery passes as a general store")


## Each role of the store, removed in turn, must break the rule that names it.
static func _store_controls(res: SuiteResult, plan: HousePlan, label: String) -> void:
	var front := plan.entrance_room()
	var cases := {
		"counter": {"drop": ["counter"], "room": -1, "expect": "counter"},
		"goods": {"drop": GOODS_CATS, "room": front, "expect": "stock"},
		"stockroom": {"drop": STOCK_CATS, "room": -2, "expect": "storage"},
	}
	for role in cases:
		var spec: Dictionary = cases[role]
		var original := plan.furniture
		plan.furniture = _without_in(plan, spec["drop"], int(spec["room"]), front)
		var found := store_contract(plan)
		plan.furniture = original
		res.checked += 1
		if not found.any(func(f: String) -> bool: return f.begins_with(String(spec["expect"]))):
			res.fail("%s: control '%s' removed and the '%s' rule did not fail" % [label, role, spec["expect"]])
	# a hearth makes the premises a cookshop: it is not a store's fitting
	var oven := {}
	for p in plan.furniture:
		if PropCatalog.category(String(p["key"])) == "workbench":
			oven = p.duplicate(true)
			break
	if not oven.is_empty():
		oven["key"] = "Cauldron"
		oven["host"] = -1
		var with_oven := plan.furniture.duplicate(true)
		with_oven.append(oven)
		var saved := plan.furniture
		plan.furniture = with_oven
		var found3 := store_contract(plan)
		plan.furniture = saved
		res.checked += 1
		if not found3.any(func(f: String) -> bool: return f.begins_with("identity")):
			res.fail("%s: a hearth in a general store did not fail identity" % label)
	# a run of bench right across the shop is no way to the counter
	var lane_case := _bench_in_lane(plan)
	res.checked += 1
	if lane_case.is_empty():
		res.fail("%s: no lane to put a bench in" % label)
		return
	var saved2 := plan.furniture
	plan.furniture = lane_case
	var found2 := store_contract(plan)
	plan.furniture = saved2
	if not found2.any(func(f: String) -> bool: return f.begins_with("lane") or f.begins_with("route")):
		res.fail("%s: a bench in the customer lane did not fail the lane or route rule" % label)


## Everything but the named categories: in `room` only when room >= 0, outside
## the front room only when room == -2, anywhere when room == -1.
static func _without_in(plan: HousePlan, cats: Array, room: int, front: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in plan.furniture:
		var in_cat: bool = String(PropCatalog.category(String(p["key"]))) in cats
		var in_scope: bool = room == -1 or (room == -2 and int(p["room"]) != front) \
			or (room >= 0 and int(p["room"]) == room)
		if in_cat and in_scope:
			continue
		var copy: Dictionary = p.duplicate(true)
		copy["host"] = -1
		out.append(copy)
	return out


static func _make(business: StringName, size: Vector2, seed_: int) -> HousePlan:
	var spec := ShopSpec.new()
	spec.business = business
	# as sarchetype builds them: the workshop-front trades in a long hall
	spec.style = &"longhall" if WORK_FRONT_TRADES.has(business) else &"townhouse"
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


static func _bench_in_lane(plan: HousePlan, cat := "counter") -> Array[Dictionary]:
	var geometry := _lane(plan, cat)
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
static func _lane(plan: HousePlan, cat := "counter") -> Dictionary:
	var door := plan.entrance()
	var room := plan.entrance_room()
	if door < 0 or room < 0:
		return {}
	var counter := _counter(plan, room, cat)
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


static func _counter(plan: HousePlan, room: int, cat := "counter") -> Dictionary:
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(String(p["key"])) == cat and not p.get("mounted", false):
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
	return counter_contract(plan, &"bakery")


## The counter-shop contract for `business` (bakery, butcher, apothecary,
## tailor): the bakery's rules, with the trade's own identity from IDENTITY.
static func counter_contract(plan: HousePlan, business: StringName) -> Array[String]:
	var out: Array[String] = []
	var ident: Dictionary = IDENTITY[business]
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
		# the bench is the trade's: its own work lies beside it
		var work_signs: Array = ident["work"]
		if not work_signs.is_empty():
			var signed := false
			for w3 in work_rooms:
				for sign_cat in work_signs:
					if _cats(plan, w3).has(String(sign_cat)):
						signed = true
			if not signed:
				out.append("work area: no %s at the %s's bench" % ["/".join(work_signs), business])

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

	# 5. recognisable without its sign (the bakery: oven, counter, bench, flour)
	out.append_array(_identity(plan, business))
	return out


## The identity rule shared by every trade: what it must hold, what it must
## not, and no other trade's sign where the customer stands.
static func _identity(plan: HousePlan, business: StringName) -> Array[String]:
	var out: Array[String] = []
	var ident: Dictionary = IDENTITY[business]
	var cats := _cats(plan)
	for need in ident["need"]:
		if not cats.has(String(need)):
			out.append("identity: a %s has no %s" % [business, need])
	for banned in ident["ban"]:
		if cats.has(String(banned)):
			out.append("identity: a %s has a %s" % [business, banned])
	var front := plan.entrance_room()
	for f in plan.furniture_of(front):
		var key := String(plan.furniture[f]["key"])
		if SIGN_KEYS.has(key) and not (SIGN_KEYS[key] as Array).has(business):
			out.append("identity: a %s shows a %s, another trade's sign" % [business, key])
	return out


## The general store's contract. Rule names: counter, route, lane, stock,
## storage, identity.
static func store_contract(plan: HousePlan) -> Array[String]:
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

	# 1. arrival to counter, and by no great detour
	var walked := grid.distance_to(stance, 0.5)
	var straight := inside.distance_to(stance)
	if walked == INF:
		out.append("route: the counter cannot be reached from the door")
	elif walked > straight * 1.6 + 1.5:
		out.append("route: the customer walks %.1fm to a counter %.1fm away" % [walked, straight])

	# 2. a customer browsing a table or a bin stands beside it: with that
	# standing room taken out of the floor the counter must still be reachable
	var saved := plan.furniture
	var padded: Array[Dictionary] = []
	for p in plan.furniture:
		var copy: Dictionary = p.duplicate(true)
		copy["host"] = -1
		if int(p["room"]) == room and not p.get("mounted", false) \
				and String(PropCatalog.category(String(p["key"]))) in ["table", "crate", "barrel", "sack"]:
			copy["rect"] = Rect2(p["rect"]).grow(BROWSE_STANCE)
		padded.append(copy)
	plan.furniture = padded
	var padded_nav := HouseNavCheck.new()
	padded_nav.check(plan)
	plan.furniture = saved
	var padded_grid: WalkGrid = padded_nav._grids.get(level)
	if padded_grid == null or not padded_grid.flood_from(inside):
		out.append("lane: browsing room leaves no standing room inside the door")
	elif walked != INF:
		var around := padded_grid.distance_to(stance, 0.5)
		if around == INF or around > walked * 1.4 + 1.0:
			out.append("lane: reaching the counter means standing where the goods are looked at")

	# 3. goods on show: several kinds, some of them shelving
	var shown := {}
	var shelved := false
	for f in plan.furniture_of(room):
		var cat := String(PropCatalog.category(String(plan.furniture[f]["key"])))
		if cat in GOODS_CATS:
			shown[cat] = true
		if cat == "shelf":
			shelved = true
	if shown.size() < 3:
		out.append("stock: only %d kind(s) of goods are on show" % shown.size())
	if not shelved:
		out.append("stock: nothing is shelved on the sales floor")

	# 4. stock kept behind the shop, joined to it and reachable from the lane
	var stocked := 0
	var linked := false
	for p in plan.furniture:
		var r := int(p["room"])
		if r == room or p.get("mounted", false):
			continue
		if not (String(PropCatalog.category(String(p["key"]))) in STOCK_CATS):
			continue
		stocked += 1
		if (_door_neighbours(plan, room).has(r) or _two_doors(plan, room, r)) \
				and grid.reached(Rect2(p["rect"]), 0.8):
			linked = true
	if stocked < 2:
		out.append("storage: no stock is kept behind the shop")
	elif not linked:
		out.append("storage: stock is kept, but not in a room the shop opens onto")

	# 5. identity: a counter and a spread of goods, no oven, no forge
	var cats := _cats(plan)
	for banned in ["hearth", "anvil"]:
		if cats.has(banned):
			out.append("identity: a general store has a %s" % banned)
	for need in ["crate", "barrel"]:
		if not cats.has(need):
			out.append("identity: a general store has no %s" % need)
	return out


static func _two_doors(plan: HousePlan, a: int, b: int) -> bool:
	for mid in _door_neighbours(plan, a):
		if _door_neighbours(plan, mid).has(b):
			return true
	return false


## What the blind door-eye review judged (SHOP-<KIND>-TRAITS): from the street
## door, the trade's serving place is in view, and the trade's goods are laid on
## a board in view. The serving place is the counter of a counter trade, the
## anvil or bench of a work-front trade (the customer is served AT the work, so
## the checklist's "counter" is that piece) and the alchemist's counter.
const TRAIT_TRADES: Array[StringName] = [&"butcher", &"apothecary", &"tailor",
	&"alchemist_laboratory", &"blacksmith", &"carpenter"]
const BOARD_CATS: Array[String] = ["counter", "shelf", "rack", "workbench", "anvil", "bench", "hearth"]


static func trait_serving_cat(business: StringName) -> String:
	return WORK_FRONT_TRADES.get(business, "counter")


## Rule names: serving (the place is not in the door's view), wares (no board
## in view, or the trade has no goods drawn).
static func traits_contract(plan: HousePlan, business: StringName) -> Array[String]:
	var out: Array[String] = []
	var cat := trait_serving_cat(business)
	if ShopSightline.seen_of(plan, cat).is_empty():
		out.append("serving: the %s is not in the door's view" % cat)
	if not (preload("res://src/shop/shop_wares.gd")).TRADES.has(business):
		out.append("wares: %s has no goods drawn" % business)
	var pose := ShopSightline.door_pose(plan)
	var boards := 0
	for f in plan.furniture_of(plan.entrance_room()):
		var p: Dictionary = plan.furniture[f]
		if String(PropCatalog.category(String(p["key"]))) in BOARD_CATS 				and ShopSightline.sees(plan, pose, p):
			boards += 1
	if boards == 0:
		out.append("wares: no board for the goods is in the door's view")
	return out


static func _run_traits(res: SuiteResult) -> void:
	for business in TRAIT_TRADES:
		for size in SIZES:
			for seed_ in TRADE_SEEDS:
				var label := "traits %s %dx%d seed %d" % [business, int(size.x), int(size.y), seed_]
				var plan := _make(business, size, seed_)
				res.checked += 1
				for failure in traits_contract(plan, business):
					res.fail("%s: %s" % [label, failure])
	# controls: the serving place taken away, then turned from the door's view
	for business in TRAIT_TRADES:
		var plan2 := _make(business, SIZES[1], TRADE_SEEDS[0])
		var front := plan2.entrance_room()
		var cat := trait_serving_cat(business)
		var saved := plan2.furniture
		plan2.furniture = _without_in(plan2, [cat], front, front)
		var found := traits_contract(plan2, business)
		plan2.furniture = saved
		res.checked += 1
		if not found.any(func(f: String) -> bool: return f.begins_with("serving")):
			res.fail("traits %s: serving place removed and the 'serving' rule did not fail" % business)
		var pose := ShopSightline.door_pose(plan2)
		var hidden: Array[Dictionary] = []
		for p in plan2.furniture:
			var copy: Dictionary = p.duplicate(true)
			copy["host"] = -1
			if int(p["room"]) == front and String(PropCatalog.category(String(p["key"]))) == cat 					and not p.get("mounted", false):
				# swung to the door's own wall, far outside its field of view
				var side: Vector2 = Vector2(pose["dir"]).orthogonal() * 20.0
				copy["rect"] = Rect2(Rect2(p["rect"]).position + side, Rect2(p["rect"]).size)
			hidden.append(copy)
		plan2.furniture = hidden
		var found2 := traits_contract(plan2, business)
		plan2.furniture = saved
		res.checked += 1
		if not found2.any(func(f: String) -> bool: return f.begins_with("serving")):
			res.fail("traits %s: serving place out of view and the 'serving' rule did not fail" % business)


## The five other trades over their frozen matrix, each with its controls.
static func _run_trades(res: SuiteResult) -> void:
	var trades: Array[StringName] = []
	trades.append_array(COUNTER_TRADES)
	for t in WORK_FRONT_TRADES:
		trades.append(t)
	for business in trades:
		for si in range(SIZES.size()):
			for seed_ in TRADE_SEEDS:
				var size: Vector2 = SIZES[si]
				var label := "%s %dx%d seed %d" % [business, int(size.x), int(size.y), seed_]
				var plan := _make(business, size, seed_)
				res.checked += 1
				for failure in trade_contract(plan, business):
					res.fail("%s: %s" % [label, failure])
				if si == 1 and seed_ == TRADE_SEEDS[0]:
					res.checked += 1
					if _signature(plan) != _signature(_make(business, size, seed_)):
						res.fail("%s: a repeat generation produced a different shop" % label)
				_trade_controls(res, plan, business, label)
	# a trade is not another trade: each, judged by the next one's identity
	# (not its whole contract, which may stop at the route before it gets there)
	for i in range(trades.size()):
		var plan2 := _make(trades[i], SIZES[1], TRADE_SEEDS[0])
		var other: StringName = trades[(i + 1) % trades.size()]
		res.checked += 1
		if _identity(plan2, other).is_empty():
			res.fail("a %s passes as a %s" % [trades[i], other])


static func trade_contract(plan: HousePlan, business: StringName) -> Array[String]:
	if WORK_FRONT_TRADES.has(business):
		return work_front_contract(plan, business)
	return counter_contract(plan, business)


## Every role of a trade, removed in turn, must break the rule that names it.
static func _trade_controls(res: SuiteResult, plan: HousePlan, business: StringName, label: String) -> void:
	var front := plan.entrance_room()
	var focus: String = WORK_FRONT_TRADES.get(business, "counter")
	var cases := {
		"serving place": {"drop": [focus], "room": front, "expect": "counter"},
		"stores": {"drop": STORAGE_CATS, "room": -2, "expect": "storage"},
		"sign": {"drop": [String(IDENTITY[business]["sign"])], "room": -1, "expect": "identity"},
	}
	if not WORK_FRONT_TRADES.has(business):
		cases["work"] = {"drop": ["workbench"], "room": -1, "expect": "work area"}
		var work_signs: Array = IDENTITY[business]["work"]
		cases["trade work"] = {"drop": work_signs, "room": -2, "expect": "work area"}
	for role in cases:
		var spec: Dictionary = cases[role]
		var original := plan.furniture
		plan.furniture = _without_in(plan, spec["drop"], int(spec["room"]), front)
		var found := trade_contract(plan, business)
		plan.furniture = original
		res.checked += 1
		if not found.any(func(f: String) -> bool: return f.begins_with(String(spec["expect"]))):
			res.fail("%s: control '%s' removed and the '%s' rule did not fail" % [label, role, spec["expect"]])
	# another trade's sign hung where the customer stands
	var foreign := ""
	for key in SIGN_KEYS:
		if not (SIGN_KEYS[key] as Array).has(business):
			foreign = key
			break
	var front_items := plan.furniture_of(front)
	if not front_items.is_empty():
		var with_sign := _without_in(plan, [], -1, front)
		var piece: Dictionary = with_sign[front_items[0]].duplicate(true)
		piece["key"] = foreign
		piece["mounted"] = true # stands nowhere: only its sign is under test
		with_sign.append(piece)
		var saved := plan.furniture
		plan.furniture = with_sign
		var found3 := trade_contract(plan, business)
		plan.furniture = saved
		res.checked += 1
		if not found3.any(func(f: String) -> bool: return f.begins_with("identity")):
			res.fail("%s: a %s on the shop floor did not fail identity" % [label, foreign])
	# a run of bench right across the floor between the door and the serving place
	var lane_case := _bench_in_lane(plan, focus)
	res.checked += 1
	if lane_case.is_empty():
		res.fail("%s: no lane to put a bench in" % label)
	else:
		var saved2 := plan.furniture
		plan.furniture = lane_case
		var found2 := trade_contract(plan, business)
		plan.furniture = saved2
		if not found2.any(func(f: String) -> bool: return f.begins_with("lane") or f.begins_with("route")):
			res.fail("%s: a bench in the customer lane did not fail the lane or route rule" % label)
	# a workshop-front trade's work boxed in: no room left to stand at it
	if WORK_FRONT_TRADES.has(business):
		var boxed := _box_in_work(plan, business)
		res.checked += 1
		if boxed.is_empty():
			res.fail("%s: no work fixture to box in" % label)
			return
		var saved3 := plan.furniture
		plan.furniture = boxed
		var found4 := trade_contract(plan, business)
		plan.furniture = saved3
		if not found4.any(func(f: String) -> bool: return f.begins_with("work area")):
			res.fail("%s: work boxed in and the 'work area' rule did not fail" % label)


## The plan with a crate stack built round the first work fixture that is not
## the serving place: the fixture is still there, its standing room is not.
static func _box_in_work(plan: HousePlan, business: StringName) -> Array[Dictionary]:
	var front := plan.entrance_room()
	var serving := _counter(plan, front, WORK_FRONT_TRADES[business])
	var serving_rect: Rect2 = serving.get("rect", Rect2())
	var out: Array[Dictionary] = []
	var box := {}
	for p in plan.furniture:
		var copy: Dictionary = p.duplicate(true)
		copy["host"] = -1
		out.append(copy)
		var cat := String(PropCatalog.category(String(p["key"])))
		if box.is_empty() and int(p["room"]) == front and not p.get("mounted", false) \
				and cat in FRONT_WORK_CATS and Rect2(p["rect"]) != serving_rect:
			box = copy.duplicate(true)
			box["key"] = "Crate_Wooden"
			box["rect"] = Rect2(p["rect"]).grow(1.2)
			box["zone"] = box["rect"]
	if box.is_empty():
		return []
	out.append(box)
	return out


## The workshop-front contract (carpenter, smith). Rule names: counter (the
## serving place), route, lane, work area, storage, identity.
static func work_front_contract(plan: HousePlan, business: StringName) -> Array[String]:
	var out: Array[String] = []
	var focus_cat: String = WORK_FRONT_TRADES[business]
	var door := plan.entrance()
	var room := plan.entrance_room()
	if door < 0 or room < 0 or plan.kind_of(room) != &"workshop":
		out.append("route: the front door does not open onto the workshop")
		return out
	var focus := _counter(plan, room, focus_cat)
	if focus.is_empty():
		out.append("counter: the workshop has no %s to be served at" % focus_cat)
		return out
	var nav := HouseNavCheck.new()
	nav.check(plan)
	var level := HousePlan.record_storey(plan.doors[door])
	var grid: WalkGrid = nav._grids.get(level)
	var geometry := _lane(plan, focus_cat)
	var inside: Vector2 = geometry["from"]
	var stance: Vector2 = geometry["to"]
	if grid == null or not grid.flood_from(inside):
		out.append("route: nowhere to stand inside the front door")
		return out

	# 1. arrival at the serving place: the customer gets to the near side of
	# the bench or the anvil, and by no great detour
	var walked := grid.distance_to(stance, 0.5)
	var straight := inside.distance_to(stance)
	if walked == INF:
		out.append("route: the %s cannot be reached from the door" % focus_cat)
	elif walked > straight * 1.6 + 1.5:
		out.append("route: the customer walks %.1fm to a %s %.1fm away" % [walked, focus_cat, straight])

	# 2. the customer does not stand where the work is done: every other work
	# fixture's standing room is taken out of the floor, and he still gets there
	var saved := plan.furniture
	var padded: Array[Dictionary] = []
	var focus_rect: Rect2 = focus["rect"]
	var work_rects: Array[Rect2] = []
	for p in plan.furniture:
		var copy: Dictionary = p.duplicate(true)
		copy["host"] = -1
		var cat := String(PropCatalog.category(String(p["key"])))
		if int(p["room"]) == room and not p.get("mounted", false) and cat in FRONT_WORK_CATS \
				and Rect2(p["rect"]) != focus_rect:
			copy["rect"] = Rect2(p["rect"]).grow(WORK_STANCE)
			work_rects.append(Rect2(p["rect"]))
		padded.append(copy)
	plan.furniture = padded
	var padded_nav := HouseNavCheck.new()
	padded_nav.check(plan)
	plan.furniture = saved
	var padded_grid: WalkGrid = padded_nav._grids.get(level)
	if padded_grid == null or not padded_grid.flood_from(inside):
		out.append("lane: the work leaves no standing room inside the door")
	elif walked != INF:
		var around := padded_grid.distance_to(stance, 0.5)
		if around == INF or around > walked * 1.4 + 1.0:
			out.append("lane: reaching the %s means standing where the work is done" % focus_cat)

	# 3. the work itself can be stood at: each fixture in the workshop has floor
	# beside it that a person reaches from the door
	work_rects.append(focus_rect)
	for wr in work_rects:
		if not grid.reached(wr, 0.8):
			out.append("work area: a work fixture at %s has no room to stand and work at it" % str(wr.get_center()))

	# 4. stock kept in a room the workshop opens onto, reachable
	var stored := false
	var linked := false
	for p2 in plan.furniture:
		var r2 := int(p2["room"])
		if r2 == room or p2.get("mounted", false):
			continue
		if not (String(PropCatalog.category(String(p2["key"]))) in STORAGE_CATS):
			continue
		stored = true
		if (_door_neighbours(plan, room).has(r2) or _two_doors(plan, room, r2)) \
				and grid.reached(Rect2(p2["rect"]), 0.8):
			linked = true
	if not stored:
		out.append("storage: no stock is kept behind the workshop")
	elif not linked:
		out.append("storage: stock is kept, but not in a room the workshop opens onto")

	# 5. identity
	out.append_array(_identity(plan, business))
	return out
