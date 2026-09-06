class_name VillageDresser
extends RefCounted
## What is standing about outside (VIL-013). VILLAGES §7 and §8.
##
## The same shape as `HouseFurnisher`: a table of RECIPES keyed by host, each
## a list of steps naming a prop CATEGORY and a RULE, never a coordinate.
## Indoors the rules are wall/free/around/corner/mounted/on; out here they are
## the seven §7 gives, and they mean the same kind of thing:
##
##   wall    against the host's own wall, never across a door or a window
##   yard    behind or beside the building, off the path to its door
##   verge   on the road verge in front of the lot, never on the carriageway
##   corner  at a corner of the lot
##   row     N copies along an axis at a pitch -- stalls, orchard trees
##   on      set on a cart, a stall, a bench
##   light   a torch or a lantern; the same LIGHT tag the temple assembler
##           already turns into an OmniLight3D
##
## Plants are separate from props and go in `plan.plants`, because they are
## judged differently: a prop is a footprint and a plant is a TRUNK you walk
## round and a CANOPY that must not hang over a roof, and the catalogue
## measures both (VIL-011). Which plants at all is the culture's business --
## §8's palette -- so a norse edge is birch and pine and a moorish one twisted
## trees and pebbles, and no village mixes two palettes.
##
## Nothing here trusts itself. `DressCheck` re-derives every footprint, every
## trunk and every canopy from the placements alone and judges them.
##
## Deterministic: every draw comes from an RNG seeded by name from the spec's
## seed, and the plan is never read in a different order than it is written.

# ------------------------------------------------------------- the recipes

## Metres of clear ground a prop wants around it before it is worth placing.
const PROP_CLEAR := 0.35
## Nothing stands within this of a door's own swing, ever.
const DOOR_CLEAR := 1.2
## Nothing stands on a road, and this is how far off one it stays.
const ROAD_CLEAR := 0.4
## A trunk stays this far off any road polygon and any building's bounds.
const TRUNK_CLEAR := 1.0
## A canopy may not hang over a roof at all; this is the slack allowed.
const CANOPY_SLACK := 0.1

## §7's recipe table, by host. A host is a building (by its programme role),
## or one of the places that is not a building at all -- the common, a gate,
## the water, the strand, the edge.
##
## `n` is [min, max] and `opt` is the same die HouseFurnisher rolls: 1.0 is a
## piece the host is not that host without, and anything less can be left out
## when there is nowhere to put it.
const RECIPES := {
	# any house: what a household leaves outside its own front door
	&"house": [
		{"cat": "barrel", "rule": &"wall", "n": [1, 1], "opt": 0.7},
		{"cat": "bench", "rule": &"wall", "n": [0, 1], "opt": 0.4},
		{"cat": "bush", "rule": &"verge", "n": [2, 2], "opt": 0.6, "plant": true},
	],
	&"farm": [
		{"cat": "crate", "rule": &"yard", "n": [1, 3], "opt": 0.9},
		{"cat": "sack", "rule": &"yard", "n": [1, 2], "opt": 0.9},
		{"cat": "wagon", "rule": &"yard", "n": [0, 1], "opt": 0.6},
		{"cat": "haystack", "rule": &"yard", "n": [1, 1], "opt": 0.8, "built": true},
		{"cat": "tree", "rule": &"row", "n": [3, 5], "pitch": 5.0, "opt": 0.7, "plant": true},
	],
	&"smithy": [
		{"cat": "anvil", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "barrel", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "cookware", "rule": &"wall", "n": [0, 1], "opt": 0.8},
		{"cat": "sconce", "rule": &"light", "n": [1, 1], "opt": 1.0},
	],
	&"tavern": [
		{"cat": "bench", "rule": &"verge", "n": [2, 2], "opt": 1.0},
		{"cat": "barrel", "rule": &"verge", "n": [1, 2], "opt": 1.0},
		{"cat": "sconce", "rule": &"light", "n": [1, 1], "opt": 1.0},
		{"cat": "banner", "rule": &"wall", "n": [1, 1], "opt": 0.6},
	],
	&"stable": [
		{"cat": "wagon", "rule": &"yard", "n": [1, 1], "opt": 0.8},
		{"cat": "sack", "rule": &"wall", "n": [1, 2], "opt": 0.8},
	],
	&"market": [
		{"cat": "stall", "rule": &"row", "n": [3, 6], "pitch": 4.0, "opt": 1.0},
		{"cat": "crate", "rule": &"on", "n": [1, 2], "opt": 0.9},
		{"cat": "wall_torch", "rule": &"light", "n": [2, 2], "opt": 1.0},
	],
	# the common: the well first, and it is the reason a common is a common
	&"common": [
		{"cat": "well", "rule": &"centre", "n": [1, 1], "opt": 1.0, "built": true},
		{"cat": "bench", "rule": &"scatter", "n": [2, 2], "opt": 0.7},
		{"cat": "tree", "rule": &"centre", "n": [1, 1], "opt": 0.5, "plant": true,
			"palette": "green"},
		{"cat": "flower", "rule": &"scatter", "n": [2, 4], "opt": 0.6, "plant": true},
	],
	&"church": [
		{"cat": "tree", "rule": &"ring", "n": [4, 6], "opt": 0.8, "plant": true,
			"palette": "edge"},
	],
	&"gate": [
		{"cat": "signpost", "rule": &"beside", "n": [1, 1], "opt": 1.0, "built": true},
		{"cat": "lamp_post", "rule": &"beside", "n": [2, 2], "opt": 1.0, "built": true},
	],
	&"water": [
		{"cat": "rock", "rule": &"bank", "n": [2, 5], "opt": 0.8, "plant": true},
		{"cat": "plant", "rule": &"bank", "n": [2, 4], "opt": 0.7, "plant": true},
	],
	&"strand": [
		{"cat": "boat", "rule": &"bank", "n": [1, 2], "opt": 1.0, "built": true},
		{"cat": "drying_rack", "rule": &"bank", "n": [1, 2], "opt": 0.9, "built": true},
		{"cat": "crate", "rule": &"bank", "n": [1, 2], "opt": 0.7},
	],
	# the edge: what bounds the village, at the culture's own density
	&"edge": [
		{"cat": "tree", "rule": &"band", "n": [6, 14], "opt": 1.0, "plant": true,
			"palette": "edge"},
		{"cat": "ground", "rule": &"band", "n": [4, 10], "opt": 0.6, "plant": true,
			"palette": "ground"},
	],
}

## §8's palette, by culture. Four slots, and a village plants from one row and
## no other: `edge` at the boundary and behind the farms, `green` the one tree
## on the common, `hedge` along a lot's side boundaries and the verges,
## `ground` the cover on the verges and the common.
##
## The keys are catalogue keys, not categories, because a palette is exactly
## the business of naming WHICH birch. A `*` suffix takes every catalogue key
## with that prefix, so a pack that ships a sixth pine is planted without this
## table changing.
const PALETTES := {
	&"english": {"edge": ["Wild_CommonTree_*", "Nature_MapleTree_*"],
		"green": ["Wild_CommonTree_*"], "hedge": ["Wild_Bush_Common*"],
		"ground": ["Wild_Grass_Common_*", "Wild_Clover_*", "Nature_Flower_*_Clump"]},
	&"frankish": {"edge": ["Wild_CommonTree_*", "Nature_MapleTree_*"],
		"green": ["Wild_CommonTree_*"], "hedge": ["Wild_Bush_Common*"],
		"ground": ["Wild_Grass_Common_*", "Wild_Clover_*", "Nature_Flower_*_Clump"]},
	&"norse": {"edge": ["Wild_Pine_*", "Nature_BirchTree_*"],
		"green": ["Nature_BirchTree_*"], "hedge": ["Nature_Bush_Small*"],
		"ground": ["Wild_Grass_Wispy_*", "Wild_Rock_Medium_*"]},
	&"alpine": {"edge": ["Wild_Pine_*", "Nature_BirchTree_*"],
		"green": ["Nature_BirchTree_*"], "hedge": ["Nature_Bush_Small*"],
		"ground": ["Wild_Grass_Wispy_*", "Wild_Rock_Medium_*"]},
	&"moorish": {"edge": ["Wild_TwistedTree_*", "Wild_CommonTree_*"],
		"green": ["Wild_TwistedTree_*"], "hedge": ["Wild_Plant_1*", "Wild_Plant_7*"],
		"ground": ["Wild_Pebble_*", "Wild_Grass_Common_Short"]},
	&"eastern": {"edge": ["Wild_TwistedTree_*", "Wild_CommonTree_*"],
		"green": ["Wild_TwistedTree_*"], "hedge": ["Wild_Plant_1*", "Wild_Plant_7*"],
		"ground": ["Wild_Pebble_*", "Wild_Grass_Common_Short"]},
	# no green tree at all: nothing grows on a blighted common
	&"blighted": {"edge": ["Nature_DeadTree_*", "Wild_TwistedTree_*"],
		"green": [], "hedge": ["Wild_Mushroom_*"],
		"ground": ["Wild_Grass_Wispy_Short", "Wild_Pebble_Square_*"]},
}

## The props that are BUILT rather than loaded (VIL-010). A recipe step marked
## `built` names one of these instead of a catalogue category; the assembler
## emits it from `PropKit` and the checks measure the AABB it returns.
const BUILT := {
	"well": {"size": Vector2(2.1, 2.1), "zone": 1.0},
	"signpost": {"size": Vector2(0.8, 0.8), "zone": 0.0},
	"lamp_post": {"size": Vector2(0.6, 0.6), "zone": 0.0, "light": true},
	"haystack": {"size": Vector2(2.8, 2.8), "zone": 0.0},
	"boat": {"size": Vector2(1.6, 4.4), "zone": 0.8},
	"drying_rack": {"size": Vector2(1.6, 3.0), "zone": 0.8},
	"mill_wheel": {"size": Vector2(3.8, 0.8), "zone": 0.0},
	"adit": {"size": Vector2(2.4, 1.2), "zone": 1.2},
	"fence_gate": {"size": Vector2(2.0, 0.4), "zone": 1.2},
}

## How thick the planted band outside the enclosure is, by enclosure kind --
## the same table §1 sizes the edge band with.
const EDGE_BAND := {&"none": 4.0, &"hedge": 5.0, &"palisade": 8.0, &"wall": 10.0}
## A `forest` village plants its edge at twice the density.
const FOREST_DENSITY := 2.0
## The green tree stands this far off the well.
const GREEN_TREE_CLEAR := 4.0


## Dress a planned village: fills `plan.props` and `plan.plants` and nothing
## else. Mutates the plan it is given, like the furnisher does; returns it for
## convenience.
static func dress(plan: VillagePlan) -> VillagePlan:
	if plan == null or plan.spec == null or plan.buildings.is_empty():
		return plan
	plan.props.clear()
	plan.plants.clear()
	var ctx: Dictionary = _context(plan)
	# hosts in a fixed order: the common first (the well is what everything
	# else keeps clear of), then the buildings in plan order, then the places
	for step in [&"common", &"market", &"church", &"gate", &"water", &"strand"]:
		_dress_place(plan, ctx, step)
	for i in range(plan.buildings.size()):
		_dress_building(plan, ctx, i)
	_hedges(plan, ctx)
	_dress_place(plan, ctx, &"edge")
	return plan


## What every placement has to keep clear of, gathered once: the road ribbons
## with their verges, every building's measured bounds, the door swings, and
## the common. Rebuilding this per prop is what would make dressing a village
## take longer than planning one.
static func _context(plan: VillagePlan) -> Dictionary:
	var roads: Array[PackedVector2Array] = []
	for road in plan.roads:
		roads.append(VillageSitePlanner.road_ribbon(road, true))
	var bounds: Array[PackedVector2Array] = []
	var doors: Array[Rect2] = []
	for b in plan.buildings:
		bounds.append(VillageMeasure.bounds_poly(b))
		var d: Vector2 = VillageMeasure.door(b)
		doors.append(Rect2(d - Vector2(DOOR_CLEAR, DOOR_CLEAR),
			Vector2(DOOR_CLEAR, DOOR_CLEAR) * 2.0))
	return {
		"roads": roads, "bounds": bounds, "doors": doors,
		"common": VillageMeasure.common_poly(plan),
		"palette": PALETTES.get(plan.spec.culture, PALETTES[&"english"]),
	}


# ------------------------------------------------------------- the hosts

## One building's own dressing: which recipe it takes is its programme role,
## read off the request the way the checks read it.
static func _dress_building(plan: VillagePlan, ctx: Dictionary, i: int) -> void:
	var host: StringName = host_of(plan, i)
	if not RECIPES.has(host):
		return
	var rng := _rng(plan, "host|%d" % i)
	for step in RECIPES[host]:
		_apply(plan, ctx, step, rng, i, host)


## What a building is, for dressing: its shop business where it has one, then
## `farm` for a farmer's house, then plain `house`. A church or temple is the
## churchyard's host.
static func host_of(plan: VillagePlan, i: int) -> StringName:
	var b: Dictionary = plan.buildings[i]
	var request: BuildingRequest = b["request"]
	match request.kind:
		&"church", &"temple":
			return &"church"
		&"shop":
			match request.purpose:
				&"blacksmith":
					return &"smithy"
				&"tavern", &"inn":
					return &"tavern"
				&"stable":
					return &"stable"
			return &"shop"
		&"house":
			return &"farm" if request.purpose == &"farmer" else &"house"
	return &""


## The places that are not buildings: the common, the market on it, the
## gates, the water, the strand, the edge.
static func _dress_place(plan: VillagePlan, ctx: Dictionary, place: StringName) -> void:
	if not RECIPES.has(place):
		return
	match place:
		&"common", &"market":
			if (ctx["common"] as PackedVector2Array).is_empty():
				return
			if place == &"market" and not _has_market(plan):
				return
		&"church":
			return          # the churchyard is dressed with its building
		&"water", &"strand":
			if plan.water.is_empty():
				return
			if place == &"strand" and plan.spec.purpose != &"fishing":
				return
		&"gate":
			if VillageMeasure.gates(plan).is_empty():
				return
	var rng := _rng(plan, "place|%s" % String(place))
	for step in RECIPES[place]:
		_apply(plan, ctx, step, rng, -1, place)


static func _has_market(plan: VillagePlan) -> bool:
	for row in plan.spec.programme:
		if row["kind"] == &"market":
			return true
	return false


# -------------------------------------------------------------- the rules

## One recipe step: roll the die, work out how many, and place them by the
## step's own rule. Anything that finds nowhere legal is simply not placed --
## an outdoor recipe is a description of a full village, and a hamlet is not
## a failure for having one bench instead of two.
static func _apply(plan: VillagePlan, ctx: Dictionary, step: Dictionary,
		rng: RandomNumberGenerator, host: int, role: StringName) -> void:
	var opt: float = float(step.get("opt", 1.0))
	if opt < 1.0 and rng.randf() > opt:
		return
	var span: Array = step["n"]
	var count: int = rng.randi_range(int(span[0]), int(span[1]))
	if count <= 0:
		return
	var keys: Array[String] = _keys_for(ctx, step)
	if keys.is_empty():
		return
	# Walk the candidates until `count` pieces are down, rather than trying
	# the first `count` of them: a rule offers several places on purpose --
	# either side of the door, then further out from the wall -- and taking
	# only the first meant one blocked spot lost the piece entirely.
	var spots: Array[Vector2] = _spots_for(plan, ctx, step, rng, host, role, count)
	var placed := 0
	for spot in spots:
		if placed >= count:
			break
		var key: String = keys[rng.randi() % keys.size()]
		if _place(plan, ctx, step, key, spot, rng, host):
			placed += 1


## Which catalogue keys a step may draw from: a palette slot for a plant, the
## BUILT table for a built prop, a category otherwise.
static func _keys_for(ctx: Dictionary, step: Dictionary) -> Array[String]:
	if bool(step.get("built", false)):
		var made: Array[String] = []
		if BUILT.has(String(step["cat"])):
			made.append(String(step["cat"]))
		return made
	if bool(step.get("plant", false)):
		var slot: String = String(step.get("palette", ""))
		if slot.is_empty():
			slot = _slot_for(String(step["cat"]))
		return _palette_keys(ctx, slot)
	return PropCatalog.of_category(String(step["cat"]))


## Which palette slot a plant category comes out of when the step does not
## name one.
static func _slot_for(cat: String) -> String:
	match cat:
		"tree", "dead_tree":
			return "edge"
		"bush":
			return "hedge"
		"ground", "grass", "flower", "pebble", "rock", "plant", "mushroom":
			return "ground"
	return "ground"


## The catalogue keys of one palette slot, expanding the `*` patterns. Only
## keys the catalogue actually knows are returned, so a palette naming a pack
## that is not installed plants nothing rather than crashing.
static func _palette_keys(ctx: Dictionary, slot: String) -> Array[String]:
	var out: Array[String] = []
	var palette: Dictionary = ctx["palette"]
	for pattern in palette.get(slot, []):
		var text: String = String(pattern)
		if text.ends_with("*"):
			var prefix: String = text.substr(0, text.length() - 1)
			for key in PropCatalog.plants():
				if key.begins_with(prefix) and PropCatalog.known(key):
					out.append(key)
		elif PropCatalog.known(text):
			out.append(text)
	return out


## Where a step's pieces go, by its rule. Every rule returns candidate points
## in a fixed order; `_place` is what refuses the illegal ones.
static func _spots_for(plan: VillagePlan, ctx: Dictionary, step: Dictionary,
		rng: RandomNumberGenerator, host: int, role: StringName,
		count: int) -> Array[Vector2]:
	match StringName(step["rule"]):
		&"wall", &"light":
			return _along_front(plan, host, count, 0.0)
		&"verge":
			return _along_front(plan, host, count, _verge_offset(plan, host))
		&"yard":
			return _in_yard(plan, host, count, rng)
		&"corner":
			return _lot_corners(plan, host, count)
		&"row":
			return _row(plan, ctx, step, host, role, count)
		&"on":
			return _on_props(plan, host, count)
		&"centre":
			return _common_centre(plan, ctx, count)
		&"scatter":
			return _scatter(ctx["common"], rng, count)
		&"ring":
			return _ring(plan, host, count)
		&"beside":
			return _beside_gates(plan, count)
		&"bank":
			return _along_water(plan, rng, count)
		&"band":
			return _edge_band(plan, rng, count)
	return []


## Points along the building's own front. `front_dir` points OUT of the
## building, so `off` is measured away from its wall: 0 is against it and the
## lot's setback less a stride is out on the verge.
##
## Candidates step BOTH ways -- along the front either side of the door, and
## progressively further out from the wall -- because the near ones are often
## under the eaves. `bounds` covers the roof overhang and `front_mid` is on
## the walls, so a barrel a metre off the wall can still be inside the
## building as far as every check is concerned; without the outward steps
## most houses got no barrel at all.
static func _along_front(plan: VillagePlan, host: int, count: int,
		off: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if host < 0:
		return out
	var b: Dictionary = plan.buildings[host]
	var mid: Vector2 = VillageMeasure.front_mid(b)
	var dir: Vector2 = VillageMeasure.front_dir(b)
	var across := Vector2(-dir.y, dir.x)
	for step_out in range(3):
		for k in range(count * 2):
			var side: float = 1.0 if k % 2 == 0 else -1.0
			var reach: float = 1.4 + float(k / 2) * 1.1
			out.append(mid + across * (side * reach)
				+ dir * (off + 0.8 + float(step_out) * 0.7))
	return out


## How far out the verge is: the lot's own setback, less a stride so the
## bench stands on the verge and not in the road.
static func _verge_offset(plan: VillagePlan, host: int) -> float:
	if host < 0:
		return 0.0
	var lot: int = plan.lot_of_building(host)
	if lot < 0:
		return 0.0
	return maxf(float(plan.lots[lot].get("setback", 2.0)) - 1.6, 0.0)


## In the lot, behind the front line of the building: the yard.
static func _in_yard(plan: VillagePlan, host: int, count: int,
		rng: RandomNumberGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if host < 0:
		return out
	var lot: int = plan.lot_of_building(host)
	if lot < 0:
		return out
	var poly: PackedVector2Array = plan.lots[lot]["poly"]
	var b: Dictionary = plan.buildings[host]
	var behind: Vector2 = -VillageMeasure.front_dir(b)
	var bounds: PackedVector2Array = VillageMeasure.bounds_poly(b)
	var back: Vector2 = VillageMeasure.centre(bounds) + behind * 4.0
	for k in range(count * 3):
		var jitter := Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
		var p: Vector2 = back + jitter
		if Poly.contains_point(poly, p):
			out.append(p)
	return out


static func _lot_corners(plan: VillagePlan, host: int, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if host < 0:
		return out
	var lot: int = plan.lot_of_building(host)
	if lot < 0:
		return out
	var poly: PackedVector2Array = plan.lots[lot]["poly"]
	var centre: Vector2 = VillageMeasure.centre(poly)
	for p in poly:
		if out.size() >= count:
			break
		out.append(Vector2(p).lerp(centre, 0.15))
	return out


## N copies along an axis at a pitch: the orchard behind a farm, the rows of
## stalls on the square.
static func _row(plan: VillagePlan, ctx: Dictionary, step: Dictionary,
		host: int, role: StringName, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var pitch: float = float(step.get("pitch", 4.0))
	if role == &"market":
		var common: PackedVector2Array = ctx["common"]
		if common.is_empty():
			return out
		var rect: Rect2 = Poly.bounding_rect(common)
		# rows along the square's longer axis, the aisle between them
		var along: Vector2 = Vector2(1, 0) if rect.size.x >= rect.size.y else Vector2(0, 1)
		var across := Vector2(-along.y, along.x)
		var mid: Vector2 = rect.get_center()
		for k in range(count):
			var row: int = k / 3
			var slot: int = k % 3
			out.append(mid + along * ((float(slot) - 1.0) * pitch)
				+ across * ((float(row) - 0.5) * pitch))
		return out
	if host < 0:
		return out
	var b: Dictionary = plan.buildings[host]
	var behind: Vector2 = -VillageMeasure.front_dir(b)
	var start: Vector2 = VillageMeasure.centre(VillageMeasure.bounds_poly(b)) + behind * 8.0
	var across2 := Vector2(-behind.y, behind.x)
	for k in range(count):
		out.append(start + across2 * ((float(k) - float(count - 1) * 0.5) * pitch))
	return out


## On something that has a top: a stall, a cart, a bench already placed.
static func _on_props(plan: VillagePlan, host: int, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in plan.props:
		if out.size() >= count:
			break
		if PropCatalog.has_tag(String(p["key"]), PropCatalog.SURFACE):
			out.append(p["pos"])
	return out


static func _common_centre(plan: VillagePlan, ctx: Dictionary,
		count: int) -> Array[Vector2]:
	var common: PackedVector2Array = ctx["common"]
	if common.is_empty():
		return []
	var centre: Vector2 = VillageMeasure.centre(common)
	var out: Array[Vector2] = [centre]
	# anything after the first stands off the middle, so the green tree does
	# not try to grow out of the well
	for k in range(1, count):
		out.append(centre + Vector2(GREEN_TREE_CLEAR + float(k), 0.0))
	return out


static func _scatter(poly: PackedVector2Array, rng: RandomNumberGenerator,
		count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if poly.is_empty():
		return out
	var rect: Rect2 = Poly.bounding_rect(poly)
	for k in range(count * 4):
		var p := Vector2(rng.randf_range(rect.position.x, rect.end.x),
			rng.randf_range(rect.position.y, rect.end.y))
		if Poly.contains_point(poly, p):
			out.append(p)
	return out


## Round the churchyard: the yews of §7, on a ring outside the church's own
## bounds.
static func _ring(plan: VillagePlan, host: int, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if host < 0:
		return out
	var bounds: PackedVector2Array = VillageMeasure.bounds_poly(plan.buildings[host])
	var rect: Rect2 = Poly.bounding_rect(bounds)
	var radius: float = maxf(rect.size.x, rect.size.y) * 0.5 + 3.0
	var centre: Vector2 = rect.get_center()
	for k in range(count):
		var a: float = TAU * float(k) / float(maxi(count, 1))
		out.append(centre + Vector2(cos(a), sin(a)) * radius)
	return out


static func _beside_gates(plan: VillagePlan, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for g in VillageMeasure.gates(plan):
		for side in [1.0, -1.0]:
			if out.size() >= count * 2:
				break
			out.append(g + Vector2(0.0, side * 5.0))
	return out


static func _along_water(plan: VillagePlan, rng: RandomNumberGenerator,
		count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for w in plan.water:
		var poly: PackedVector2Array = w["poly"]
		var grown: PackedVector2Array = Poly.offset(poly, 1.5)
		for p in grown:
			if out.size() >= count * 2:
				break
			out.append(p)
	return out


## The band outside the enclosure, or just inside the site edge when there is
## no enclosure: where the village is bounded by something.
static func _edge_band(plan: VillagePlan, rng: RandomNumberGenerator,
		count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var band: float = float(EDGE_BAND.get(plan.spec.enclosure, 4.0))
	var site: Rect2 = plan.site
	var inner: Rect2 = site.grow(-band - 1.0)
	var want: int = count
	if plan.spec.purpose == &"forest":
		want = int(float(count) * FOREST_DENSITY)
	# Sampled ON the band, not over the whole site and filtered. The band is a
	# few metres of a site hundreds of metres across, so uniform sampling put
	# one candidate in ten inside it and a fifty-building village came out
	# with a single tree at its edge.
	for k in range(want * 3):
		var side: int = k % 4
		var depth: float = rng.randf_range(0.5, maxf(band, 1.5))
		var p: Vector2
		match side:
			0:
				p = Vector2(site.position.x + depth,
					rng.randf_range(site.position.y, site.end.y))
			1:
				p = Vector2(site.end.x - depth,
					rng.randf_range(site.position.y, site.end.y))
			2:
				p = Vector2(rng.randf_range(site.position.x, site.end.x),
					site.position.y + depth)
			_:
				p = Vector2(rng.randf_range(site.position.x, site.end.x),
					site.end.y - depth)
		if inner.has_point(p):
			continue          # inside the village, not at its edge
		out.append(p)
	return out


# ---------------------------------------------------------- placing them

## Put one piece down, if the ground is free. A plant goes in `plan.plants`
## with its measured trunk and canopy; everything else in `plan.props` with
## the floor it stands on and the floor a person needs to use it.
## True when the piece went down. False is not a failure: an outdoor recipe
## describes a full village, and a hamlet is not wrong for having one bench
## where the recipe offers two.
static func _place(plan: VillagePlan, ctx: Dictionary, step: Dictionary,
		key: String, at: Vector2, rng: RandomNumberGenerator, host: int) -> bool:
	var is_plant: bool = bool(step.get("plant", false))
	if is_plant:
		var trunk: float = maxf(PropCatalog.trunk(key), 0.1)
		if not _plant_is_clear(plan, ctx, at, trunk, PropCatalog.canopy(key)):
			return false
		plan.plants.append({"key": key, "pos": at,
			"canopy": PropCatalog.canopy(key), "trunk": trunk,
			"yaw": snappedf(rng.randf_range(0.0, TAU), 0.001)})
		return true
	var built: bool = bool(step.get("built", false))
	var size: Vector2 = Vector2(BUILT[key]["size"]) if built \
		else PropCatalog.footprint(key)
	var zone: float = float(BUILT[key]["zone"]) if built else PropCatalog.zone_depth(key)
	var yaw: float = _facing(plan, host, at)
	var rect := Rect2(at - size / 2.0, size)
	var use := Rect2(at - Vector2(zone, zone), Vector2(zone, zone) * 2.0) 		if zone > 0.0 else Rect2()
	if not _prop_is_clear(plan, ctx, rect, use):
		return false
	plan.props.append({"key": key, "pos": at, "yaw": snappedf(yaw, 0.001),
		"host": host, "rect": rect, "zone": use,
		"built": built, "light": _is_light(key, built)})
	return true


static func _is_light(key: String, built: bool) -> bool:
	if built:
		return bool(BUILT[key].get("light", false))
	return PropCatalog.has_tag(key, PropCatalog.LIGHT)


## Which way a piece faces: away from its host building, so a bench by a door
## looks out at the street; toward the village otherwise.
static func _facing(plan: VillagePlan, host: int, at: Vector2) -> float:
	var dir: Vector2 = Vector2(0, -1)
	if host >= 0 and host < plan.buildings.size():
		dir = VillageMeasure.front_dir(plan.buildings[host])
	else:
		var to_centre: Vector2 = plan.site.get_center() - at
		if to_centre.length_squared() > 0.01:
			dir = to_centre.normalized()
	return PropCatalog.yaw_facing(dir)


## Nothing on a road, in a doorway, inside a building or on top of another
## prop.
##
## Measured the way `RoadCheck.clear` measures it, and with the same
## functions: its ZONE against the ribbon WITH its verge, through
## `VillageLotPlanner.overlap_area`. Two things were wrong with doing it any
## other way. The check tests the zone -- the floor a person needs to USE the
## piece -- and an anvil's zone is nearly a metre wider than the anvil, so a
## dresser that only kept the anvil out of the road put its zone in it. And
## `Poly.intersection_area` clips one convex polygon against another, which a
## bowed road ribbon is not; `overlap_area` goes through `Geometry2D` and
## does not care.
static func _prop_is_clear(plan: VillagePlan, ctx: Dictionary, rect: Rect2,
		zone: Rect2) -> bool:
	if not plan.site.grow(-0.5).encloses(rect):
		return false
	var claim: Rect2 = rect.merge(zone) if zone.size.x > 0.0 else rect
	var poly: PackedVector2Array = Poly.from_rect(claim.grow(ROAD_CLEAR))
	for ribbon in ctx["roads"]:
		if VillageLotPlanner.overlap_area(poly, ribbon) > VillageLotPlanner.AREA_EPS:
			return false
	var mine: PackedVector2Array = Poly.from_rect(rect)
	for b in ctx["bounds"]:
		if VillageLotPlanner.overlap_area(mine, b) > VillageLotPlanner.AREA_EPS:
			return false
	for d in ctx["doors"]:
		if d.intersects(claim):
			return false
	var grown: Rect2 = rect.grow(PROP_CLEAR)
	for p in plan.props:
		if grown.intersects(p["rect"]):
			return false
	return true


## A trunk off every road and every building, and a canopy over no roof.
## Same functions as the checks -- `overlap_area` over `Geometry2D`, not the
## convex clipper, because a road ribbon bends.
static func _plant_is_clear(plan: VillagePlan, ctx: Dictionary, at: Vector2,
		trunk: float, canopy: float) -> bool:
	if not plan.site.has_point(at):
		return false
	var stem: PackedVector2Array = Poly.from_rect(
		Rect2(at - Vector2(trunk, trunk), Vector2(trunk, trunk) * 2.0).grow(TRUNK_CLEAR))
	for ribbon in ctx["roads"]:
		if VillageLotPlanner.overlap_area(stem, ribbon) > VillageLotPlanner.AREA_EPS:
			return false
	var crown: PackedVector2Array = Poly.from_rect(
		Rect2(at - Vector2(canopy, canopy), Vector2(canopy, canopy) * 2.0).grow(-CANOPY_SLACK))
	for b in ctx["bounds"]:
		if VillageLotPlanner.overlap_area(stem, b) > VillageLotPlanner.AREA_EPS:
			return false
		if canopy > 0.0 and VillageLotPlanner.overlap_area(crown, b) > VillageLotPlanner.AREA_EPS:
			return false
	for d in ctx["doors"]:
		if d.has_point(at):
			return false
	for p in plan.props:
		if (p["rect"] as Rect2).grow(trunk).has_point(at):
			return false
	for other in plan.plants:
		if at.distance_to(other["pos"]) < trunk + float(other["trunk"]) + 0.5:
			return false
	return true


# ------------------------------------------------------------- the hedges

## A hedge along each lot's side boundaries, with a gap where the path to the
## door crosses it. Culture's `hedge` slot, at a pitch, and only where the
## village is rich enough to keep one (§7: `row`, wealth x 0.8).
static func _hedges(plan: VillagePlan, ctx: Dictionary) -> void:
	var keys: Array[String] = _palette_keys(ctx, "hedge")
	if keys.is_empty():
		return
	var rng := _rng(plan, "hedge")
	var chance: float = plan.spec.wealth * 0.8
	for i in range(plan.buildings.size()):
		if rng.randf() > chance:
			continue
		var lot: int = plan.lot_of_building(i)
		if lot < 0:
			continue
		var poly: PackedVector2Array = plan.lots[lot]["poly"]
		var front: PackedVector2Array = plan.lots[lot]["front"]
		for e in range(poly.size()):
			var a: Vector2 = poly[e]
			var b: Vector2 = poly[(e + 1) % poly.size()]
			# the frontage itself is the way in, never hedged across
			if _same_edge(a, b, front):
				continue
			var run: float = a.distance_to(b)
			var steps: int = int(run / 1.6)
			for k in range(steps):
				var t: float = (float(k) + 0.5) / float(maxi(steps, 1))
				var key: String = keys[rng.randi() % keys.size()]
				# a hedge is a run: the pieces that will not fit are simply
				# the gaps in it, which is what a hedge looks like anyway
				var _in_hedge: bool = _place(plan, ctx,
					{"plant": true, "palette": "hedge"}, key, a.lerp(b, t), rng, i)


static func _same_edge(a: Vector2, b: Vector2, front: PackedVector2Array) -> bool:
	if front.size() < 2:
		return false
	return (a.distance_to(front[0]) < 0.5 and b.distance_to(front[1]) < 0.5) \
		or (a.distance_to(front[1]) < 0.5 and b.distance_to(front[0]) < 0.5)


## An RNG named from the spec's seed, so dressing is a pure function of the
## plan and two runs put the same barrel in the same place.
static func _rng(plan: VillagePlan, key: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("dress|%d|%s" % [plan.spec.seed, key])
	return rng
